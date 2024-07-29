#!/bin/bash
set -e

# Script to update ncloud application code from mounted local repository. Local only.

app_name=$1

cd server
if [[ $app_name != "" ]]; then
    cd apps/$app_name
fi

npm install
npm run build
rm -rf node_modules
