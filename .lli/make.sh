#!/bin/bash
set -e

# Make.

flags=$1

export MSYS_NO_PATHCONV=1

if [[ $flags != *"skip-build"* ]]; then
    echo "Building image..."
    ext_build_args=()
    if [[ $flags == *"debug"* ]]; then
        ext_build_args+=(--progress simple --no-cache)
    fi
    if [[ $flags == *"no-cache"* ]]; then
        ext_build_args+=(--no-cache)
    fi

    docker build \
        --target build \
        -t ncloud_make \
        "${ext_build_args[@]}" \
        .      
fi

echo "Running make..."

echo "cd /tmp && ls -lah && npm install && npm run build" | \
docker run \
    --volume "$(pwd)/../../../../server:/tmp" \
    -i ncloud_make \
    bash
