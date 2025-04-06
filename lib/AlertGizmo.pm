# AlertGizmo
# ABSTRACT: base class for AlertGizmo feed monitors
# Copyright 2024-2025 by Ian Kluft

# pragmas to silence some warnings from Perl::Critic
## no critic (Modules::RequireExplicitPackage)
# This solves a catch-22 where parts of Perl::Critic want both package and use-strict to be first
use Modern::Perl qw(2023)
    ;    # includes strict & warnings, boolean requires 5.36, try/catch requires 5.34
## use critic (Modules::RequireExplicitPackage)

package AlertGizmo;

use utf8;
use autodie;
use experimental qw(builtin try);
use feature      qw(say try);
use builtin      qw(true false);
use Readonly;
use Carp         qw(carp croak confess);
use Scalar::Util qw( blessed );
use FindBin;
use AlertGizmo::Config;
use AlertGizmo::Postproc;
use File::Basename;
use File::Fetch;
use Getopt::Long;
use DateTime;
use DateTime::Format::Flexible;
use Template;
use results;
use File::Which;
use Data::Dumper;

# exceptions/errors
use Exception::Class (
    'AlertGizmo::Exception',

    'AlertGizmo::Exception::NetworkGet' => {
        isa         => 'AlertGizmo::Exception',
        alias       => 'throw_network_get',
        fields      => [ qw( client )],
        description => "Failed to access feed source",
    },

    'AlertGizmo::Exception::Postprox' => {
        isa         => 'AlertGizmo::Exception',
        alias       => 'throw_postprox',
        description => "Postprocessing error",
    },
);

# initialize class static variables
AlertGizmo::Config->accessor( ["options"], {} );
AlertGizmo::Config->accessor( ["params"],  {} );
AlertGizmo::Config->accessor( ["paths"],   {} );
AlertGizmo::Config->accessor( ["postproc"],   {} );

# constants
Readonly::Scalar our $PROGNAME => basename($0);
Readonly::Array our @CLI_OPTIONS =>
    ( "dir:s", "verbose", "test|test_mode", "proxy:s", "timezone|tz:s", "postproc:s" );
Readonly::Scalar our $DEFAULT_OUTPUT_DIR => $FindBin::Bin;
Readonly::Scalar our $WKHTMLTOIMAGE => which("wkhtmltoimage");

# return AlertGizmo (or subclass) version number
sub version
{
    my $class = shift;
    {
        ## no critic (TestingAndDebugging::ProhibitNoStrict)
        no strict 'refs';
        if ( defined ${ $class . "::VERSION" } ) {
            return ${ $class . "::VERSION" };
        }
    }
    return "00-dev";
}

#
# Configuration wrapper functions for AlertGizmo::Config
#

