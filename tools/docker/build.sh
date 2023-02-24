#!/bin/bash
set -exo pipefail


# This script builds certbot docker and certbot dns plugins docker using the
# local Certbot files.

# Usage: ./build.sh [TAG] [all|amd64|arm32v6|arm64v8]
#   with the [TAG] value corresponding the base of the tag to give the Docker
#   images and the 2nd value being the architecture to build snaps for.
#   Values for the tag should be something like `v0.34.0` or `nightly`. The
#   given value is only the base of the tag because the things like the CPU
#   architecture are also added to the full tag.

WORK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
REPO_ROOT="$(dirname "$(dirname "${WORK_DIR}")")"
source "$WORK_DIR/lib/common"




TAG_BASE="$1"
if [ -z "$TAG_BASE" ]; then
    echo "We cannot tag Docker images with an empty string!" >&2
    exit 1
fi


if [ -n "$2" ]; then
    PLATFORM_SETTER="--platform $2"
fi

# Register QEMU handlers
# docker run --rm --privileged multiarch/qemu-user-static:register --reset

docker buildx create --name certbot_builder --driver docker-container --driver-opt=network=host --bootstrap --use
docker run --privileged --rm tonistiigi/binfmt --install all

# Step 1: Certbot core Docker
DOCKER_REPO="${DOCKER_HUB_ORG}/certbot"
pushd "${REPO_ROOT}"
docker buildx build ${PLATFORM_SETTER} \
        --target certbot \
        -f "${WORK_DIR}/Dockerfile" \
        -t "${DOCKER_REPO}:${TAG_BASE}" \
        -t "${DOCKER_REPO}:latest" \
        --push \
        .


# Step 2: Certbot DNS plugins Docker images
for plugin in "${CERTBOT_PLUGINS[@]}"; do
    DOCKER_REPO="${DOCKER_HUB_ORG}/${plugin}"
    docker buildx build ${PLATFORM_SETTER} \
        --target plugin \
        --build-context plugin-src="${REPO_ROOT}/certbot-${plugin}" \
        -f "${WORK_DIR}/Dockerfile" \
        -t "${DOCKER_REPO}:${TAG_BASE}" \
        -t "${DOCKER_REPO}:latest" \
        --push \
        .
    
done

popd

docker buildx rm certbot_builder
