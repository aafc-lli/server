#!/bin/bash
set -e

# Pre-install init script. Executed within ncloud container.

apt-get update
apt-get install postgresql-client -y

cat << EOF |
CREATE ROLE ncloud;
ALTER ROLE ncloud WITH LOGIN;
ALTER ROLE ncloud WITH PASSWORD 'ncloud';

CREATE DATABASE ncloud OWNER ncloud;
EOF
psql postgresql://pgadmin:localadmin@lli-local-postgres/postgres
