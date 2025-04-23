# AlertGizmo static web site builder container
# by Ian Kluft

# use Alpine Linux
FROM alpine:3.21

# note: do not set WORKDIR because Github Actions mounts the workspace (copy of repo content) as the working directory.
# To test the container, use docker or podman with --workdir and provide a similar copy of the repo to work with.

# initial OS packages
RUN apk update && apk add wget openssl openssl-dev tar git make perl perl-app-cpanminus perl-module-build perl-module-build-tiny perl-yaml perl-yaml-libyaml perl-http-date perl-datetime perl-term-readkey perl-html-parser perl-ppi perl-moose perl-moo perl-template-toolkit perl-config-ini perl-params-validate perl-yaml-tiny perl-text-template perl-ipc-run3 perl-net-ssleay perl-io-socket-ssl perl-lwp-protocol-https perl-number-compare perl-module-pluggable perl-path-tiny perl-type-tiny perl-moosex-types perl-text-glob 

# install Dist::Zilla & App::Aphra, which are key to the site build but not provided by APK packages
RUN cpanm --notest --quiet Dist::Zilla App::Aphra

# build AlertGizmo using Dist::Zilla's dzil
RUN cd $GITHUB_WORKSPACE/src/perl && dzil authordeps --missing | cpanm --notest --quiet && dzil listdeps --missing | cpanm --notest --quiet && dzil build && dzil install

# run entrypoint script
ENTRYPOINT /bin/sh $GITHUB_WORKSPACE/web-build/container/entrypoint.sh
