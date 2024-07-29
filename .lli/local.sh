#!/bin/bash
set -e

# Script to manage local ncloud deployment.

verb=$1
flags=$2

if [[ $verb == "up" ]]; then
    echo "Deploying local ncloud..."

    if [[ $flags != *"skip-build"* ]]; then
        ./build.sh ncloud:latest $flags,svc-with-node
    fi

    docker compose \
        -f docker-compose.local.yaml \
        up \
        --detach

    if [[ $flags == *"then-init"* ]]; then
        ./local.sh init $flags
    fi

    echo "Done deployment."
elif [[ $verb == "down" ]]; then
    echo "Destroying local ncloud..."

    ext_teardown_args=()
    if [[ $flags != *"save-vols"* ]]; then
        ext_teardown_args+=(--volumes)
    fi

    docker compose \
        -f docker-compose.local.yaml \
        down \
        "${ext_teardown_args[@]}"

    echo "Done destroy."
elif [[ $verb == "init" ]]; then
    echo "Initializing local ncloud..."

    if [[ $flags != *"skip-pre"* ]]; then
        cat init/pre-install.sh | docker exec -i lli-local-ncloud bash
    fi
    if [[ $flags != *"skip-inst"* ]]; then
        ./init/local-install.sh
    fi
    if [[ $flags != *"skip-post"* ]]; then
        # Post-install script exists in container.
        echo ./post-install.sh | \
            docker exec --user www-data -i lli-local-ncloud bash
    fi

    echo "Done initialization."
elif [[ $verb == "update" ]]; then
    echo "Update ncloud container source code from local repo..."

    echo "./local-update.sh $flags" | \
        docker exec -i lli-local-ncloud bash
elif [[ $verb == "attach" ]]; then
    echo "Attaching to ncloud container..."

    docker logs lli-local-ncloud --follow
elif [[ $verb == "exec" ]]; then
    echo "Execing to ncloud container..."

    docker exec -it lli-local-ncloud bash
else
    echo "Invalid arguments."
    echo "Usage: ./local.sh up|down|update|init|attach|exec"
    exit 1
fi
