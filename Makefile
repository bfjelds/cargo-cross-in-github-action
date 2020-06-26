BUILD_AMD64 ?= 1
BUILD_ARM32 ?= 0 #skip building arm32 for now
BUILD_ARM64 ?= 1

REGISTRY ?= myacr.azurecr.io
UNIQUE_ID ?= $(USER)

CROSS_PREFIX ?= $(REGISTRY)/$(UNIQUE_ID)
CROSS_DOCKERFILE_DIR ?= build/containers/intermediate

PREFIX ?= $(REGISTRY)/$(UNIQUE_ID)
DOCKERFILE_DIR ?= build/containers
VERSION_LABEL=$(shell cat version.txt)
LABEL_PREFIX ?= $(VERSION_LABEL)

CACHE_OPTION ?=

ENABLE_DOCKER_MANIFEST = DOCKER_CLI_EXPERIMENTAL=enabled

AMD64_SUFFIX = amd64
ARM32V7_SUFFIX = arm32v7
ARM64V8_SUFFIX = arm64v8

AMD64_TARGET = x86_64-unknown-linux-gnu
ARM32V7_TARGET = arm-unknown-linux-gnueabihf
ARM64V8_TARGET = aarch64-unknown-linux-gnu
CROSS_VERSION = 0.1.16


#
#
# INSTALL-CROSS: install cargo cross building tool:
#
#    `make install-cross`
#
#
.PHONY: install-cross
install-cross:
	cargo install cross

#
#
# CROSS: make and push the intermediate images for the cross building Rust:
#
#    To make all platforms: `make cross`
#    To make specific platforms: `BUILD_AMD64=1 BUILD_ARM32=0 BUILD_ARM64=1 make cross`
#
#
.PHONY: cross
cross: create-cross-build-containers push-cross-build-containers
create-cross-build-containers: create-cross-build-containers-amd64 create-cross-build-containers-arm32 create-cross-build-containers-arm64
create-cross-build-containers-amd64:
ifeq (1, $(BUILD_AMD64))
	 docker build $(CACHE_OPTION) -f $(CROSS_DOCKERFILE_DIR)/Dockerfile.rust-crossbuild-$(AMD64_SUFFIX) . -t $(CROSS_PREFIX)/rust-crossbuild:$(AMD64_TARGET)-$(CROSS_VERSION)
endif
create-cross-build-containers-arm32:
ifeq (1, ${BUILD_ARM32})
	 docker build $(CACHE_OPTION) -f $(CROSS_DOCKERFILE_DIR)/Dockerfile.rust-crossbuild-$(ARM32V7_SUFFIX) . -t $(CROSS_PREFIX)/rust-crossbuild:$(ARM32V7_TARGET)-$(CROSS_VERSION)
endif
create-cross-build-containers-arm64:
ifeq (1, ${BUILD_ARM64})
	 docker build $(CACHE_OPTION) -f $(CROSS_DOCKERFILE_DIR)/Dockerfile.rust-crossbuild-$(ARM64V8_SUFFIX) . -t $(CROSS_PREFIX)/rust-crossbuild:$(ARM64V8_TARGET)-$(CROSS_VERSION)
endif

push-cross-build-containers: push-cross-build-containers-amd64 push-cross-build-containers-arm32 push-cross-build-containers-arm64
push-cross-build-containers-amd64:
ifeq (1, $(BUILD_AMD64))
	 docker push $(CROSS_PREFIX)/rust-crossbuild:$(AMD64_TARGET)-$(CROSS_VERSION)
endif
push-cross-build-containers-arm32:
ifeq (1, ${BUILD_ARM32})
	 docker push $(CROSS_PREFIX)/rust-crossbuild:$(ARM32V7_TARGET)-$(CROSS_VERSION)
endif
push-cross-build-containers-arm64:
ifeq (1, ${BUILD_ARM64})
	 docker push $(CROSS_PREFIX)/rust-crossbuild:$(ARM64V8_TARGET)-$(CROSS_VERSION)
endif

#
#
# foo: make and push the images for foo:
#
#    To make all platforms: `make foo`
#    To make specific platforms: `BUILD_AMD64=1 BUILD_ARM32=0 BUILD_ARM64=1 make foo`
#
#
.PHONY: foo
foo: foo-build foo-docker

