#!/bin/sh -eu

LOCAL_PROJECT_PATH=${1:-$(pwd)}
BUILD_COMMAND="
shards build --static --release
chown 1000:1000 -R bin
"
INSTALL_CRYSTAL="
echo '@edge http://dl-cdn.alpinelinux.org/alpine/edge/community' >>/etc/apk/repositories
apk add --update --no-cache --force-overwrite \
  crystal@edge \
  g++ \
  gc-dev \
  libevent-dev \
  libxml2-dev \
  llvm5-dev \
  llvm5-libs \
  llvm5-static \
  make \
  musl-dev \
  openssl-dev \
  pcre-dev \
  readline-dev \
  shards@edge \
  yaml-dev
"

# Compile Crystal project statically for arm64 (aarch64)
docker pull multiarch/qemu-user-static:register
docker run --rm --privileged multiarch/qemu-user-static:register --reset
docker run -it -v $LOCAL_PROJECT_PATH:/app -w /app --rm multiarch/alpine:aarch64-edge /bin/sh -c "$INSTALL_CRYSTAL; $BUILD_COMMAND"
