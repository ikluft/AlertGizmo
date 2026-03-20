# AlertGizmo::Neo::Hazard
# ABSTRACT: AlertGizmo NEO monitor per-approach hazard data including risk/severity and color to display
# Copyright 2026 by Ian Kluft

# pragmas to silence some warnings from Perl::Critic
## no critic (Modules::RequireExplicitPackage)
# This solves a catch-22 where parts of Perl::Critic want both package and use-strict to be first
use Modern::Perl qw(2023);
# includes strict & warnings, boolean requires 5.36, try/catch requires 5.34
## use critic (Modules::RequireExplicitPackage)

package AlertGizmo::Neo::Hazard;

use utf8;
use autodie;
use experimental qw(builtin try);
use feature      qw(say try);
use builtin      qw(true false);
use charnames    qw(:loose);
use Readonly;
use AlertGizmo::Config;
use Params::Util qw(_ARRAY _POSINT);
use Data::Dumper;

# exceptions/errors
use Exception::Class (
    'AlertGizmo::Neo::Hazard::Exception',

    'AlertGizmo::Neo::Hazard::Exception::ParameterError' => {
        isa         => 'AlertGizmo::Neo::Hazard::Exception',
        alias       => 'throw_parameter_error',
        description => "Parameter error",
    },

);

# contants for AlertGizmo::Neo::Hazard
Readonly::Array  my @categories => qw(dist size vel);
Readonly::Scalar my $E_RADIUS   => 6378;
Readonly::Scalar my $UC_QMARK     => "\N{fullwidth question mark}";    # Unicode question mark
Readonly::Scalar my $UC_NDASH     => "\N{en dash}";                    # Unicode dash

#
# utility functions

# generate hex color string from array of red/green/blue integers
sub _hexcolor
{
    my ( $red, $green, $blue ) = @_;
    return sprintf( "#%02X%02X%02X", $red, $green, $blue );
}

# linear interpolation of a ramped value within a given range
# use x values as input range, y values as output range
# x (provided) is the input value in the range x0-x1
# y (computed) is the output value at the same proportion in the range y0-y1
# for more info see https://en.wikipedia.org/wiki/Linear_interpolation
sub _ramp
{
    my ( $x, $x0, $x1, $y0, $y1 ) = @_;
    my $y = ( $y0 * ( $x1 - $x ) + $y1 * ( $x - $x0 )) / ( $x1 - $x0 );
    return $y;
}

# compute color/priority by distance for each NEO, called by _dist2color()
# returns array: red, green, blue, priority (0-10)
sub _dist2rgbp
{
    my $dist = shift;

    # green for over 350000km
    if ( $dist >= 350000 ) {
        return ( 0, 255, 0, 0 );
    }

    # 250k-350k km -> ramp from green #00FF00 to yellow #FFFF00, priority increases 0.0-3
    if ( $dist >= 250000 ) {
        return (
            _ramp( $dist, 250000, 350000, 0, 255),
            255,
            0,
            _ramp( $dist, 250000, 350000, 3.333, 0.0 )
        );
    }

    # 150k-250k km -> ramp from yellow #FFFF00 to orange #FF5300, priority increases 3-6
    if ( $dist >= 150000 ) {
        return (
            255,
            _ramp( $dist, 150000, 250000, 165, 255 ),
            0,
            _ramp( $dist, 150000, 250000, 6, 3 )
        );
    }

    # 50k-150k km -> ramp from orange #FF5300 to red #FF0000, priority increases 6-9
    if ( $dist >= 50000 ) {
        return (
            255,
            _ramp( $dist, 50000, 150000, 0, 165 ),
            0,
            _ramp( $dist, 50000, 150000, 9, 6 )
        );
    }

    # surface-50000 km -> red bg, priority increases 9-10
    if ( $dist >= $E_RADIUS ) {
        return (
            255,
            0,
            0,
            _ramp( $dist, $E_RADIUS, 50000, 10, 9 )
        );
    }

    # less than surface -> BlueViolet bg (impact!)
    # This should not be called for impact prioritization. This is a default placeholder not intended to be used.
    return ( 138, 43, 226, 10 );
}

# compute bgcolor and priority for each NEO based on distance at closest approach
sub _dist2color
{
    # background color computation based on distance
    my $dist_min_km = shift;

    my ( $red, $green, $blue, $priority ) = _dist2rgbp($dist_min_km);

    # return RGB string
    return ( _hexcolor( $red, $green, $blue ), $priority );
}

