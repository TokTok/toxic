#!/usr/bin/env sh

# MIT License
#
# Copyright (c) 2021-2022 Maxim Biro <nurupo.contributions@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Script for building a minimal statically compiled Toxic. While it doesn't
# support X11 integration, video/audio calls, desktop & sound notifications, QR
# codes and Python scripting, it is rather portable.
#
# Run as:
#
#    sudo docker run -it --rm --pull=always \
#         -v /tmp/artifact:/artifact \
#         -v /home/jfreegman/git/toxic:/toxic \
#         amd64/alpine:latest \
#         /bin/sh /toxic/script/build-minimal-static-toxic.sh
#
# that would use Toxic code from /home/jfreegman/git/toxic and place the build
# artifact at /tmp/artifact.
#
# You can change between:
#   amd64/alpine:latest,
#   i386/alpine:latest,
#   arm64v8/alpine:latest,
#   arm32v7/alpine:latest,
#   arm32v6/alpine:latest,
#   ppc64le/alpine:latest,
#   s390x/alpine:latest,
#   etc.
# as long as your system can run foreign architecture binaries, e.g. via qemu
# static bins and binfmt (install qemu-user-static package on Debian/Ubuntu).
#
#
# To debug, run:
#
#    sudo docker run -it --rm \
#         -v /tmp/artifact:/artifact \
#         -v /home/jfreegman/git/toxic:/toxic \
#         amd64/alpine:latest \
#         /bin/sh
#    # sh /toxic/script/build-minimal-static-toxic.sh

set -eu

ARTIFACT_DIR="/artifact"
TOXIC_SRC_DIR="/toxic"

if [ ! -f /etc/os-release ] || ! grep -qi 'Alpine Linux' /etc/os-release
then
  echo "Error: This script expects to be run on Alpine Linux."
  exit 1
fi

if [ ! -d "$ARTIFACT_DIR" ] || [ ! -d "$TOXIC_SRC_DIR" ]
then
  echo "Error: At least one of $ARTIFACT_DIR or $TOXIC_SRC_DIR directories inside the container is missing."
  exit 1
fi

if [ "$(id -u)" != "0" ]
then
  echo "Error: This script expects to be run as root."
  exit 1
fi

set -x

# Use all cores for building
MAKEFLAGS=j$(nproc)
export MAKEFLAGS
# TODO(nurupo): Once GCC 14 comes out, switch to using the new -fhardened
CFLAGS="-ftrivial-auto-var-init=zero -fPIE -pie -Wl,-z,relro,-z,now -fstack-protector-strong -fstack-clash-protection"
if [ "$(uname -m)" == "x86_64" ]
then
  CFLAGS="$CFLAGS -fcf-protection=full"
fi
export CFLAGS

check_sha256()
{
  if ! ( echo "$1  $2" | sha256sum -cs - )
  then
    echo "Error: sha256 of $2 doesn't match the known one."
    echo "Expected: $1  $2"
    echo "Got: $(sha256sum "$2")"
    exit 1
  else
    echo "sha256 matches the expected one: $1"
  fi
}

apk update
apk upgrade
apk add \
    brotli-dev \
    brotli-static \
    build-base \
    cmake \
    git \
    libconfig-dev \
    libconfig-static \
    libsodium-dev \
    libsodium-static \
    linux-headers \
    ncurses-dev \
    ncurses-static \
    ncurses-terminfo \
    ncurses-terminfo-base \
    nghttp2-dev \
    nghttp2-static \
    openssl-dev \
    openssl-libs-static \
    pkgconf \
    wget \
    xz \
    zlib-dev \
    zlib-static

BUILD_DIR="/tmp/build"
mkdir -p "$BUILD_DIR"


# Build Toxcore
cd "$BUILD_DIR"

# The git hash of the c-toxcore version we're using
TOXCORE_VERSION="0f12f384c8cf62310b9cff6c31e94af7126b7478"

# The sha256sum of the c-toxcore tarball for TOXCORE_VERSION
TOXCORE_HASH="18181e2baef5896d217505b360775e84a30d1f8adf48188c87b76a16ccd634ee"

TOXCORE_FILENAME="c-toxcore-$TOXCORE_VERSION.tar.gz"

wget --timeout=10 -O "$TOXCORE_FILENAME" "https://github.com/TokTok/c-toxcore/archive/$TOXCORE_VERSION.tar.gz"
check_sha256 "$TOXCORE_HASH" "$TOXCORE_FILENAME"

tar -o -xf "$TOXCORE_FILENAME"
rm "$TOXCORE_FILENAME"

cd c-toxcore*
mkdir -p "third_party" && cd "third_party"

CMP_VERSION="cc67a0eab0a7579dcb12ce1072066275d49787bf"
CMP_FILENAME="cmp-$CMP_VERSION.tar.gz"
wget --timeout=10 -O "$CMP_FILENAME" "https://github.com/TokTok/cmp/archive/$CMP_VERSION.tar.gz"
tar -o -xf "$CMP_FILENAME"