# wrapper for AlertGizmo::Config read/write accessor
sub config
{
    my ( $class, $keys_ref, $value ) = @_;
    if ( not defined $keys_ref ) {
        return AlertGizmo::Config->accessor()->unwrap();
    }
    my $result = AlertGizmo::Config->accessor( $keys_ref, $value );
    AlertGizmo::Config->verbose() and say STDERR "config: " . ( join( "-", @$keys_ref )) . " result type "
        . ref($result);
    if ( $result->is_err() ) {
        my $err = $result->unwrap_err();
        AlertGizmo::Config->verbose() and say STDERR "config: result err " . ref($err);
        if ( $err->isa('AlertGizmo::Config::Exception::NotFound') ) {

            # process not found error into undef result as common Perl code expects
            return;
        }
        confess($err);
    }

    # returns on success
    my $resval = $result->unwrap();
    AlertGizmo::Config->verbose() and say STDERR "config: result value "
        . ( ref $resval ? Dumper( $resval ) : $resval // "" );
    return $resval;
}

# wrapper for AlertGizmo::Config existence-test method
sub has_config
{
    my ( $class, @keys ) = @_;
    return AlertGizmo::Config->contains(@keys);
}

# wrapper for AlertGizmo::Config delete method
sub del_config
{
    my ( $class, @keys ) = @_;
    return AlertGizmo::Config->del(@keys);
}

# accessor wrapper for options top-level config
sub options
{
    my ( $class, $keys_ref, $value ) = @_;
    return $class->config( [ "options", @{ $keys_ref // [] } ], $value );
}

# accessor wrapper for params top-level config
sub params
{
    my ( $class, $keys_ref, $value ) = @_;
    return $class->config( [ "params", @{ $keys_ref // [] } ], $value );
}

# accessor wrapper for paths top-level config
sub paths
{
    my ( $class, $keys_ref, $value ) = @_;
    return $class->config( [ "paths", @{ $keys_ref // [] } ], $value );
}

# accessor for test mode config
sub config_test_mode
{
    my $class = shift;
    return $class->options( ["test"] ) // false;
}

# accessor for proxy config
sub config_proxy
{
    my $class = shift;
    return $class->options( ["proxy"] ) // $ENV{PROXY} // $ENV{SOCKS_PROXY};
}

# accessor for timezone config
sub config_timezone
{
    my $class = shift;

    if ( $class->has_config(qw(params timezone)) ) {
        return $class->params( ["timezone"] );
    }
    my $tz = $class->options( ["timezone"] )
        // "UTC";    # get TZ value from CLI options or default UTC
    $class->params( ["timezone"], $tz );    # save to template params
    return $tz;                             # and return value to caller
}

# accessor for timestamp config
sub config_timestamp
{
    my $class = shift;

    if ( $class->has_config(qw(params timestamp)) ) {
        my $timestamp = $class->params( ["timestamp"] );

    # check if value placed in timestamp is a DateTime object, or replace date strings with DateTime
        if ( not $timestamp->isa("DateTime") ) {
            my $old_timestamp = $timestamp;
            try {
                $timestamp = DateTime::Format::Flexible->parse_datetime($old_timestamp);
            } catch ($e) {
                confess
"config_timestamp: timestamp $old_timestamp is not a DateTime object or date string - $e";
            };

            # overwrite timestamp param with DateTime object
            $class->params( ["timestamp"], $timestamp );
        }
        return $timestamp;
    }
    my $timestamp_obj = DateTime->now( time_zone => "" . $class->config_timezone() );
    $class->params( ["timestamp"], $timestamp_obj );
    return $timestamp_obj;
}

# accessor for output directory config
# It should not be necessary for subclasses to override this. But it's technically possible.
sub config_dir
{
    my $class = shift;

    if ( $class->has_config(qw(params output_dir)) ) {
        return $class->params( ["output_dir"] );
    }
    my $dir;
    if ( $class->has_config(qw(options dir)) ) {
        $dir = $class->options( ["dir"] );
    } else {
        $dir = $DEFAULT_OUTPUT_DIR;
    }
    $class->params( ["output_dir"], $dir );
    return $dir;
}

# class method to set the subclass it was called as to provide the implementation for this run
sub set_class
{
    my $class = shift;

    if ( $class eq __PACKAGE__ ) {
        croak "error: set_class must be called by a subclass of " . __PACKAGE__;
    }
    if ( not $class->isa(__PACKAGE__) ) {
        croak "error: $class is not a subclass of " . __PACKAGE__;
    }
    $class->config( ["class"], $class );
    return;
}

#
# common functions used by AlertGizmo feed monitors
#

# convert DateTime to date/time/tz string
sub dt2dttz
{
    my $dt = shift;
    return $dt->ymd('-') . " " . $dt->hms(':') . " " . $dt->time_zone_short_name();
}

# generate class name from program name
# class function
sub gen_class_name
{
    # If "class" config is set, then this is already decided. So use that.
    if ( __PACKAGE__->has_config("class") ) {
        return __PACKAGE__->config( ["class"] );
    }

    # use the name of the script to determine which AlertGizmo subclass to load
    my $progname = $PROGNAME;
    $progname =~ s/^alert-//x;    # remove alert- prefix from program name
    $progname =~ s/\.pl$//x;      # remove .pl suffix if present
    my $subclassname = __PACKAGE__ . "::" . ucfirst( lc($progname) );
    my $subclasspath = $subclassname . ".pm";
    $subclasspath =~ s/::/\//gx;
    try {
        require $subclasspath;
    } catch ($e) {
        croak "failed to load class $subclassname: $e";
    };
    if ( not $subclassname->isa(__PACKAGE__) ) {
        croak "error: $subclassname is not a subclass of " . __PACKAGE__;
    }
    return $subclassname;
}

# in test mode, dump program status for debugging
# This may be overridden by subclasses to display more specific dump info.
# In test mode it must exit after displaying the dump, as this does, and not proceed to network access.
sub test_dump
{
    my $class = shift;

    # in test mode, exit before messing with symlink or removing old files
    if ( $class->config_test_mode() ) {
        say STDERR "test mode: params=" . Dumper( $class->params() );
        exit 0;
    }
    return;
}

# network access utility function provided for use by subclasses
# originally based on WebFetch's get() method, modified to use File::Fetch instead
sub net_get
{
    my ( $class, $source, $params ) = @_;

    if ( not defined $source ) {
        AlertGizmo::Exception::NetworkGet->throw( "net_get: URI/URL source parameter missing" );
    }
    AlertGizmo::Config->verbose() and say STDERR "net_get(" . $source . ")\n";

    # unpack parameters if present
    my $file_path;
    if (( defined $params ) and ( ref $params eq "HASH" )) {
        if ( exists $params->{file} ) {
            $file_path = $params->{file};
        }
    }

    # send request, capture response
    my $ff = File::Fetch->new( uri => $source );
    my $content;
    $ff->fetch( to => \$content );

    # abort on failure
    if ( $ff->error( false ) ) {
        AlertGizmo::Exception::NetworkGet->throw( "The request received an error: " . $ff->error( true ) );
    }

    # write the content and return if a file path was specified
    if ( defined $file_path ) {
        open ( my $out_fh, ">", $file_path )
            or AlertGizmo::Exception::NetworkGet->throw( "net_get: failed to save $file_path: $!" );
        say $out_fh $content
            or AlertGizmo::Exception::NetworkGet->throw( "net_get: failed to write to $file_path: $!" );
        close $out_fh
            or AlertGizmo::Exception::NetworkGet->throw( "net_get: failed to close $file_path: $!" );
        return;
    }

    # return the content if a file path was not specified
    return $content;
}

# perform network request for a URL and save result in named file
# this is a common method that AlertGizmo as parent class provides to subclasses
sub retrieve_url
{
    my ( $class, $url ) = @_;
    my $paths = $class->paths();

    # perform network request
    if ( $class->config_test_mode() ) {
        if ( not -e $paths->{outlink} ) {
            croak "test mode requires $paths->{outlink} to exist";
        }
        say STDERR "*** skip network access in test mode ***";
    } else {
        my $proxy = $class->config_proxy();
        try {
            $class->net_get( $url, { file => $class->paths( ["outjson"] ) } );
        } catch ( $e ) {
            confess "failed to get URL ($url): " . $e;
        }

        # check results of request
        if ( -z $paths->{outjson} ) {
            croak "JSON data file " . $paths->{outjson} . " is empty";
        }
    }
    return;
}

# log generated files for use by postprocessing
sub log_generated_file
{
    my ( $class, %attr ) = @_;
    my %missing;
    foreach my $fname ( qw( path filetype ) ) {
        if ( not exists $attr{$fname}) {
            $missing{$fname} = 1;
        }
    }
    if ( %missing ) {
        croak "$class: missing params in log_generated_name() call: ".join( " ", sort keys %missing );
    }

    # make sure log array exists
    if ( not $class->has_config( "generated_files" )) {
        $class->$class->config( [ "generated_files" ], [] );
    }

    # add the new log entry
    my $genfiles_ref = $class->config( [ "generated_files" ] );
    my @log_entry = ( $class, $attr{ path }, $attr{ filetype } );
    push @$genfiles_ref, \@log_entry;
    return;
}

# get list of generated files, optionally filtered by content type or origin class
sub query_generated_file
{
    my ( $class, %attr ) = @_;
    my $q_class = $attr{class};
    my $q_type = $attr{type};

    # short-circuit results if no query parameters and just return everything
    my $genfiles_ref = $class->config( [ "generated_files" ] );
    if ( not defined $q_class and not defined $q_type ) {
        return @$genfiles_ref;
    }

    # scan for queried entries
    my @result;
    foreach my $entry ( @$genfiles_ref ) {
        if ( defined $q_class and $q_class eq $entry->[0]) {
            push @result, $entry;
            next;
        }
        if ( defined $q_type and $q_type eq $entry->[2]) {
            push @result, $entry;
            next;
        }
    }
    return @result;
}

# inner mainline called from main() exception-catching wrapper
sub main_inner
{
    my $class = gen_class_name();

    # load subclass-specific argument list, then read command line arguments
    my @cli_options = (@CLI_OPTIONS);
    if ( $class->can("cli_options") ) {
        push @cli_options, ( $class->cli_options());
    }
    GetOptions( AlertGizmo->options(), @cli_options );

    # save timestamp
    $class->params( [qw( timestamp )], dt2dttz( $class->config_timestamp() ) );

    # subclass-specific processing for before template
    if ( $class->can("pre_template") ) {
        $class->pre_template();
    }

    # process template
    my $config = {
        INCLUDE_PATH => $class->config_dir(),
        INTERPOLATE  => 1,                      # expand "$var" in plain text
        POST_CHOMP   => 1,                      # cleanup whitespace
        EVAL_PERL    => 0,                      # evaluate Perl code blocks
    };
    my $template = Template->new($config);
    my $gen_path_output = $class->config_dir() . "/" . $class->path_output();
    $template->process(
        $class->path_template(),
        $class->params(),
        $gen_path_output,
        binmode => ':utf8'
    ) or croak "template processing error: " . $template->error();
    $class->log_generated_file( "path" => $gen_path_output, "filetype" => "html" );

    # in test mode, exit before messing with symlink or removing old files
    $class->test_dump();

    # subclass-specific processing for after template
    if ( $class->can("post_template") ) {
        $class->post_template();
    }

    # use configuration file for post-processing controls, if provided
    if ( AlertGizmo::Postproc->load_prox()) {
        # if postproc data was loaded, process it
        AlertGizmo::Postproc->run_prox();
    }

    return;
}

# exception-catching wrapper for mainline
## no critic (Subroutines::RequireFinalReturn)
sub main
{
    # catch exceptions
    try {
        main_inner();
    } catch ($e) {

        # simple but a functional start until more specific exception-catching gets added
        if ( blessed $e ) {
            if ( $e->isa('AlertGizmo::Config::Exception::NotFound') ) {
                say "error: NotFound (name => " . $e->{name} . ")";
                exit 1;
            }
            if ( $e->isa('AlertGizmo::Config::Exception::NonIntegerIndex') ) {
                say "error: NonIntegerIndex (str => " . $e->{str} . ")";
                exit 1;
            }
            if ( $e->can("rethrow") ) {
                if ( $e->isa('Exception::Class') ) {
                    croak $_->error, "\n", $_->trace->as_string, "\n";
                }
                $e->rethrow();
            }
            croak "error (" . ( ref $e ) . "): $e";
        }
        croak "error: $e";
    }
    exit 0;
}
## critic (Subroutines::RequireFinalReturn)

1;

=pod

=encoding utf8

=head1 SYNOPSIS

    use AlertGizmo;
    use AlertGizmo::Subclass; # fictional subclass example, use an actual subclass (i.e. Neo, Swpc) in its place

    # set implementation subclass to example AlertGizmo::Subclass, then run AlertGizmo's main()
    AlertGizmo::Subclass->set_class();
    AlertGizmo->main();

=head1 DESCRIPTION

AlertGizmo is the module with core routines which its subclasses use to implement reading and processing news and alerts from the web.

Current subclasses which AlertGizmo was developed to support are AlertGizmo::Neo (NASA Near Earth Object "NEO") passes) and AlertGizmo::Swpc (NOAA Space Weather Prediction Center alerts for solar flares and aurora).

=head1 INSTALLATION

AlertGizmo is available by downloading from the Github repository.

=head2 Perl Development Environment

The source code repository is at L<https://github.com/ikluft/AlertGizmo> .

For a development environment, make sure Perl is installed. Check first if binary packages are available for your OS & p
latform. More information can be found at L<https://metacpan.org/dist/perl/view/INSTALL>.

Then install App::cpanminus (cpanm), Dist::Zilla (dzil) and Perl::Critic (perlcritic).

On Debian-based Linux systems they can be installed with this command as root:

    apt update
    apt install cpanminus libdist-zilla-perl libperl-critic-perl

On RPM-based Linux systems (Fedora, Red Hat and CentOS derivatives) as root:

    dnf install --refresh perl-App-cpanminus perl-Dist-Zilla perl-Perl-Critic

On Alpine Linux systems and containers:

    apk update && apk upgrade
    apk add make git perl perl-utils perl-alien-build perl-class-tiny perl-config-tiny perl-date-manip perl-datetime per
l-datetime-locale perl-datetime-timezone perl-dbd-csv perl-dbd-sqlite perl-dbi perl-http-date perl-ipc-run perl-list-mor
eutils perl-list-someutils perl-log-dispatch perl-log-log4perl perl-module-build perl-moose perl-moosex-types perl-names
pace-autoclean perl-net-ssleay perl-params-validate perl-perlio-utf8_strict perl-pod-parser perl-readonly perl-term-read
key perl-test-leaktrace perl-test-pod perl-test-warn perl-text-template perl-type-tiny perl-xml-dom perl-yaml
    cpan -T App::cpanminus Dist::Zilla Perl::Critic </dev/null

On operating systems which don't provide binary packages of App::cpanminus, Dist::Zilla or Perl::Critic, install them fr
om CPAN with this command:

    cpan -T App::cpanminus Dist::Zilla Perl::Critic </dev/null

=head2 Set up AlertGizmo

Download AlertGizmo source code with the git command:

    git clone https://github.com/ikluft/AlertGizmo.git

Run these Dist::Zilla commands to set up the environment for build, test and install:

    # note: if/when more language implementations begin, a step would be added to change into a subdirectory for Perl
    dzil authordeps --missing | cpanm --notest
    dzil listdeps --missing | cpanm --notest
    dzil build
    dzil test
    dzil install

Prior to submitting pull requests for consideration for inclusion in the package, additional tests can be performed with the author and/or release options:

    dzil test --author
    dzil test --release

=head2 Running from a crontab

To run AlertGizmo from a crontab, first use 'crontab -l' to determine if you have one set up, and that the crontab command is installed. (If it isn't installed, Linux packages such as L<cronie|https://github.com/cronie-crond/cronie> can perform L<modern cron|https://en.wikipedia.org/wiki/Cron#Modern_versions> functions. If on a small embedded Linux system, L<BusyBox|https://en.wikipedia.org/wiki/BusyBox> or L<Toybox|https://en.wikipedia.org/wiki/Toybox> also provide a crontab command.)

When run in normal mode, the scripts pull new data from the network. When run in test mode with the --test flag on the command line, they use saved data from prior network accesses but do not make a new network access.

If you have a crontab already, preserve its contents by saving it to a file we'll call 'my-crontab' with this command:

    crontab -l > my-crontab

Otherwise create the 'my-crontab' file empty from scratch with a text editor.

Add these lines to the 'my-crontab' file, replacing "path/to/script" with your path where these scripts are installed and using your local time zone instead of US/Pacific (the author's local time zone).

    CRON_TZ=UTC

    # access NASA JPL NEO API 8 times per day and just after midnight UTC
    1 0 * * *       $HOME/path/to/script/pull-nasa-neo.pl --tz="US/Pacific"
    31~44 */3 * * * $HOME/path/to/script/pull-nasa-neo.pl --tz="US/Pacific"

    # access NOAA Space Weather Predition Center alerts every 2 hours
    11~24 */2 * * * $HOME/path/to/script/pull-swpc-alerts.pl --tz="US/Pacific"

Then install the crontab by running:

    crontab my-crontab

=head1 FUNCTIONS AND METHODS

=over 4

=item $obj->net_get ( $url )

This WebFetch utility function will get a URL and return a reference
to a scalar with the retrieved contents.

In case of an error, it throws an exception.

=back

=head1 LICENSE

I<AlertGizmo> and its submodules are Open Source software licensed under the GNU General Public License Version 3.
See L<https://www.gnu.org/licenses/gpl-3.0-standalone.html>.

=head1 SEE ALSO

L<WebFetch>, L<XML::Feed>

=head1 BUGS AND LIMITATIONS

Please report bugs via GitHub at L<https://github.com/ikluft/AlertGizmo/issues>

Patches and enhancements may be submitted via a pull request at L<https://github.com/ikluft/AlertGizmo/pulls>

=cut