# compute color/priority for table cell, called by _diameter2color()
sub _diameter2rgbp
{
    my $diameter_str = shift;

    # deal with unknown diameter
    if ( $diameter_str eq $UC_QMARK ) {
        return ( 192, 192, 192, 0 );
    }

    my $diameter;
    if ( $diameter_str =~ /^ ( \d+ ) $UC_NDASH ( \d+ ) $/x ) {

        # if an estimated range of diameters was provided, use the average for the cell color
        $diameter = int(($1 + $2) / 2);
    } else {

        # otherwise use the initial integer as a median value
        $diameter_str =~ s/[^\d] .*//x;
        $diameter = int($diameter_str);
    }

    # green for under 20m, priority 0
    if ( $diameter <= 30 ) {
        return ( 0, 255, 0, 0 );
    }

    # 20-75m -> ramp from green #00FF00 to yellow #FFFF00, priority 0-3
    if ( $diameter <= 75 ) {
        return (
            _ramp( $diameter, 20, 75, 0, 255 ),
            255,
            0,
            _ramp( $diameter, 20, 75, 0, 3 )
        );
    }

    # 75-140m -> ramp from yellow #FFFF00 to orange #FF5300, priority 3-6
    if ( $diameter <= 140 ) {
        return (
            255,
            _ramp( $diameter, 75, 140, 255, 83 ),
            0,
            _ramp( $diameter, 75, 140, 3, 6 )
        );
    }

    # 140-1000m -> ramp from orange #FF5300 to red #FF0000, priority 6-9
    if ( $diameter <= 1000 ) {
        return (
            255,
            _ramp( $diameter, 140, 1000, 83, 0 ),
            0,
            _ramp( $diameter, 140, 1000, 6, 9 )
        );
    }

    # over 1000m -> red bg, priority 9
    return ( 255, 0, 0, 9 );
}

# compute color/priority based on NEO diameter
sub _diameter2color
{
    # background color computation based on distance
    my $diameter_min_km = shift;

    my ( $red, $green, $blue, $priority ) = _diameter2rgbp($diameter_min_km);

    # return RGB string
    return ( _hexcolor( $red, $green, $blue ), $priority );
}

# compute color/priority for table cell, called by _vel2color()
# divisions of colors and priorities are based on Feb 2026 summary of NASA JPL NEO approach database
# mean/average NEO relative velocity: 10.57, std deviation: 5.09, min: 0.86, max: 42.92
# This is interpreted as
#   0-15: green, priority 0
#   15-25: green-yellow, priority 0-3
#   25-35: yellow-orange, priority 3-6
#   35-45: orange-red, priority 6-9
#   45+: red, priority 9
sub _vel2rgbp
{
    my $vel = shift;

    # 25+ km/s: red, priority 9
    if ( $vel > 45 ) {
        return ( 255, 0, 0, 9 );
    }

    # 20-25 km/s: orange #FF5300 to red #FF0000, priority 6-9
    if ( $vel > 35 ) {
        return (
            255,
            _ramp( $vel, 35, 45, 83, 0 ),
            0,
            _ramp( $vel, 35, 45, 6, 9 )
        );
    }

    # 15-20 km/s: yellow #FFFF00 to orange #FF5300, priority 3-6
    if ( $vel > 25 ) {
        return (
            255,
            _ramp( $vel, 25, 35, 255, 83 ),
            0,
            _ramp( $vel, 25, 35, 3, 6 )
        );
    }

    # 10-15 km/s: green #00FF00 to yellow #FFFF00, priority 0-3
    if ( $vel > 15 ) {
        return (
            _ramp( $vel, 15, 25, 0, 255 ),
            255,
            0,
            _ramp( $vel, 15, 25, 0, 3 )
        );
    }

    # less than 10 km/h: green, priority 0
    return ( 0, 255, 0, 0 );
}

# compute color/priority based on NEO velocity
sub _vel2color
{
    # background color computation based on velocity
    my $vel = shift;

    my ( $red, $green, $blue, $priority ) = _vel2rgbp($vel);

    # return RGB string
    return ( _hexcolor( $red, $green, $blue ), $priority );
}

