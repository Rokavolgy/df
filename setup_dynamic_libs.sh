#!/bin/bash
set -ex

# build-handbrake.sh
# Builds x264, LAME, speexdsp/speex (if needed), then HandBrakeCLI on Amazon Linux 2023.
# No GUI. Installs libraries to /usr/local and HandBrakeCLI to /usr/local/bin.

WORKDIR=/work
PREFIX=/usr/local
NPROC=$(nproc)

echo "Starting giga build: x264, lame, speexdsp, handbrakecli"
echo "Workdir: $WORKDIR"
echo "Install prefix: $PREFIX"
echo "Parallel jobs: $NPROC"

# Ensure workdir exists
mkdir -p "$WORKDIR"
chown "$(id -u):$(id -g)" "$WORKDIR"
cd "$WORKDIR"

# Update and install system packages
echo "Installing system packages"
dnf makecache
dnf -y update 

dnf -y groupinstall "Development Tools" 
dnf -y install \
  rpm-build redhat-rpm-config rpmdevtools \
  pkgconf-pkg-config pkgconf \
  meson ninja-build cmake autoconf automake libtool \
  gcc gcc-c++ git tar python3 python3-pip \
  fribidi-devel harfbuzz-devel freetype-devel \
  jansson-devel libogg-devel libvorbis-devel \
  libtheora-devel libvpx-devel x265-devel \
  numactl-devel bzip2-devel zlib-devel libass-devel \
  nasm yasm pkgconfig which wget make perl \
  autoconf-archive libsndfile-devel speexdsp-devel speex-devel libjpeg-turbo-devel libjpeg-turbo turbojpeg-devel lame libatomic

# Ensure basic tools are available
which git
which pkg-config
which nasm
which yasm

# Export pkg-config path for /usr/local
export PREFIX=/usr/local
export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export CPPFLAGS="-I$PREFIX/include -I/usr/include $CPPFLAGS"
export CFLAGS="-I$PREFIX/include -I/usr/include $CFLAGS"
export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib $LDFLAGS"
export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH"

# -----------------------------------------------------------------------------
# Build and install x264 from source
# -----------------------------------------------------------------------------
echo "Building x264 from source"

cd "$WORKDIR"
rm -rf x264
git clone https://code.videolan.org/videolan/x264.git
cd x264

# Optionally checkout a stable tag. Comment out if you want latest master.
# Example: git checkout stable
# Use default branch for latest stable-ish code
./configure --enable-shared --enable-pic --prefix="$PREFIX" > /dev/null
make -j"$NPROC" > /dev/null
make install
ldconfig

# Verify x264
if pkg-config --exists x264; then
  echo "x264 found via pkg-config"
  pkg-config --modversion x264 || true
else
  echo "Warning: pkg-config cannot find x264. Listing $PREFIX/lib/pkgconfig"
  ls -la "$PREFIX/lib/pkgconfig" || true
fi

#Verify libjpeg
if pkg-config --exists libjpeg; then
  echo "libjpeg-turbo found via pkg-config"
  pkg-config --modversion libjpeg
elif pkg-config --exists turbojpeg; then
  echo "turbojpeg found via pkg-config"
  pkg-config --modversion turbojpeg
else
  echo "Warning: TurboJPEG NOT found via pkg-config"
  echo "Listing $PREFIX/lib/pkgconfig"
  ls -la "$PREFIX/lib/pkgconfig" || true
fi

echo "Building TurboJPEG from source"

git clone https://github.com/libjpeg-turbo/libjpeg-turbo.git
cd libjpeg-turbo

cmake -G"Unix Makefiles" -DCMAKE_INSTALL_PREFIX=/usr/local .
make -j$(nproc)
make install
ldconfig

#Double checking it
echo "Checking TurboJPEG"

if [ -f /usr/local/include/turbojpeg.h ]; then
  echo "TurboJPEG header OK"
else
  echo "ERROR: turbojpeg.h missing"
  ls -la /usr/local/include || true
  exit 1
fi

if pkg-config --exists libturbojpeg; then
  echo "TurboJPEG pkg-config OK"
  pkg-config --modversion libturbojpeg
else
  echo "ERROR: TurboJPEG pkg-config missing"
  ls -la /usr/local/lib64/pkgconfig || true
  exit 1
fi

ln -sf /usr/include/turbojpeg.h /usr/local/include/turbojpeg.h
ln -sf /usr/lib64/libturbojpeg.so /usr/local/lib/libturbojpeg.so
ldconfig
# -----------------------------------------------------------------------------
# Build and install LAME (libmp3lame) from source
# -----------------------------------------------------------------------------
#echo "Building LAME (libmp3lame) from source"

#cd "$WORKDIR"
#rm -rf lame-3.100 lame-3.100.tar.gz
#wget -q https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
#tar xf lame-3.100.tar.gz
#cd lame-3.100
#./configure --enable-shared --prefix="$PREFIX"
#make -j"$NPROC" > /dev/null
#make install
#ldconfig

# Verify libmp3lame
if pkg-config --exists libmp3lame; then
  echo "libmp3lame found via pkg-config"
  pkg-config --modversion libmp3lame || true
else
  echo "Warning: pkg-config cannot find libmp3lame. Listing $PREFIX/lib/pkgconfig"
  ls -la "$PREFIX/lib/pkgconfig" || true
fi

# -----------------------------------------------------------------------------
# Build and install speexdsp and speex from source if pkg-config can't find them
# -----------------------------------------------------------------------------
echo "Checking speex and speexdsp"
dnf makecache 
dnf install -y speexdsp-devel speex-devel pkgconf-pkg-config

# Re-export pkg-config path in case files were added
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export CPPFLAGS="-I$PREFIX/include $CPPFLAGS"
export LDFLAGS="-L$PREFIX/lib $LDFLAGS"


ln -sf /usr/local/include/turbojpeg.h /usr/include/turbojpeg.h || true
ln -sf /usr/local/lib64/pkgconfig/libturbojpeg.pc /usr/lib64/pkgconfig/libturbojpeg.pc || true
ldconfig || true
chmod +x ./HandBrakeCLI
LD_LIBRARY_PATH=/usr/local/lib64:/usr/local/lib:$LD_LIBRARY_PATH ./HandBrakeCLI --version
