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

# TODO - continue converting APOD script to AlertGizmo submodule
