#!/bin/bash
set -e

# Script to build ncloud container. The container must be built this way.

image_tag=$1
flags=$2

if [[ $flags != *"skip-ctx"* ]]; then
    echo "Populating build context..."

    if [[ -d context ]]; then
        rm -rf context
    fi
    mkdir context

    # Copy ncloud. Archive used for build performance.
    our_path=$(pwd)

    pushd ../
    set +e
    tar \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='.lli' \
        --warning=no-file-changed \
        -cf \
        "$our_path/context/server.tar" .
    set -e
    popd
    cp ../composer.json context/composer.json
    cp ../composer.lock context/composer.lock
else
    echo "Reusing existing build context, recent changes may not be applied."
fi

echo "Building image..."
ext_build_args=()
if [[ $flags == *"debug"* ]]; then
    ext_build_args+=(--progress plain)
fi
if [[ $flags == *"no-cache"* ]]; then
    ext_build_args+=(--no-cache)
fi
if [[ $flags == *"svc-with-node"* ]]; then
    ext_build_args+=(--build-arg SERVICE_BASE_IMAGE=node_base)
fi

docker build \
    --target service \
    -t $image_tag \
    "${ext_build_args[@]}" \
    .

echo "Done build."
