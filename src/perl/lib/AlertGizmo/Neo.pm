# AlertGizmo::Neo
# ABSTRACT: AlertGizmo monitor for NASA JPL Near-Earth Object (NEO) close approach data
# Copyright 2024-2026 by Ian Kluft

# pragmas to silence some warnings from Perl::Critic
## no critic (Modules::RequireExplicitPackage)
# This solves a catch-22 where parts of Perl::Critic want both package and use-strict to be first
use Modern::Perl qw(2023);
# includes strict & warnings, boolean requires 5.36, try/catch requires 5.34
## use critic (Modules::RequireExplicitPackage)

package AlertGizmo::Neo;

use parent "AlertGizmo";

use utf8;
use autodie;
use experimental qw(builtin try);
use feature      qw(say try);
use builtin      qw(true false);
use Readonly;
use Carp qw(croak);
use File::Basename;
use DateTime;
use DateTime::Format::Flexible;
use File::Slurp;
use IO::Interactive qw(is_interactive);
use JSON;
use URI::Escape;
use AlertGizmo::Config;
use AlertGizmo::Neo::Approach;

# constants for AlertGizmo::Neo
Readonly::Array my @CLI_OPTS      => ( "query_ld|ld:s" );
Readonly::Scalar my $DAYS_BACK    => 15;
Readonly::Scalar my $DAYS_AHEAD   => 60;
Readonly::Scalar my $DEFAULT_LD   => 1.5;
Readonly::Scalar my $NEO_API_URL  =>
    "https://ssd-api.jpl.nasa.gov/cad.api?dist-max=%3.1fLD&sort=-date&diameter=true&date-min=%s&date-max=%s";
Readonly::Scalar my $OUTJSON      => "neo-data.json";
Readonly::Scalar my $OUTBASE      => "close-approaches";
Readonly::Scalar my $TEMPLATE     => $OUTBASE . ".tt";

# get template path for this subclass
# class method, required of AlertGizmo subclasses
sub path_template
{
    return $TEMPLATE;
}

# get output file path base for this subclass
# class method, required of AlertGizmo subclasses
sub path_out_base
{
    return $OUTBASE;
}

# return description link url & text to display in table footer
# class method, required of AlertGizmo subclasses
sub footer_desc
{
    return ( "https://ssd-api.jpl.nasa.gov/doc/cad.html", "NASA JPL NEO approaches" );
}

# return script link url & text to display in table footer
# class method, required of AlertGizmo subclasses
sub footer_script
{
    return ( "https://github.com/ikluft/AlertGizmo/tree/main/src/perl", "pull-nasa-neo" );
}

# return author link url & text to display in table footer
# class method, required of AlertGizmo subclasses
sub footer_author
{
    return ( "https://ikluft.github.io/", "Ian Kluft" );
}

