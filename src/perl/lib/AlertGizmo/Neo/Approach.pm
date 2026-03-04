# AlertGizmo::Neo
# ABSTRACT: Per-approach record data for AlertGizmo monitor for NASA JPL Near-Earth Object (NEO) passes
# Copyright 2024-2026 by Ian Kluft

# pragmas to silence some warnings from Perl::Critic
## no critic (Modules::RequireExplicitPackage)
# This solves a catch-22 where parts of Perl::Critic want both package and use-strict to be first
use Modern::Perl qw(2023);
# includes strict & warnings, boolean requires 5.36, try/catch requires 5.34
## use critic (Modules::RequireExplicitPackage)

package AlertGizmo::Neo::Approach;

use utf8;
use autodie;
use experimental qw(builtin try);
use feature      qw(say try);
use builtin      qw(true false);
use charnames    qw(:loose);
use Carp qw(confess);
use AlertGizmo::Config;
use Data::Dumper;

# contants for AlertGizmo::Neo::Approach;
Readonly::Scalar my $NEO_LINK_URL => "https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html#/?sstr=";
Readonly::Scalar my $E_RADIUS     => 6378;
Readonly::Scalar my $KM_IN_AU     => 1.4959787e+08;
Readonly::Scalar my $UC_QMARK     => "\N{fullwidth question mark}";    # Unicode question mark
Readonly::Scalar my $UC_NDASH     => "\N{en dash}";                    # Unicode dash
Readonly::Scalar my $UC_PLMIN     => "\N{plus minus sign}";            # Unicode plus-minus sign
 

# instantiate new object
# required parameter: hash ref with NEO/asteroid parameters from NASA JPL data
sub new
{
    my ( $class, $raw_neo_ref ) = @_;
    if ( ref $raw_neo_ref ne "ARRAY" ) {
        my $type = ( ref $raw_neo_ref ) ? "".( ref $raw_neo_ref )." ref" : "scalar";
        confess "" . __PACKAGE__ . "::new($class): expected arrayref, got $type";
    }
    AlertGizmo::Config->verbose() and say STDERR __PACKAGE__ . "::new($class): ".Dumper( $raw_neo_ref );
    my $self = {};
    bless $self, $class;
    $self->init( $raw_neo_ref );

    return $self;
}

# initialize NEO entry from NASA JPL data
sub init
{
    my ( $self, $raw_neo_ref ) = @_;

    # start NEO record
    $self->{des}   = $raw_neo_ref->[ AlertGizmo::Config->params( [qw( fnum des )] ) ];
    $self->{cd}    = $raw_neo_ref->[ AlertGizmo::Config->params( [qw( fnum cd )] ) ];
    $self->{v_rel} = int( $raw_neo_ref->[ AlertGizmo::Config->params( [qw( fnum v_rel )] ) ] + 0.5 );

    # distance computation
    $self->get_dist_km( $raw_neo_ref, AlertGizmo::Config->params() );

    # closest approact in local timezone (for mouseover text)
    my $cd_dt = DateTime::Format::Flexible->parse_datetime( $self->{cd} . ":00 UTC" )
        ->set_time_zone( AlertGizmo::Config->timezone() );
    $self->{cd_local} = AlertGizmo::dt2dttz($cd_dt);

    # background color computation based on distance
    $self->{bgcolor} = dist2bgcolor( $self->{dist} );

    # diameter is not always known - must deal with missing or null values
    $self->get_diameter( $raw_neo_ref, AlertGizmo::Config->params() );

    # cell background for diameter
    $self->{diameter_bgcolor} = diameter2bgcolor( $self->{diameter} );

    # set URL for NASA JPL NEO web info on this NEO approach
    $self->{link} = $NEO_LINK_URL . URI::Escape::uri_escape_utf8( $self->{des} );

    return;
}

# internal computation for bgcolor for each table, called by dist2bgcolor()
sub _dist2rgb
{
    my $dist = shift;

    # green for over 350000km
    if ( $dist >= 350000 ) {
        return ( 0, 255, 0 );
    }

    # 150k-250k km -> ramp from green #00FF00 to yellow #FFFF00
    if ( $dist >= 250000 ) {
        my $ramp = 255 - int( ( $dist - 250000 ) / 100000 * 255 );
        return ( $ramp, 255, 0 );
    }

    # 50k-150k km -> ramp from yellow #7F7F00 to orange #7F5300
    if ( $dist >= 150000 ) {
        my $ramp = 165 + int( ( $dist - 150000 ) / 100000 * 91 );
        return ( 255, $ramp, 0 );
    }

    # 50k-150k km -> ramp from orange #7F5300 to red #7F0000
    if ( $dist >= 50000 ) {
        my $ramp = int( ( $dist - 50000 ) / 100000 * 165 );
        return ( 255, $ramp, 0 );
    }

    # surface-50000 km -> red bg
    if ( $dist >= $E_RADIUS ) {
        return ( 255, 0, 0 );
    }

    # less than surface -> BlueViolet bg (impact!)
    return ( 138, 43, 226 );
}

# compute bgcolor for each table row based on NEO distance at closest approach
sub dist2bgcolor
{
    # background color computation based on distance
    my $dist_min_km = shift;
    my ( $red, $green, $blue );

    ( $red, $green, $blue ) = _dist2rgb($dist_min_km);

    # return RGB string
    return sprintf( "#%02X%02X%02X", $red, $green, $blue );
}