# compute color/priority for forecasted impact events based on estimated diameter
# estimated priority based on Torino Scale parameters with near-certain impact probability
# See https://en.wikipedia.org/wiki/Torino_scale
# 
# This is interpreted as
# 0-20m (or unknown): teal, priority 10
# 20m-100m: teal-navyblue, priority 10-13
# 100m-1000m: navyblue-webpurple, priority 13-16
# 1000m-5000m: purple-magenta, priority 16-20
sub _impact_color
{
    my $self = shift;
    my $neo_size = $self->size();

    # deal with unknown diameter
    if ( $neo_size eq $UC_QMARK ) {
        return ( 0, 128, 128, 10 );
    }

    # 0-20m (or unknown): teal, priority 10
    if ( $neo_size < 20 ) {
        return ( 0, 128, 128, 10 );
    }

    # 20m-100m: teal-navyblue, priority 10-13
    if ( $neo_size < 100 ) {
        return (
            0,
            _ramp( $neo_size, 20, 100, 128, 0 ),
            128,
            _ramp( $neo_size, 20, 100, 10, 13 )
        );
    }

    # 100m-1000m: navyblue-webpurple, priority 13-16
    if ( $neo_size < 1000 ) {
        return (
            _ramp( $neo_size, 100, 1000, 0, 128 ),
            0,
            128,
            _ramp( $neo_size, 100, 1000, 13, 16 )
        );
    }

    # 1000m-5000m: purple-magenta, priority 16-20
    # (we never want to see this outside of sw testing: it would be an extinction level event)
    if ( $neo_size < 5000 ) {
        return (
            _ramp( $neo_size, 1000, 5000, 128, 255 ),
            0,
            _ramp( $neo_size, 1000, 5000, 128, 255 ),
            _ramp( $neo_size, 1000, 5000, 16, 20 )
        );
    }

    # >5000m: magenta, priority=20
    # (we never want to see this outside of sw testing: it would be an extinction level event)
    return ( 255, 0, 255, 20 );
}

#
# object instantiation & initialization
#

# instantiate new object
# hazard description parameter is a list of key/value pairs to compute hazards from
#   dist = distance in km as arrayref with min/avg/max distances (only avg used, unless any are impact trajectory)
#   size = diameter in m
#   vel  = relative velocity in km/s
sub new
{
    my ( $class, %hazard_desc ) = @_;
    AlertGizmo::Config->verbose() and say STDERR __PACKAGE__ . "::new($class): ".Dumper( \%hazard_desc );

    # instantiate object
    my $self = {};
    bless $self, $class;
    $self->init( %hazard_desc );

    return $self;
}

# initialize NEO hazard data
sub init
{
    my ( $self, %hazard_desc ) = @_;

    # verify parameter list
    if ( scalar %hazard_desc == 0 ) {
        throw_parameter_error( __PACKAGE__ . ": missing hazard parameters - empty list" );
    }
    foreach my $key ( @categories ) {
        if ( not exists $hazard_desc{$key}) {
            throw_parameter_error( __PACKAGE__ . ": missing hazard parameter $key" );
        }
        if ( $key eq "dist" ) {
            if ( not _ARRAY $hazard_desc{$key} ) {
                throw_parameter_error( __PACKAGE__ . ": dist must be an array reference to min/avg/max distances" );
            }
            if ( not defined $hazard_desc{$key}[0] and not defined $hazard_desc{$key}[2] ) {
                # if neither min_dist or max_dist were provided, then only require dist
                if ( not _POSINT $hazard_desc{$key}[1] ) {
                    throw_parameter_error( __PACKAGE__ . ": dist[1] must be a positive integer" );
                }
            } else {
                # if all were provided, check that distances are positive integers
                foreach my $i (0..2) {  # note: integer ranges are inclusive in Perl
                    if ( not _POSINT $hazard_desc{$key}[$i] ) {
                        throw_parameter_error( __PACKAGE__ . ": dist[$i] must be a positive integer" );
                    }
                }
                if ( $hazard_desc{$key}[0] > $hazard_desc{$key}[1] or $hazard_desc{$key}[1] > $hazard_desc{$key}[2] ) {
                    throw_parameter_error( __PACKAGE__ . ": dist min/avg/max must be integers in ascending order" );
                }
            }
        } elsif ( ref $hazard_desc{$key}) {
            throw_parameter_error( __PACKAGE__ . ": $key must be scalar" );
        }
        $self->{$key} = {};
        $self->{$key}{param} = $hazard_desc{$key};
    }

    # distance hazard
    $self->_init_dist();

    # size hazard
    $self->_init_size();

    # velocity hazard
    $self->_init_vel();

    # compute maximum hazard color and priority
    $self->_init_max();

    return;
}

