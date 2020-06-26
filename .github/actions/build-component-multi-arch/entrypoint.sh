#!/bin/bash -l

case "${GITHUB_EVENT_NAME}" in
    "release" )
        echo "Setup for Release (${GITHUB_EVENT_NAME})"
        export LABEL_SUFFIX=""
        ;;
    * )
        echo "Setup for non-Release (${GITHUB_EVENT_NAME})"
        export LABEL_SUFFIX="-dev"
        ;;
esac
echo "Use label suffix: [${LABEL_SUFFIX}]"

echo Login into Container Registry
echo "${INPUT_ACR_PASSWORD}" | docker login -u ${INPUT_ACR_NAME} --password-stdin ${INPUT_ACR_REPO}

echo Create multi-arch versioned manifest
export LABEL_PREFIX=v$(cat version.txt)${LABEL_SUFFIX}
export PREFIX=${INPUT_ACR_REPO}
make ${INPUT_MAKEFILE_COMPONENT_NAME}-docker-multi-arch-create

echo Inspect multi-arch versioned manifest
DOCKER_CLI_EXPERIMENTAL=enabled docker manifest inspect ${INPUT_ACR_REPO}/${INPUT_CONTAINER_NAME}:v$(cat version.txt)${LABEL_SUFFIX}

echo Push multi-arch versioned manifest
export LABEL_PREFIX=v$(cat version.txt)${LABEL_SUFFIX}
export PREFIX=${INPUT_ACR_REPO}
make ${INPUT_MAKEFILE_COMPONENT_NAME}-docker-multi-arch-push


echo Create multi-arch latest manifest
export LABEL_PREFIX=latest${LABEL_SUFFIX}
export PREFIX=${INPUT_ACR_REPO}
make ${INPUT_MAKEFILE_COMPONENT_NAME}-docker-multi-arch-create

echo Inspect multi-arch latest manifest
DOCKER_CLI_EXPERIMENTAL=enabled docker manifest inspect ${INPUT_ACR_REPO}/${INPUT_CONTAINER_NAME}:latest${LABEL_SUFFIX}

echo Push multi-arch latest manifest
export LABEL_PREFIX=latest${LABEL_SUFFIX}
export PREFIX=${INPUT_ACR_REPO}
make ${INPUT_MAKEFILE_COMPONENT_NAME}-docker-multi-arch-push

