AlertGizmo
----------

by Ian Kluft

AlertGizmo is a set of Perl modules which monitor for space-related events and generate summary pages. The Perl implementation may later be used as a prototype for other language implementations.

It originated as scripts I wrote to monitor space-related alerts online. The common code among the scripts was pulled together into the AlertGizmo module. These can be run manually, or automatically from crontabs. (see example below)

## Subclasses

The subclasses of AlertGizmo which handle the details of specific topics of space alert data are as follows:

* AlertGizmo::Apod: monitor for NASA Astronomy Picture of the Day (APOD) feed (work in progress)
* AlertGizmo::Neo: monitor for NASA JPL Near-Earth Object (NEO) close approach data
* AlertGizmo::Swpc: monitor for NOAA Space Weather Prediction Center (SWPC) alerts, including aurora

## Directory structure

- bin (script directory)
  - *[pull-nasa-neo.pl](bin/pull-nasa-neo.pl)* reads NASA JPL data on Near Earth Object (NEO) asteroid close approaches to Earth, within 2 lunar distances (LD) and makes a table of upcoming events and recent ones within 15 days.
     - language: Perl5🧅
     - dependencies: AlertGizmo::Neo, [Template Toolkit](http://www.template-toolkit.org/)
     - example template text: [close-approaches.tt](close-approaches.tt)
  - *[pull-swpc-alerts.pl](bin/pull-swpc-alerts.pl)* reads NOAA Space Weather Prediction Center (SWPC) alerts for solar flares and aurora
     - language: Perl5🧅
     - dependencies: AlertGizmo::Swpc, [Template Toolkit](http://www.template-toolkit.org/)
     - example template text: [noaa-swpc-alerts.tt](noaa-swpc-alerts.tt)
  - *[pull-nasa-apod.pl](bin/pull-nasa-apod.pl)* reads NASA Astronomy Picture of the Day (APOD) feed (work in progress)
     - language: Perl5🧅
     - dependencies: AlertGizmo::Apod, [Template Toolkit](http://www.template-toolkit.org/)
     - example template text: [nasa-apod-alerts.tt](nasa-apod-alerts.tt)
- lib (library directory)
  - AlertGizmo.pm - base class for AlertGizmo feed monitors
  - AlertGizmo/Config.pm - configuration data for AlertGizmo classes
  - AlertGizmo/Apod.pm - AlertGizmo monitor for NASA Astronomy Picture of the Day (APOD) feed (work in progress)
  - AlertGizmo/Neo.pm - AlertGizmo monitor for NASA JPL Near-Earth Object (NEO) close approach data
  - AlertGizmo/Swpc.pm - AlertGizmo monitor for NOAA Space Weather Prediction Center (SWPC) alerts, including aurora
  - AlertGizmo/Postproc.pm - common code for for AlertGizmo postprocessing classes
  - AlertGizmo/Postproc/Image.pm - postprocessing plugin to generate images from AlertGizmo data

## Installation

### Installation from CPAN

This section will be filled in after AlertGizmo is uploaded to CPAN.

### Installation from source code

The source code repository is at [https://github.com/ikluft/AlertGizmo](https://github.com/ikluft/AlertGizmo).

For a development environment, make sure Perl is installed. The minimum Perl version is 5.36 due to use of language features from 2024. Check first if binary packages are available for your OS & platform. More information can be found at [https://metacpan.org/dist/perl/view/INSTALL](https://metacpan.org/dist/perl/view/INSTALL).

Then install App::cpanminus (cpanm), Dist::Zilla (dzil) and Perl::Critic (perlcritic).

On Debian-based Linux systems they can be installed with this command as root:

    apt update
    apt install cpanminus libdist-zilla-perl libperl-critic-perl

On RPM-based Linux systems (Fedora, Red Hat and CentOS derivatives) as root:

    dnf install --refresh perl-App-cpanminus perl-Dist-Zilla perl-Perl-Critic

On Alpine Linux systems and containers:

    apk update && apk upgrade
    apk add make git perl perl-utils perl-alien-build perl-class-tiny perl-config-tiny perl-date-manip perl-datetime perl-datetime-locale perl-datetime-timezone perl-dbd-csv perl-dbd-sqlite perl-dbi perl-http-date perl-ipc-run perl-list-moreutils perl-list-someutils perl-log-dispatch perl-log-log4perl perl-module-build perl-moose perl-moosex-types perl-namespace-autoclean perl-net-ssleay perl-params-validate perl-perlio-utf8_strict perl-pod-parser perl-readonly perl-term-readkey perl-test-leaktrace perl-test-pod perl-test-warn perl-text-template perl-type-tiny perl-xml-dom perl-yaml
    cpan -T App::cpanminus Dist::Zilla Perl::Critic </dev/null

On operating systems which don't provide binary packages of App::cpanminus, Dist::Zilla or Perl::Critic, install them from CPAN with this command:

    cpan -T App::cpanminus Dist::Zilla Perl::Critic </dev/null

### Set up AlertGizmo

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

## Running from a crontab

To run AlertGizmo from a crontab, first use 'crontab -l' to determine if you have one set up, and that the crontab command is installed. (If it isn't installed, Linux packages such as [cronie](https://github.com/cronie-crond/cronie) can perform [modern cron](https://en.wikipedia.org/wiki/Cron#Modern_versions) functions. If on a small embedded Linux system, [BusyBox](https://en.wikipedia.org/wiki/BusyBox) or [Toybox](https://en.wikipedia.org/wiki/Toybox) also provide a crontab command.)

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

## Ongoing experimentation

The SWPC alert script is derived from the NEO script. So they had common code. Before making more similar scripts, it was considered a good idea to make modules to combine their common features. That became AlertGizmo. Now the door is open to add more modules on that foundation.

An outage in Tom Taylor's Mastodon "Low Flying Rocks" bot led me to the conclusion I should expand these to be able to post on Mastodon. I was already inspired by [XKCD comic #2979 "Sky Alarm"](https://xkcd.com/2979/) to go in that direction.
[![XKCD comic #2979 "Sky Alarm"](https://imgs.xkcd.com/comics/sky_alarm.png)](https://xkcd.com/2979/)

### Image generation

An intended upcoming feature is the ability to turn output from any AlertGizmo module into an image for display on social media or other postings. Even before it's added to AlertGizmo, it can be done with a tool such as wkhtmltoimage (part of wkhtmltopdf) and NetPBM tools can convert the HTML output to a PNG image file.

    wkhtmltoimage --enable-local-file-access close-approaches.html - | djpeg | pnmcrop -white -closeness=5 | pamtopng > close-approaches.png
    wkhtmltoimage --enable-local-file-access noaa-swpc-alerts.html - | djpeg | pnmcrop -white -closeness=5 | pamtopng > noaa-swpc-alerts.png

### Postprocessing scripts

Current experimentation includes development of a postprocessing script to control image generation and posting to social media. The script will be specified by a --postproc=path parameter. But what needs to go in the script is to be determined.

## Current development plans

Current plans include making a NASA APOD reader (in progress as Apod.pm), a table image generator as an alternative to HTML output, and a Mastodon client to post the images and summary text as periodic updates.
