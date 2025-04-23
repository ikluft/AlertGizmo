#!/bin/sh
# AlertGizmo site-builder container entry point script
# by Ian Kluft

# error message function
err_fail()
{
    echo "$*" >&2
    echo web build failed at "$(date)" >&2
    exit 1
}

# test begin time
echo start web build at "$(date)"

# generate static web site using App::Aphra
( mkdir -p web && cd web-build && aphra build --target ../web ) \
    || err_fail site generation failed

# process online data from NASA & NOAA into status data files
( mkdir -p web/data \
    && cd web/data ) \
    || err_fail make web/data directory failed
( cd web/data && \
    ln -sf ../../src/perl/bin/*.pl . \
    && ln -sf ../../src/perl/templates/*.tt . ) \
    || err_fail symlink bin+template files failed
( web/data/pull-nasa-neo.pl --dir="$PWD/web/data" --tz="US/Pacific" \
    && web/data/pull-swpc-alerts.pl --dir="$PWD/web/data" --tz="US/Pacific" ) \
    || err_fail data feed failed

# test end time
echo end web build at "$(date)"
