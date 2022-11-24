# syntax=docker/dockerfile:1

# bump: brotli /BROTLI_VERSION=([\d.]+)/ https://github.com/google/brotli.git|*
# bump: brotli after ./hashupdate Dockerfile BROTLI $LATEST
# bump: brotli link "Release notes" https://github.com/google/brotli/releases/tag/$LATEST
ARG BROTLI_VERSION=1.0.9
ARG BROTLI_URL="https://github.com/google/brotli/archive/v$BROTLI_VERSION.tar.gz"
ARG BROTLI_SHA256=f9e8d81d0405ba66d181529af42a3354f838c939095ff99930da6aa9cdf6fe46

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG BROTLI_URL
ARG BROTLI_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O brotli.tar.gz "$BROTLI_URL" && \
  echo "$BROTLI_SHA256  brotli.tar.gz" | sha256sum --status -c - && \
  mkdir brotli && \
  tar xf brotli.tar.gz -C brotli --strip-components=1 && \
  rm brotli.tar.gz && \
  apk del download

FROM base AS build
COPY --from=download /tmp/brotli/ /tmp/brotli/
WORKDIR /tmp/brotli/build
RUN \
  apk add --no-cache --virtual build \
    build-base bash cmake pkgconf && \
  cmake -DCMAKE_BUILD_TYPE=Release .. && \
  cmake --build . --config Release --target install && \
  # Sanity tests
  pkg-config --exists --modversion --path libbrotlicommon && \
  pkg-config --exists --modversion --path libbrotlienc && \
  pkg-config --exists --modversion --path libbrotlidec && \
  ar -t /usr/local/lib/libbrotlicommon-static.a && \
  ar -t /usr/local/lib/libbrotlienc-static.a && \
  ar -t /usr/local/lib/libbrotlidec-static.a && \
  readelf -h /usr/local/lib/libbrotlicommon-static.a && \
  readelf -h /usr/local/lib/libbrotlienc-static.a && \
  readelf -h /usr/local/lib/libbrotlidec-static.a && \
  # Cleanup
  apk del build

FROM scratch
ARG BROTLI_VERSION
COPY --from=build /usr/local/lib/pkgconfig/libbrotli*.pc /usr/local/lib/pkgconfig/
COPY --from=build /usr/local/lib/libbrotli* /usr/local/lib/
COPY --from=build /usr/local/include/brotli/ /usr/local/include/brotli/
