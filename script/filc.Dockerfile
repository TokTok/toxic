FROM alpine:3.23 AS c-toxcore-git
RUN apk add --no-cache git \
 && git clone --depth=1 --recursive https://github.com/TokTok/c-toxcore /src

# Replaced by a local checkout with --build-context c-toxcore=<dir>.
FROM scratch AS c-toxcore
COPY --from=c-toxcore-git /src /

FROM ubuntu:24.04

RUN apt-get update && \
 DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
 binutils \
 ca-certificates \
 cmake \
 curl \
 linux-libc-dev \
 make \
 patchelf \
 perl \
 pkg-config \
 xz-utils \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /work/filc
RUN curl -fsSLo filc.tar.xz https://github.com/pizlonator/fil-c/releases/download/v0.687/filc-0.687-linux-x86_64.tar.xz \
 && echo "aab538401f78a47ab261ee79afed8c6b99e1d4848e263ae159a75b03c1288da1  filc.tar.xz" | sha256sum -c \
 && tar xJf filc.tar.xz --strip-components=1 \
 && rm filc.tar.xz \
 && ./setup.sh
ENV CC=/work/filc/build/bin/clang CXX=/work/filc/build/bin/clang++
ENV PKG_CONFIG_PATH=/work/prefix/lib/pkgconfig

# Everything must be compiled with Fil-C, including our dependencies.
WORKDIR /work/libsodium
RUN curl -fsSLo libsodium.tar.gz https://github.com/jedisct1/libsodium/releases/download/1.0.22-RELEASE/libsodium-1.0.22.tar.gz \
 && echo "adbdd8f16149e81ac6078a03aca6fc03b592b89ef7b5ed83841c086191be3349  libsodium.tar.gz" | sha256sum -c \
 && tar xzf libsodium.tar.gz --strip-components=1 \
 && rm libsodium.tar.gz \
 && ./configure --prefix=/work/prefix --disable-asm --disable-shared \
 && make -j"$(nproc)" install

WORKDIR /work/ncurses
RUN curl -fsSLo ncurses.tar.gz https://invisible-island.net/archives/ncurses/ncurses-6.6.tar.gz \
 && echo "355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11  ncurses.tar.gz" | sha256sum -c \
 && tar xzf ncurses.tar.gz --strip-components=1 \
 && rm ncurses.tar.gz \
 && ./configure --prefix=/work/prefix --enable-widec --enable-pc-files \
 --with-pkg-config-libdir=/work/prefix/lib/pkgconfig --without-shared --without-cxx \
 --without-ada --without-manpages --without-progs --without-tests \
 && make -j"$(nproc)" install

WORKDIR /work/libconfig
RUN curl -fsSLo libconfig.tar.gz https://github.com/hyperrealm/libconfig/archive/refs/tags/v1.8.3.tar.gz \
 && echo "683f723d647befcdb36e1a4a61a83ae8c89dc7959ca872a7407b6c8152104162  libconfig.tar.gz" | sha256sum -c \
 && tar xzf libconfig.tar.gz --strip-components=1 \
 && rm libconfig.tar.gz \
 && cmake -B _build -DCMAKE_INSTALL_PREFIX=/work/prefix -DCMAKE_BUILD_TYPE=Release \
 -DBUILD_SHARED_LIBS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_CXX=OFF \
 && cmake --build _build -j"$(nproc)" --target install

# Ubuntu's ca-certificates are in /usr/lib/ssl.
WORKDIR /work/openssl
RUN curl -fsSLo openssl.tar.gz https://github.com/openssl/openssl/releases/download/openssl-3.5.9/openssl-3.5.9.tar.gz \
 && echo "603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a  openssl.tar.gz" | sha256sum -c \
 && tar xzf openssl.tar.gz --strip-components=1 \
 && rm openssl.tar.gz \
 && ./Configure linux-x86_64 --prefix=/work/prefix --libdir=lib --openssldir=/usr/lib/ssl \
 no-asm no-shared no-tests no-docs \
 && make -j"$(nproc)" \
 && make install_sw

WORKDIR /work/curl
RUN curl -fsSLo curl.tar.xz https://curl.se/download/curl-8.21.0.tar.xz \
 && echo "aa1b66a70eace83dc624508745646c08ae561de512ab403adffb93ac87fc72e6  curl.tar.xz" | sha256sum -c \
 && tar xJf curl.tar.xz --strip-components=1 \
 && rm curl.tar.xz \
 && ./configure --prefix=/work/prefix --disable-shared --with-openssl=/work/prefix --without-libpsl \
 --without-zlib --without-brotli --without-zstd --without-nghttp2 --without-libidn2 \
 --disable-docs --disable-manual \
 && make -j"$(nproc)" install

WORKDIR /work/c-toxcore
COPY --from=c-toxcore . /work/c-toxcore
RUN cmake -B _build -DCMAKE_INSTALL_PREFIX=/work/prefix -DCMAKE_BUILD_TYPE=RelWithDebInfo \
 -DENABLE_SHARED=OFF -DBUILD_TOXAV=OFF -DBOOTSTRAP_DAEMON=OFF -DDHT_BOOTSTRAP=OFF \
 && cmake --build _build -j"$(nproc)" --target install

WORKDIR /work/toxic
COPY Makefile /work/toxic/
COPY cfg /work/toxic/cfg/
COPY misc /work/toxic/misc/
COPY sounds /work/toxic/sounds/
COPY src /work/toxic/src/
# The Makefile doesn't link the dependencies of static libraries.
RUN make -j"$(nproc)" DISABLE_X11=1 DISABLE_AV=1 DISABLE_SOUND_NOTIFY=1 DISABLE_DESKTOP_NOTIFY=1 \
 DISABLE_QRCODE=1 DISABLE_QRPNG=1 \
 USER_LDFLAGS="$(pkg-config --static --libs toxcore ncursesw libconfig libcurl)"