# internal computation for bgcolor for table cell, called by diameter2bgcolor()
sub _diameter2rgb
{
    my $diameter_str = shift;

    # deal with unknown diameter
    if ( $diameter_str eq $UC_QMARK ) {
        return ( 192, 192, 192 );
    }

    my $diameter;
    if ( $diameter_str =~ /^ ( \d+ ) $UC_NDASH ( \d+ ) $/x ) {

        # if an estimated range of diameters was provided, use the top end for the cell color
        $diameter = int($2);
    } else {

        # otherwise use the initial integer as a median value
        $diameter_str =~ s/[^\d] .*//x;
        $diameter = int($diameter_str);
    }

    # green for under 20m
    if ( $diameter <= 30 ) {
        return ( 0, 255, 0 );
    }

    # 20-75m -> ramp from green #00FF00 to yellow #FFFF00
    if ( $diameter <= 75 ) {
        my $ramp = int( ( $diameter - 20 ) / 55 * 255 );
        return ( $ramp, 255, 0 );
    }

    # 75-140m -> ramp from yellow #7F7F00 to orange #7F5300
    if ( $diameter <= 140 ) {
        my $ramp = 165 + int( ( $diameter - 75 ) / 65 * 91 );
        return ( 255, $ramp, 0 );
    }

    # 140-1000m -> ramp from orange #7F5300 to red #7F0000
    if ( $diameter <= 1000 ) {
        my $ramp = int( ( $diameter - 140 ) / 860 * 165 );
        return ( 255, $ramp, 0 );
    }

    # over 1000m -> red bg
    return ( 255, 0, 0 );
}

# compute bgcolor for table cell based on NEO diameter
sub diameter2bgcolor
{
    # background color computation based on distance
    my $diameter_min_km = shift;
    my ( $red, $green, $blue );

    ( $red, $green, $blue ) = _diameter2rgb($diameter_min_km);

    # return RGB string
    return sprintf( "#%02X%02X%02X", $red, $green, $blue );
}

# get distance as km (convert from AU)
sub get_dist_km
{
    my ( $self, $raw_item ) = @_;

    foreach my $param_name (qw(dist dist_min dist_max)) {
        my $dist_au = $raw_item->[ AlertGizmo::Config->params( [ "fnum", $param_name ] ) ];
        my $dist_km = $dist_au * $KM_IN_AU;
        $self->{$param_name} = int( $dist_km + 0.5 );
    }
    return;
}

# convert magnitude (h) to estimated diameter in m
sub h_to_diameter_m
{
    my ( $h, $p ) = @_;
    my $ee = -0.2 * $h;
    return 1329.0 / sqrt($p) * ( 10**$ee ) * 1000.0;
}

# get diameter as a printable string
# if diameter data exists, format diameter +/- diameter_sigma
# otherwise estimate diameter from magnitude (see https://www.physics.sfasu.edu/astro/asteroids/sizemagnitude.html )
sub get_diameter
{
    my ( $self, $raw_item ) = @_;

    # if diameter data was provided, use it
    my $fnum_diameter = AlertGizmo::Config->params( [qw( fnum diameter )] );
    if (    ( exists $raw_item->[$fnum_diameter] )
        and ( defined $raw_item->[$fnum_diameter] )
        and ( $raw_item->[$fnum_diameter] ne "null" ) )
    {
        # diameter data found - format it with or without diameter_sigma
        my $diameter            = "" . int( $raw_item->[ $fnum_diameter * 1000.0 ] + 0.5 );
        my $fnum_diameter_sigma = AlertGizmo::Config->params( [qw( fnum diameter_sigma )] );
        if (    ( exists $raw_item->[$fnum_diameter_sigma] )
            and ( defined $raw_item->[$fnum_diameter_sigma] )
            and ( $raw_item->[$fnum_diameter_sigma] ne "null" ) )
        {
            $diameter .=
                " " . $UC_PLMIN . " " . int( $raw_item->[$fnum_diameter_sigma] * 1000.0 + 0.5 );
        }
        $self->{diameter} = $diameter;
        return;
    }

    # if magnitude data was provided, estimate diameter from it
    # according to API definition, h (absolute magnitude) should be provided
    my $fnum_h = AlertGizmo::Config->params( [qw( fnum h )] );
    if (    ( exists $raw_item->[$fnum_h] )
        and ( defined $raw_item->[$fnum_h] )
        and ( $raw_item->[$fnum_h] ne "null" ) )
    {
        my $min = int( h_to_diameter_m( $raw_item->[$fnum_h], 0.25 ) + 0.5 );
        my $max = int( h_to_diameter_m( $raw_item->[$fnum_h], 0.05 ) + 0.5 );
        $self->{diameter} = $min . $UC_NDASH . $max;
        return
    }

    # if diameter and magnitude were both unknown, deal with missing data by displaying a question mark
    $self->{diameter} = $UC_QMARK;
    return;
}

1;

=pod

=encoding utf8

=head1 SYNOPSIS

    # for internal use by AlertGizmo::Neo
    use AlertGizmo::Neo::Approach;

=head1 DESCRIPTION

AlertGizmo::Neo::Approach must be instantiated with per-approach data from NASA JPL on an asteroid close approach.

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
