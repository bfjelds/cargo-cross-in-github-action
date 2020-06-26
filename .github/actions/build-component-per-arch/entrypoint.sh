#!/bin/sh

echo Start entrypoint.sh

echo "Output arguments"
sh -c "echo $*"

echo "Output environment variables:"
printenv

echo "Use multiarch/qemu-user-static to configure cross-plat"
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

case "${GITHUB_EVENT_NAME}" in
    "release" )
        echo "Setup for Release (${GITHUB_EVENT_NAME})"
        export VERSIONED_LABEL="v$(cat version.txt)"
        export LATEST_LABEL="latest"
        ;;
    * )
        echo "Setup for non-Release (${GITHUB_EVENT_NAME})"
        export VERSIONED_LABEL="v$(cat version.txt)-dev"
        export LATEST_LABEL="latest-dev"
        ;;
esac
echo "Use labels: versioned=${VERSIONED_LABEL} latest=${LATEST_LABEL}"

export PUSH_CONTAINERS=0
case ${INPUT_GITHUB_EVENT_NAME} in
    'release') export PUSH_CONTAINERS=1;;
    'push')
        if [ "$INPUT_GITHUB_REF" == "refs/heads/master" ]; then
            export PUSH_CONTAINERS=1
        fi
        ;;
    'pull_request')
        case ${INPUT_GITHUB_EVENT_ACTION} in
            'closed')
                case ${INPUT_GITHUB_REF} in
                    'refs/heads/master')
                        case ${INPUT_GITHUB_MERGED} in
                            'true') export PUSH_CONTAINERS=1;;
                            * )
                                echo "Not a merge operation: ${INPUT_GITHUB_MERGED} ... not Pushing containers"
                                ;;
                        esac
                        ;;
                    * )
                        echo "Github.ref is not 'refs/heads/master': ${INPUT_GITHUB_REF} ... not Pushing containers"
                        ;;
                esac
                ;;
            * )
                echo "Action is not 'closed': ${INPUT_GITHUB_EVENT_ACTION} ... not Pushing containers"
                ;;
        esac
        ;;
esac
echo "Push containers: ${PUSH_CONTAINERS}"

case "${INPUT_PLATFORM}" in
    "amd64" )   export MAKEFILE_TARGET_SUFFIX="amd64";;
    "arm32v7" ) export MAKEFILE_TARGET_SUFFIX="arm32";;
    "arm64v8" ) export MAKEFILE_TARGET_SUFFIX="arm64";;
    * )
        echo "Unknown platform: ${INPUT_PLATFORM}"
        exit 1
        ;;
esac
echo "Makefile build target suffix: ${MAKEFILE_TARGET_SUFFIX}"

echo "Login into Container Registry repo=${INPUT_ACR_REPO} user=${INPUT_ACR_NAME}"
echo "${INPUT_ACR_PASSWORD}" | docker login -u ${INPUT_ACR_NAME} --password-stdin ${INPUT_ACR_REPO}

case "${INPUT_BUILD_RUST}" in
    "1" )
        echo "Install Rust"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -x -s -- -y
        echo "Add cargo ($HOME/.cargo/bin) to $PATH"
        PATH=$PATH:$HOME/.cargo/bin
        echo "Check cargo version"
        cargo --version
        echo "Install Cross"
        make install-cross || exit 1
        cross --version
        echo "Cross compile: foo-cross-build-${MAKEFILE_TARGET_SUFFIX}"
        make foo-cross-build-${MAKEFILE_TARGET_SUFFIX} || exit 1
        ;;
    * )
        echo "Not building Rust: ${INPUT_BUILD_RUST}"
        ;;
esac

echo "Build the versioned container: make ${INPUT_MAKEFILE_COMPONENT_NAME}-build-${MAKEFILE_TARGET_SUFFIX}"
export LABEL_PREFIX=${VERSIONED_LABEL}
export PREFIX=${INPUT_ACR_REPO}
make ${INPUT_MAKEFILE_COMPONENT_NAME}-build-${MAKEFILE_TARGET_SUFFIX} || exit 1

echo "Build the latest container: make ${INPUT_MAKEFILE_COMPONENT_NAME}-build-${MAKEFILE_TARGET_SUFFIX}"
export LABEL_PREFIX=${LATEST_LABEL}
export PREFIX=${INPUT_ACR_REPO}
make ${INPUT_MAKEFILE_COMPONENT_NAME}-build-${MAKEFILE_TARGET_SUFFIX} || exit 1

case "${PUSH_CONTAINERS}" in
    "1" )
        echo "Push the versioned container: make ${INPUT_MAKEFILE_COMPONENT_NAME}-docker-per-arch-${MAKEFILE_TARGET_SUFFIX}"
        export LABEL_PREFIX=${VERSIONED_LABEL}
        export PREFIX=${INPUT_ACR_REPO}
        make ${INPUT_MAKEFILE_COMPONENT_NAME}-docker-per-arch-${MAKEFILE_TARGET_SUFFIX} || exit 1

        echo "Push the latest container: make ${INPUT_MAKEFILE_COMPONENT_NAME}-docker-per-arch-${MAKEFILE_TARGET_SUFFIX}"
        export LABEL_PREFIX=${LATEST_LABEL}
        export PREFIX=${INPUT_ACR_REPO}
        make ${INPUT_MAKEFILE_COMPONENT_NAME}-docker-per-arch-${MAKEFILE_TARGET_SUFFIX}  || exit 1
        ;;
    * )
        echo "Not pushing containers: ${PUSH_CONTAINERS}"
        ;;
esac
