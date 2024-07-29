#!/bin/bash
set -e

# Script to update ncloud application code from mounted local repository. Local only.

flags=$1

apt-get install -y rsync

rsync \
    -avog --stats \
    --exclude '3rdparty' \
    --exclude tests \
    --exclude node_modules \
    --exclude *.css \
    --exclude *.js \
    --exclude *.map \
    --chown www-data:www-data \
    /ncloud/local-source/* /ncloud/server

rsync \
    -avog --stats \
    --exclude '3rdparty' \
    --exclude tests \
    --exclude node_modules \
    --exclude *.map \
    --chown www-data:www-data \
    /ncloud/local-source/apps/cdsp/* /ncloud/server/apps/cdsp

rsync \
    -avog --stats \
    --exclude '3rdparty' \
    --exclude tests \
    --exclude node_modules \
    --exclude *.map \
    --chown www-data:www-data \
    /ncloud/local-source/themes/cdsp-theme/* /ncloud/server/themes/cdsp-theme

cp /ncloud/conf/config.php /ncloud/server/config/config.php

if [[ $flags == *"rebuild-js"* ]]; then
    pushd /ncloud/server
    npm install && npm run build

    popd
fi
