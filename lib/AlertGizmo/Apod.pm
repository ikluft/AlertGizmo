# AlertGizmo::Apod
# ABSTRACT: AlertGizmo monitor for NASA Astronomy Picture of the Day (APOD) feed
# Copyright 2024 by Ian Kluft

# pragmas to silence some warnings from Perl::Critic
## no critic (Modules::RequireExplicitPackage)
# This solves a catch-22 where parts of Perl::Critic want both package and use-strict to be first
use Modern::Perl qw(2023);
# includes strict & warnings, boolean requires 5.36, try/catch requires 5.34
## use critic (Modules::RequireExplicitPackage)

package AlertGizmo::Swpc;

use parent "AlertGizmo";

use utf8;
use autodie;
use experimental qw(builtin try);
use feature      qw(say try);
use builtin      qw(true false);
use charnames    qw(:loose);
use Readonly;
use Carp qw(croak confess);
use File::Basename;

# constants
Readonly::Scalar my $APOD_RSS_URL => "https://apod.nasa.gov/apod.rss";
Readonly::Scalar my $RSS_XSL_STYLESHEET => "rss.xsl";
Readonly::Scalar my $TEMPLATE      => "apod-alerts.tt";
Readonly::Scalar my $OUTHTML       => "apod-alerts.html";

# get APoD feed and save result in named file
sub read_apod_feed
{
    # read APoD feed
    __PACKAGE__->retrieve_url( $APOD_RSS_URL );
    return;
}

# get template path for this subclass
# class method
sub path_template
{
    return $TEMPLATE;
}

# get output file path for this subclass
# class method
sub path_output
{
    return $OUTHTML;
}

# class method AlertGizmo (parent) calls before template processing
sub pre_template
{
    my $class = shift;

    # TODO

    return;
}

# class method AlertGizmo (parent) called after template processing
sub post_template
{
    my $class = shift;

    # TODO

    return;
}

1;

=pod

=encoding utf8

=head1 SYNOPSIS

    use AlertGizmo;
    use AlertGizmo::Apod;

    # set implementation subclass to AlertGizmo::Apod, then run AlertGizmo's main()
    AlertGizmo::Apod->set_class();
    AlertGizmo->main();

=head1 DESCRIPTION

AlertGizmo::Apod reads NASA's daily Astronomy Picture of the Day (APOD) data. It makes an HTML table of recent APOD imagery.

=head1 INSTALLATION

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