# initialize distance hazard data
sub _init_dist
{
    my $self = shift;

    # distance hazard
    # different set of colors if any of min/avg/max are less then $E_RADIUS, indicating impact trajectory
    if ( $self->min_dist() < $E_RADIUS or $self->dist() < $E_RADIUS or $self->max_dist() < $E_RADIUS ) {
        # impact trajectory: compute probability as proportion of min-max distances which is less than Earth radius
        if ( $self->max_dist() < $E_RADIUS ) {
            $self->{dist}{impact} = 1.0;
        } else {
            $self->{dist}{impact} = ( $E_RADIUS - $self->min_dist()) / ($self->max_dist() - $self->min_dist());
        }
        $self->{dist}{color} = _hexcolor( 0, 255 - int( $self->{dist}{impact} * 255), 255 );
        $self->{dist}{priority} = $self->_impact_color();
    } else {
        # NEO will pass without impact (used for vast majority)
        my ( $rgb, $priority ) = _dist2color( $self->dist() );
        $self->{dist}{color} = $rgb;
        $self->{dist}{priority} = $priority;
    }

    return;
}

# initialize size hazard data
sub _init_size
{
    my $self = shift;

    my ( $rgb, $priority ) = _diameter2color( $self->size() );
    $self->{size}{color} = $rgb;
    $self->{size}{priority} = $priority;

    return;
}

# initialize velocity hazard data
sub _init_vel
{
    my $self = shift;

    my ( $rgb, $priority ) = _vel2color( $self->vel() );
    $self->{vel}{color} = $rgb;
    $self->{vel}{priority} = $priority;

    return;
}

# compute maximum hazard color and priority
sub _init_max
{
    my $self = shift;

    $self->{max} = {};
    if ( exists $self->{dist}{impact} ) {
        # if a nonzero impact probability exists, ignore everything else and use that color/priority
        $self->{max}{color} = $self->{dist}{color};
        $self->{max}{priority} = $self->{dist}{priority};
        $self->{max}{remark} = sprintf( "impact %d%%", int( $self->{dist}{impacty} * 100 ));
    } else {
        # select maximum priority - no need for a loop with only 3 choices
        my $max_key = "dist";
        if ( $self->{size}{priority} > $self->{$max_key}{priority}) {
            $max_key = "size";
        }
        if ( $self->{vel}{priority} > $self->{$max_key}{priority}) {
            $max_key = "vel";
        }
        $self->{max}{color} = $self->{$max_key}{color};
        $self->{max}{priority} = $self->{$max_key}{priority};
    }

    return;
}

#
# accessors
#

# field accessors
sub min_dist { my $self = shift; return $self->{dist}{param}[0] // $self->{dist}{param}[1]; }
sub dist { my $self = shift; return $self->{dist}{param}[1]; }
sub max_dist { my $self = shift; return $self->{dist}{param}[2] // $self->{dist}{param}[1]; }
sub size { my $self = shift; return $self->{size}{param}; }
sub vel { my $self = shift; return $self->{vel}{param}; }

# get display color by hazard category
sub color
{
    my ( $self, $category ) = @_;

    if ( not exists $self->{$category} or not exists $self->{$category}{color} ) {
        throw_parameter_error( __PACKAGE__ . ": no color available for $category" );
    }
    return $self->{$category}{color};
}

# test and get remark
sub has_remark { my $self = shift; return exists $self->{max}{remark}; }
sub remark { my $self = shift; return $self->{max}{remark}; }


1;

=pod

=encoding utf8

=head1 SYNOPSIS

    # for internal use by AlertGizmo::Neo::Approach
    use AlertGizmo::Neo::Hazard;

=head1 DESCRIPTION

AlertGizmo::Neo::Hazard contains hazard-level info for each NEO line on the display.
In particular, it computes the color to display and priority level for distance, size and velocity parameters,
as well as determining which of those is the highest priority.

=head1 FUNCTIONS AND METHODS

=head1 LICENSE

I<AlertGizmo> and its submodules are Open Source software licensed under the GNU General Public License Version 3.
See L<https://www.gnu.org/licenses/gpl-3.0-standalone.html>.

=head1 SEE ALSO

L<AlertGizmo>,
L<AlertGizmo::Neo>

=head1 BUGS AND LIMITATIONS

Please report bugs via GitHub at L<https://github.com/ikluft/AlertGizmo/issues>

Patches and enhancements may be submitted via a pull request at L<https://github.com/ikluft/AlertGizmo/pulls>

=cut