# class method AlertGizmo (parent) calls before template processing
sub pre_template
{
    my $class = shift;

    # compute query start date from $DAYS_BACK days ago
    my $timestamp = AlertGizmo::Config->timestamp();
    my $start_date =
        $timestamp->clone()->set_time_zone('UTC')->subtract( days => $DAYS_BACK )->date();
    AlertGizmo::Config->params( ["start_date"], $start_date );
    is_interactive() and say "start date: " . $start_date;

    # compute query end date from $DAYS_AHEAD days ago
    my $end_date =
        $timestamp->clone()->set_time_zone('UTC')->add( days => $DAYS_AHEAD )->date();
    AlertGizmo::Config->params( ["end_date"], $end_date );
    is_interactive() and say "end date: " . $end_date;

    # set query lunar distance limit (query_ld)
    my $query_ld = $DEFAULT_LD;
    if ( AlertGizmo::Config->has( qw(params query_ld) )) {
        $query_ld = AlertGizmo::Config->params( [ "query_ld" ] );
    } elsif ( AlertGizmo::Config->has( qw(options query_ld) )) {
        $query_ld = AlertGizmo::Config->options( [ "query_ld" ] );
        AlertGizmo::Config->params( [ "query_ld" ], $query_ld );
    } else {
        AlertGizmo::Config->params( [ "query_ld" ], $query_ld );
    }

    # clear destination symlink
    AlertGizmo::Config->paths( [qw( outlink )], AlertGizmo::Config->dir() . "/" . $OUTJSON );
    if ( -e AlertGizmo::Config->paths( [qw( outlink )] ) ) {
        if ( not -l AlertGizmo::Config->paths( [qw( outlink )] ) ) {
            croak "destination file " . AlertGizmo::Config->paths( [qw( outlink )] ) . " is not a symlink";
        }
    }
    AlertGizmo::Config->paths( [qw( outjson )],
        AlertGizmo::Config->paths( [qw( outlink )] ) . "-" . AlertGizmo::Config->timestamp() );

    # perform NEO query
    my $url = sprintf $NEO_API_URL,
        $query_ld,
        AlertGizmo::Config->params( ["start_date"] ),
        AlertGizmo::Config->params( ["end_date"] );
    $class->retrieve_url( $url );

    # read JSON into template data
    # in case of JSON error, allow these to crash the program here before proceeding to symlinks
    my $json_path =
          AlertGizmo::Config->test_mode()
        ? AlertGizmo::Config->paths( [qw( outlink )] )
        : AlertGizmo::Config->paths( [qw( outjson )] );
    my $json_text = File::Slurp::read_file($json_path);
    AlertGizmo::Config->params( ["json"], JSON::from_json $json_text );
    my $json_data = AlertGizmo::Config->params( [qw( json data )] );

    # check API version number
    my $api_version = AlertGizmo::Config->params( [qw( json signature version )] );
    if ( $api_version ne "1.5" ) {
        croak "API version changed to " . $api_version . " - code needs update to handle it";
    }

    # collect field names/numbers from JSON
    AlertGizmo::Config->params( ["fnum"], {} );
    my $fields_ref = AlertGizmo::Config->params( [qw( json fields )] );
    for ( my $fnum = 0 ; $fnum < scalar @$fields_ref ; $fnum++ ) {
        AlertGizmo::Config->params( [ "fnum", $fields_ref->[$fnum] ], $fnum );
    }

    # convert API results to template-able list
    AlertGizmo::Config->params( ["neos"], [] );
    my $neos_ref = AlertGizmo::Config->params( ["neos"] );
    foreach my $raw_item (@$json_data) {
        # initialize and store NEO record
        my $neo = AlertGizmo::Neo::Approach->new( $raw_item );
        push @$neos_ref, $neo;
    }

    return;
}

# class method AlertGizmo (parent) called after template processing
sub post_template
{
    my $class = shift;

    # make a symlink to new data
    if ( -l AlertGizmo::Config->paths( ["outlink"] ) ) {
        unlink AlertGizmo::Config->paths( ["outlink"] );
    }
    symlink basename( AlertGizmo::Config->paths( ["outjson"] ) ), AlertGizmo::Config->paths( ["outlink"] )
        or croak "failed to symlink "
        . AlertGizmo::Config->paths( ["outlink"] ) . " to "
        . AlertGizmo::Config->paths( ["outjson"] ) . ": $!";

    # clean up old data files
    my $config_dir = AlertGizmo::Config->dir();
    opendir( my $dh, $config_dir )
        or croak "Can't open $config_dir: $!";
    my @datafiles = sort { $b cmp $a } grep { /^ $OUTJSON -/x } readdir $dh;
    closedir $dh;
    if ( scalar @datafiles > 5 ) {
        splice @datafiles, 0, 5;
        foreach my $oldfile (@datafiles) {

            # double check we're only removing old JSON files
            next if ( ( substr $oldfile, 0, length($OUTJSON) ) ne $OUTJSON );

            my $delpath = $config_dir . "/" . $oldfile;
            next if not -e $delpath;               # skip if the file doesn't exist
            next if ( ( -M $delpath ) < 0.65 );    # don't remove files newer than 15 hours

            is_interactive() and say "removing $delpath";
            unlink $delpath;
        }
    }
    return;
}

1;

=pod

=encoding utf8

=head1 SYNOPSIS

    use AlertGizmo;
    use AlertGizmo::Neo;

    # set implementation subclass to AlertGizmo::Neo, then run AlertGizmo's main()
    AlertGizmo::Neo->set_class();
    AlertGizmo->main();

=head1 DESCRIPTION

AlertGizmo::Neo reads data on NASA JPL Near Earth Object "NEO" passes, producing an HTML table of asteroid passes in the past 2 weeks or known upcoming passes up to 2 months in the future.

=head1 FUNCTIONS AND METHODS

=head1 LICENSE

I<AlertGizmo> and its submodules are Open Source software licensed under the GNU General Public License Version 3.
See L<https://www.gnu.org/licenses/gpl-3.0-standalone.html>.

=head1 SEE ALSO

L<AlertGizmo>

=head1 BUGS AND LIMITATIONS

Please report bugs via GitHub at L<https://github.com/ikluft/AlertGizmo/issues>

Patches and enhancements may be submitted via a pull request at L<https://github.com/ikluft/AlertGizmo/pulls>

=cut
