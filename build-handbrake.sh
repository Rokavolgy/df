#!/bin/bash
set -ex

# build-handbrake-giga.sh
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
  autoconf-archive libsndfile-devel speexdsp-devel speex-devel libjpeg-turbo-devel libjpeg-turbo > /dev/null

# Ensure basic tools are available
which git
which pkg-config
which nasm
which yasm

# Export pkg-config path for /usr/local
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export CPPFLAGS="-I$PREFIX/include $CPPFLAGS"
export LDFLAGS="-L$PREFIX/lib $LDFLAGS"
export PATH="$PREFIX/bin:$PATH"

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


# -----------------------------------------------------------------------------
# Build and install LAME (libmp3lame) from source
# -----------------------------------------------------------------------------
echo "Building LAME (libmp3lame) from source"

cd "$WORKDIR"
rm -rf lame-3.100 lame-3.100.tar.gz
wget -q https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
tar xf lame-3.100.tar.gz
cd lame-3.100
./configure --enable-shared --prefix="$PREFIX"
make -j"$NPROC" > /dev/null
make install
ldconfig

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

# -----------------------------------------------------------------------------
# Clone and build HandBrakeCLI (no GUI)
# -----------------------------------------------------------------------------
echo "Cloning HandBrake and building HandBrakeCLI"

cd "$WORKDIR"
rm -rf HandBrake
git clone https://github.com/HandBrake/HandBrake.git
cd HandBrake

# Optionally checkout latest stable tag
LATEST_TAG=$(git describe --tags --abbrev=0 || true)
if [ -n "$LATEST_TAG" ]; then
  echo "Checking out latest tag $LATEST_TAG"
  git checkout "$LATEST_TAG"
fi

# Override to master
git checkout master

# Configure and build CLI only. We built system x264 and libmp3lame, but also allow HandBrake to build bundled codecs if needed.
# --disable-gtk ensures no GUI dependencies are required.
./configure --disable-gtk --disable-nvenc --disable-qsv -launch-jobs=$(nproc) --force CFLAGS="-I/usr/include/turbojpeg -I/usr/local/include" --launch 

# Install HandBrakeCLI to /usr/local
make --directory=build install

# Verify HandBrakeCLI
if [ -x /usr/local/bin/HandBrakeCLI ]; then
  echo "HandBrakeCLI built successfully"
  /usr/local/bin/HandBrakeCLI --version
else
  echo "ERROR: HandBrakeCLI not found after build"
  ls -la /usr/local/bin || true
  exit 1
fi

echo "Giga build complete. HandBrakeCLI is at /usr/local/bin/HandBrakeCLI"
echo "Libraries installed to $PREFIX"

sleep 10