mv cmp-*/* 'cmp/'
cd ..

cmake -B_build -H. \
      -DENABLE_STATIC=ON \
      -DENABLE_SHARED=OFF \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_TOXAV=OFF \
      -DBOOTSTRAP_DAEMON=OFF \
      -DDHT_BOOTSTRAP=OFF \
      -DEXPERIMENTAL_API=ON \
      -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/prefix-toxcore"
cmake --build _build --target install


# Build cURL
# While Alpine does provide a static cURL build, it's not built with
# --with-ca-fallback, which is needed for better cross-distro portability.
# Basically, some distros put their ca-certificates in different places, and
# with --with-ca-fallback we or the user can provide the cert bundle file
# location with SSL_CERT_FILE env variable.
cd "$BUILD_DIR"

CURL_VERSION="8.11.1"
CURL_HASH="c7ca7db48b0909743eaef34250da02c19bc61d4f1dcedd6603f109409536ab56"
CURL_FILENAME="curl-$CURL_VERSION.tar.xz"

wget --timeout=10 -O "$CURL_FILENAME" "https://curl.haxx.se/download/$CURL_FILENAME"
check_sha256 "$CURL_HASH" "$CURL_FILENAME"
tar -xf "$CURL_FILENAME"
rm "$CURL_FILENAME"
cd curl*

./configure \
  --prefix="$BUILD_DIR/prefix-curl" \
  --disable-shared \
  --enable-static \
  --disable-ftp \
  --disable-file \
  --disable-ldap \
  --disable-ldaps \
  --disable-rtsp \
  --disable-proxy \
  --disable-dict \
  --disable-telnet \
  --disable-tftp \
  --disable-pop3 \
  --disable-imap \
  --disable-smb \
  --disable-smtp \
  --disable-gopher \
  --disable-mqtt \
  --disable-docs \
  --disable-manual \
  --disable-libcurl-option \
  --disable-sspi \
  --disable-basic-auth \
  --disable-bearer-auth \
  --disable-digest-auth \
  --disable-kerberos-auth \
  --disable-negotiate-auth \
  --disable-aws \
  --disable-ntlm \
  --disable-ntlm-wb \
  --disable-tls-srp \
  --disable-unix-sockets \
  --disable-cookies \
  --disable-http-auth \
  --disable-bindlocal \
  --disable-netrc \
  --disable-websockets \
  --without-ca-bundle \
  --without-ca-path \
  --without-libpsl \
  --with-ca-fallback \
  --with-nghttp2 \
  --with-brotli \
  --with-openssl
make
make install
sed -i 's|-lbrotlidec |-lbrotlidec -lbrotlicommon |g' $BUILD_DIR/prefix-curl/lib/pkgconfig/libcurl.pc


# Build Toxic
cd "$BUILD_DIR"
cp -a "$TOXIC_SRC_DIR" toxic
cd toxic

git config --global --add safe.directory "$PWD"

if [ -z "$(git describe --tags --exact-match HEAD)" ]
then
  set +x
  echo "Didn't find a git tag on the HEAD commit. You seem to be building an in-development release of Toxic rather than a release version." | fold -sw 80
  printf "Do you wish to proceed? (y/N): "
  read -r answer
  if echo "$answer" | grep -v -iq "^y" ; then
    echo "Exiting."
    exit 1
  fi
  set -x
fi

sed -i 's|pkg-config|pkg-config --static|' cfg/global_vars.mk
sed -i 's|<limits.h|<linux/limits.h|' src/*

CFLAGS="$CFLAGS -static" PKG_CONFIG_PATH="$BUILD_DIR/prefix-toxcore/lib64/pkgconfig:$BUILD_DIR/prefix-toxcore/lib/pkgconfig:$BUILD_DIR/prefix-curl/lib/pkgconfig" PREFIX="$BUILD_DIR/prefix-toxic" make \
  DISABLE_X11=1 \
  DISABLE_AV=1 \
  DISABLE_SOUND_NOTIFY=1 \
  DISABLE_QRCODE=1 \
  DISABLE_QRPNG=1 \
  DISABLE_DESKTOP_NOTIFY=1 \
  ENABLE_PYTHON=0 \
  ENABLE_RELEASE=1 \
  ENABLE_ASAN=0 \
  DISABLE_GAMES=0 \
  ENABLE_TOX_EXPERIMENTAL=1 \
  install


# Prepare the build artifact
PREPARE_ARTIFACT_DIR="$BUILD_DIR/artifact"
cp -a "$BUILD_DIR/prefix-toxic/bin" "$PREPARE_ARTIFACT_DIR"
strip "$PREPARE_ARTIFACT_DIR"/*

cp -a "$BUILD_DIR/toxic/misc"/* "$PREPARE_ARTIFACT_DIR"
mv "$PREPARE_ARTIFACT_DIR/toxic.conf.example" "$PREPARE_ARTIFACT_DIR/toxic.conf"

cp -aL /usr/share/terminfo "$PREPARE_ARTIFACT_DIR"

TOXIC_GIT_TAG="$(git -C "$BUILD_DIR/toxic" describe --tags --abbrev=0 || true)"
# GitHub PRs do shallow clones without tags
if [ -z "$TOXIC_GIT_TAG" ]
then
  git -C "$BUILD_DIR/toxic" fetch origin --unshallow
  TOXIC_GIT_TAG="$(git -C "$BUILD_DIR/toxic" describe --tags --abbrev=0)"
fi
TOXIC_GIT_COMMIT="$(git -C "$BUILD_DIR/toxic" rev-parse HEAD)"
TOXIC_GIT_REV="$(git -C "$BUILD_DIR/toxic" rev-list HEAD --count)"
TOXIC_VERSION="${TOXIC_GIT_TAG}_r${TOXIC_GIT_REV} ($TOXIC_GIT_COMMIT)"

echo "A minimal statically compiled Toxic. Doesn't support X11 integration,
video/audio calls, desktop & sound notifications, QR codes and Python
scripting. However, it is rather portable.

Toxic $TOXIC_VERSION

Build date-time: $(TZ=UTC date +"%Y-%m-%dT%H:%M:%S%z")

OS:
$ cat /etc/os-release
$(cat /etc/os-release)

List of self-built software statically compiled into Toxic:
libcurl $CURL_VERSION
libtoxcore $TOXCORE_VERSION

List of OS-packaged software statically compiled into Toxic:
$ apk list -I | grep 'static' | sort -i
$(apk list -I | grep 'static' | sort -i)

List of all packages installed during the build:
$ apk list -I | sort -i
$(apk list -I | sort -i)" > "$PREPARE_ARTIFACT_DIR/build_info"

echo '#!/usr/bin/env sh

DEBIAN_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
RHEL_SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt
OPENSUSE_CERT_FILE=/etc/ssl/ca-bundle.pem
TERMUX_CERT_FILE=/data/data/com.termux/files/usr/etc/tls/cert.pem

if [ ! -f "$SSL_CERT_FILE" ] ; then
  if [ -f "$DEBIAN_SSL_CERT_FILE" ] ; then
    SSL_CERT_FILE="$DEBIAN_SSL_CERT_FILE"
  elif [ -f "$RHEL_SSL_CERT_FILE" ] ; then
    SSL_CERT_FILE="$RHEL_SSL_CERT_FILE"
  elif [ -f "$OPENSUSE_CERT_FILE" ] ; then
    SSL_CERT_FILE="$OPENSUSE_CERT_FILE"
  elif [ -f "$TERMUX_CERT_FILE" ] ; then
    SSL_CERT_FILE="$TERMUX_CERT_FILE"
  fi
fi

if [ -z "$SSL_CERT_FILE" ] ; then
  echo "Warning: Couldn'\''t find the SSL CA certificate store file." | fold -sw 80
  echo
  echo "Toxic uses HTTPS to download a list of DHT bootstrap nodes in order to connect to the Tox DHT. This functionality is optional, you should be able to use Toxic without it. If you choose to use Toxic without it, you might need to manually enter DHT bootstrap node information using the '\''/connect'\'' command in order to come online." | fold -sw 80
  echo
  echo "To fix this issue, install SSL CAs as provided by your Linux distribution, e.g. '\''ca-certificates'\'' package on Debian/Ubuntu. If it'\''s already installed and you still see this message, run this script with SSL_CERT_FILE variable set to point to the SSL CA certificate store file location. The file is usually named '\''ca-certificates.crt'\'' or '\''ca-bundle.pem'\''." | fold -sw 80
  echo
  printf "Do you wish to run Toxic without SSL CA certificate store file found? (y/N): "
  read -r answer
  if echo "$answer" | grep -v -iq "^y" ; then
    echo "Exiting."
    exit
  fi
fi

cd "$(dirname -- $0)"

SSL_CERT_FILE="$SSL_CERT_FILE" TERMINFO=./terminfo ./toxic -c toxic.conf' > "$PREPARE_ARTIFACT_DIR/run_toxic.sh"
chmod a+x "$PREPARE_ARTIFACT_DIR/run_toxic.sh"


# Tar it
cd "$PREPARE_ARTIFACT_DIR"
cd ..
ARCH="$(tr '_' '-' < /etc/apk/arch)"
ARTIFACT_NAME="toxic-minimal-static-musl_linux_$ARCH"
mv "$PREPARE_ARTIFACT_DIR" "$PREPARE_ARTIFACT_DIR/../$ARTIFACT_NAME"
tar -cJf "$ARTIFACT_NAME.tar.xz" "$ARTIFACT_NAME"
mv "$ARTIFACT_NAME.tar.xz" "$ARTIFACT_DIR"
chmod 777 -R "$ARTIFACT_DIR"
