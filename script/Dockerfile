FROM alpine:3.19.0 AS build

RUN ["apk", "add", "--no-cache", \
 "autoconf", \
 "automake", \
 "brotli-static", \
 "c-ares-static", \
 "cmake", \
 "curl-dev", \
 "curl-static", \
 "diffutils", \
 "g++", \
 "gcc", \
 "git", \
 "libconfig-dev", \
 "libconfig-static", \
 "libidn2-static", \
 "libsodium-dev", \
 "libsodium-static", \
 "libtool", \
 "libunistring-static", \
 "libx11-dev", \
 "libx11-static", \
 "libxcb-static", \
 "linux-headers", \
 "make", \
 "ncurses-dev", \
 "ncurses-static", \
 "nghttp2-static", \
 "openssl-libs-static", \
 "pkgconfig", \
 "python3-dev", \
 "yasm", \
 "zlib-static"]

WORKDIR /work/portaudio
RUN ["git", "clone", "--branch=v19.7.0", "--depth=1", "https://github.com/PortAudio/portaudio", "/work/portaudio"]
RUN ["cmake", "-B_build", "-H.", "-DBUILD_SHARED_LIBS=OFF"]
RUN cmake --build _build --target install -- "-j$(nproc)"

WORKDIR /work/openal-soft
RUN ["git", "clone", "--branch=1.23.1", "--depth=1", "https://github.com/kcat/openal-soft", "/work/openal-soft"]
RUN ["cmake", "-B_build", "-H.", "-DLIBTYPE=STATIC", "-DALSOFT_EXAMPLES=OFF", "-DALSOFT_UTILS=OFF", "-DALSOFT_DLOPEN=OFF"]
RUN cmake --build _build --target install -- "-j$(nproc)"

WORKDIR /work/libvpx
RUN ["git", "clone", "--branch=v1.13.1", "--depth=1", "https://github.com/webmproject/libvpx", "/work/libvpx"]
RUN ["./configure", "--disable-shared", "--enable-static", "--disable-examples", "--disable-tools", "--disable-unit-tests"]
RUN make "-j$(nproc)" install

WORKDIR /work/opus
RUN ["git", "clone", "--branch=v1.4", "--depth=1", "https://github.com/xiph/opus", "/work/opus"]
RUN ["autoreconf", "-fi"]
RUN ["./configure", "--disable-shared", "--enable-static"]
RUN make "-j$(nproc)" install

WORKDIR /app
# TODO(iphydf): Change to a release tag once NGC is released.
RUN ["git", "clone", "--depth=200", "--recurse-submodules", "--shallow-submodules", "https://github.com/TokTok/c-toxcore", "/work/c-toxcore"]
RUN cd /work/c-toxcore && git checkout 0e42752f0fc2a460b08ac4d275ae5b5f18c8d3ea
RUN mkdir -p /work/include/tox \
 && ln -s /work/c-toxcore/toxav/toxav.h /work/include/tox/ \
 && ln -s /work/c-toxcore/toxcore/tox.h /work/include/tox/ \
 && ln -s /work/c-toxcore/toxcore/tox_private.h /work/include/tox/ \
 && ln -s /work/c-toxcore/toxencryptsave/toxencryptsave.h /work/include/tox/
COPY src/ /work/toxic/src/
RUN gcc \
 -o /app/toxic \
 -static \
 -DPACKAGE_DATADIR='"/app"' \
 -DGAMES \
 -DAUDIO \
 -DVIDEO \
 -DTOX_EXPERIMENTAL \
 -UPYTHON \
 /work/toxic/src/*.c \
 /work/c-toxcore/toxav/*.c \
 /work/c-toxcore/toxcore/*.c \
 /work/c-toxcore/toxcore/*/*.c \
 /work/c-toxcore/toxencryptsave/*.c \
 /work/c-toxcore/third_party/cmp/cmp.c \
 -I/work/include \
 $(pkg-config --cflags --libs libconfig libcurl libsodium ncurses openal opus vpx) \
 $(python3-config --embed --abiflags --includes --ldflags) \
 "-L$(dirname $(find /usr -name "libpython3.11.a"))" \
 -lX11 -lxcb -lXdmcp -lXau -lssl -lcrypto -lnghttp2 -lidn2 -lz -lunistring -lbrotlidec -lbrotlicommon -lcares -lstdc++ -lportaudio
RUN strip /app/toxic
COPY misc/nameservers /app/
COPY sounds/ /app/sounds/
COPY apidoc/python/source/*.py /app/scripts/

RUN echo 'root:x:0:0:root:/root:/app/toxic' > /work/passwd \
 && echo 'toxic:x:1000:1000:Toxic User:/home/toxic:/app/toxic' > /work/passwd \
 && echo 'root:x:0' > /work/group \
 && echo 'toxic:x:1000' > /work/group
RUN mkdir -p /home/toxic/.config

FROM scratch
# Basic OS-level stuff: passwd/group so we don't need to run as root, ssl for
# curl to work, and terminfo for ncurses to work.
COPY --from=build /work/passwd /work/group /etc/
COPY --from=build /etc/ssl/ /etc/ssl/
COPY --from=build /etc/terminfo/ /etc/terminfo/
COPY --from=build /usr/lib/python3.11/ /usr/lib/python3.11/

# App bundle. Everything needed to run toxic is here.
COPY --from=build /app /app

COPY --from=build --chown=toxic:toxic /home/toxic/ /home/toxic/
WORKDIR /app
USER toxic
ENV USER=toxic
CMD ["/app/toxic"]
