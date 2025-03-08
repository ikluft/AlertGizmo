# AlertGizmo::Postproc
# ABSTRACT: common code for for AlertGizmo postprocessing classes
# Copyright (c) 2025 by Ian Kluft

# pragmas to silence some warnings from Perl::Critic
## no critic (Modules::RequireExplicitPackage)
# This solves a catch-22 where parts of Perl::Critic want both package and use-strict to be first
use Modern::Perl qw(2023);    # includes strict & warnings
## use critic (Modules::RequireExplicitPackage)

package AlertGizmo::Postproc;

use utf8;
use autodie;
use experimental qw(builtin try);
use feature      qw(say try);
use builtin      qw(true false);
use Carp         qw(carp croak confess);
use Module::Load;
use AlertGizmo; # should always already be loaded because it calls us
use YAML qw(LoadFile);

# load YAML data from post-processing configuration file path
# returns 1 if postproc data was loaded, otherwise 0
sub load
{
    if ( AlertGizmo->has_config(qw(options postproc)) ) {
        my $postproc_path = AlertGizmo->options( ["postproc"] );
        my $postproc_yaml = LoadFile( $postproc_path );
        AlertGizmo->params( ["postprox"], $postproc_yaml );
        return 1;
    }
    return 0;
}

# perform postprocessing
sub run
{
    # load postprocessing instructions from first YAML doc
    my $postprox_top_ref = AlertGizmo->params( ["postprox"]);
    if ( ref $postprox_top_ref ne "ARRAY" ) {
        carp "invalid postprocessing structure: doc list expected, not an array ref";
        return;
    }
    if ( ref $postprox_top_ref->[0] ne "ARRAY" ) {
        carp "invalid postprocessing structure: instruction list expected, not an array ref";
        return;
    }
    my @postprox = @{$postprox_top_ref->[0]};

    # handle postprocessing instructions
    foreach my $pp ( @postprox ) {
        if ( ref $pp ne "HASH" ) {
            carp "invalid postprocessing structure: entry is not a hashref";
            next;
        }
        my %pp = %$pp;
        if ( not exists $pp{class} ) {
            carp "invalid postprocessing structure: entry hash does not contain a class key";
            next;
        }
        Module::Load::autoload( $pp{class} );
        if ( not $pp{class}->isa( __PACKAGE__ ) ) {
            carp "invalid postprocessing structure: entry class ".$pp{class}." is not a subclass of ".__PACKAGE__;
            next;
        }

        # TODO
    }

    # TODO
    return;
}

1;

=pod

=encoding utf8

=head1 SYNOPSIS

    use AlertGizmo::Postproc;

    # this is how AlertGizmo calls AlertGizmo::Postproc
    if ( AlertGizmo::Postproc->load()) {
        AlertGizmo::Postproc->run();
    }

=head1 DESCRIPTION

=head1 INSTALLATION

=head1 FUNCTIONS AND METHODS

=head1 LICENSE

I<AlertGizmo> and its submodules are Open Source software licensed under the GNU General Public License Version 3.
See L<https://www.gnu.org/licenses/gpl-3.0-standalone.html>.

=head1 SEE ALSO

=head1 BUGS AND LIMITATIONS

Please report bugs via GitHub at L<https://github.com/ikluft/AlertGizmo/issues>

Patches and enhancements may be submitted via a pull request at L<https://github.com/ikluft/AlertGizmo/pulls>

=cut
