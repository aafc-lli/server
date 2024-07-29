#!/bin/bash
set -e

# Init script to trigger install. Executed on host.

export MSYS_NO_PATHCONV=1

curl \
    -X POST \
    -H "Content-type: multipart/form-data" \
    -F install=true \
    -F adminlogin=admin \
    -F adminpass=admin \
    -F directory=/ncloud/data \
    -F dbtype=pgsql \
    -F dbuser=ncloud \
    -F dbpass=ncloud \
    -F dbpass-clone=ncloud \
    -F dbname=ncloud \
    -F dbhost=lli-local-postgres \
    http://localhost