foo-build: install-cross foo-cross-build
foo-docker: foo-docker-build foo-docker-push-per-arch foo-docker-push-multi-arch-create foo-docker-push-multi-arch-push

foo-cross-build: foo-cross-build-amd64 foo-cross-build-arm32 foo-cross-build-arm64
foo-cross-build-amd64:
ifeq (1, $(BUILD_AMD64))
	PKG_CONFIG_ALLOW_CROSS=1 cross build --target=$(AMD64_TARGET)
endif
foo-cross-build-arm32:
ifeq (1, ${BUILD_ARM32})
	PKG_CONFIG_ALLOW_CROSS=1 cross build --target=$(ARM32V7_TARGET)
endif
foo-cross-build-arm64:
ifeq (1, ${BUILD_ARM64})
	PKG_CONFIG_ALLOW_CROSS=1 cross build --target=$(ARM64V8_TARGET)
endif

foo-docker-build: foo-docker-build-amd64 foo-docker-build-arm32 foo-docker-build-arm64
foo-docker-build-amd64:
ifeq (1, ${BUILD_AMD64})
	docker build $(CACHE_OPTION) -f $(DOCKERFILE_DIR)/Dockerfile.foo . -t $(PREFIX)/foo-rust:$(LABEL_PREFIX)-$(AMD64_SUFFIX) --build-arg PLATFORM=$(AMD64_SUFFIX) --build-arg CROSS_BUILD_TARGET=$(AMD64_TARGET)
endif
foo-docker-build-arm32:
ifeq (1, ${BUILD_ARM32})
	docker build $(CACHE_OPTION) -f $(DOCKERFILE_DIR)/Dockerfile.foo . -t $(PREFIX)/foo-rust:$(LABEL_PREFIX)-$(ARM32V7_SUFFIX) --build-arg PLATFORM=$(ARM32V7_SUFFIX) --build-arg CROSS_BUILD_TARGET=$(ARM32V7_TARGET)
endif
foo-docker-build-arm64:
ifeq (1, ${BUILD_ARM64})
	docker build $(CACHE_OPTION) -f $(DOCKERFILE_DIR)/Dockerfile.foo . -t $(PREFIX)/foo-rust:$(LABEL_PREFIX)-$(ARM64V8_SUFFIX) --build-arg PLATFORM=$(ARM64V8_SUFFIX) --build-arg CROSS_BUILD_TARGET=$(ARM64V8_TARGET)
endif


foo-docker-push-per-arch: foo-docker-push-per-arch-amd64 foo-docker-push-per-arch-arm32 foo-docker-push-per-archarm64
foo-docker-push-per-arch-amd64:
ifeq (1, ${BUILD_AMD64})
	docker push $(PREFIX)/foo:$(LABEL_PREFIX)-$(AMD64_SUFFIX)
endif
foo-docker-per-arch-arm32:
ifeq (1, ${BUILD_ARM32})
	docker push $(PREFIX)/foo:$(LABEL_PREFIX)-$(ARM32V7_SUFFIX)
endif
foo-docker-per-arch-arm64:
ifeq (1, ${BUILD_ARM64})
	docker push $(PREFIX)/foo:$(LABEL_PREFIX)-$(ARM64V8_SUFFIX)
endif


foo-docker-push-multi-arch-create:
ifeq (1, ${BUILD_AMD64})
	$(ENABLE_DOCKER_MANIFEST) docker manifest create --amend $(PREFIX)/foo:$(LABEL_PREFIX) $(PREFIX)/foo:$(LABEL_PREFIX)-$(AMD64_SUFFIX)
endif
ifeq (1, ${BUILD_ARM32})
	$(ENABLE_DOCKER_MANIFEST) docker manifest create --amend $(PREFIX)/foo:$(LABEL_PREFIX) $(PREFIX)/foo:$(LABEL_PREFIX)-$(ARM32V7_SUFFIX)
endif
ifeq (1, ${BUILD_ARM64})
	$(ENABLE_DOCKER_MANIFEST) docker manifest create --amend $(PREFIX)/foo:$(LABEL_PREFIX) $(PREFIX)/foo:$(LABEL_PREFIX)-$(ARM64V8_SUFFIX)
endif


foo-docker-push-multi-arch-push:
	$(ENABLE_DOCKER_MANIFEST) docker manifest push $(PREFIX)/foo:$(LABEL_PREFIX)
