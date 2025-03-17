# AlertGizmo::Postproc::Image
# ABSTRACT: generate images from AlertGizmo data
# Copyright (c) 2025 by Ian Kluft

# pragmas to silence some warnings from Perl::Critic
## no critic (Modules::RequireExplicitPackage)
# This solves a catch-22 where parts of Perl::Critic want both package and use-strict to be first
use Modern::Perl qw(2023);    # includes strict & warnings
## use critic (Modules::RequireExplicitPackage)

package AlertGizmo::Postproc::Image;

use parent "AlertGizmo::Postproc";

use utf8;
use autodie;
use experimental qw(builtin try);
use feature      qw(say try);
use builtin      qw(true false);
use Carp         qw(carp croak confess);

# generate image during postprocessing for AlertGizmo
sub run
{
    my $self = shift;

    # TODO
    return;
}

1;

=pod

=encoding utf8

=head1 SYNOPSIS

    use AlertGizmo::Postproc::Image;

    # called by AlertGizmo::Postproc
    # should not be called from user code except for testing
    @result = AlertGizmo::Postproc::Image->( \%pp );

=head1 DESCRIPTION

AlertGizmo::Postproc::Image is a post-processing plugin to generate images from AlertGizmo data.

=head1 FUNCTIONS AND METHODS

=head1 LICENSE

I<AlertGizmo> and its submodules are Open Source software licensed under the GNU General Public License Version 3.
See L<https://www.gnu.org/licenses/gpl-3.0-standalone.html>.

=head1 SEE ALSO

L<AlertGizmo::Postproc>

=head1 BUGS AND LIMITATIONS

Please report bugs via GitHub at L<https://github.com/ikluft/AlertGizmo/issues>

Patches and enhancements may be submitted via a pull request at L<https://github.com/ikluft/AlertGizmo/pulls>

=cut

