#!/bin/bash
set -ex

# prepare-static-libs.sh
# Builds x264, LAME, speexdsp/speex (if needed).
# No GUI. Installs libraries to /usr/local.

WORKDIR=/work
PREFIX=/usr/local
NPROC=$(nproc)

echo "Starting giga build: x264, lame, speexdsp"
echo "Workdir: $WORKDIR"
echo "Install prefix: $PREFIX"
echo "Parallel jobs: $NPROC"

export PKG_CONFIG="pkg-config --static" 
export HB_BUILD_STATIC=1

# Ensure workdir exists
mkdir -p "$WORKDIR"
chown "$(id -u):$(id -g)" "$WORKDIR"
cd "$WORKDIR"

# Update and install system packages
echo "Installing system packages"

# Ensure basic tools are available
which git
which pkg-config
which nasm
which yasm

# Export pkg-config path for /usr/local
export PREFIX=/usr/local
export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export CPPFLAGS="-I$PREFIX/include -I/usr/include $CPPFLAGS"
export CFLAGS="-I$PREFIX/include -I/usr/include -fPIC -O3 -mavx2 $CFLAGS"
export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib $LDFLAGS"
export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH"

echo "Building x264 from source"

cd "$WORKDIR"
rm -rf x264
git clone https://code.videolan.org/videolan/x264.git
cd x264

# Optionally checkout a stable tag. Comment out if you want latest master.
# Example: git checkout stable
# Use default branch for latest stable-ish code
./configure --enable-static --disable-shared --enable-pic --prefix="$PREFIX"
make -j"$NPROC"
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

#libjpeg
echo "Building libjpeg"
git clone --depth 1 https://github.com/libjpeg-turbo/libjpeg-turbo.git
cd libjpeg-turbo
cmake -G"Unix Makefiles" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DENABLE_SHARED=OFF -DENABLE_STATIC=ON \
  -DWITH_JPEG8=ON .
make -j"$NPROC"
make install

pkg-config --static --libs libturbojpeg || true
ls -l $PREFIX/lib64/libturbojpeg.a
ls -l $PREFIX/include/turbojpeg.h

#libfreetype
git clone --depth 1 https://git.savannah.gnu.org/git/freetype/freetype2.git
cd freetype2
./autogen.sh || true
./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic
make -j"$NPROC"
make install


ln -sf /usr/include/turbojpeg.h /usr/local/include/turbojpeg.h
ln -sf /usr/lib64/libturbojpeg.so /usr/local/lib/libturbojpeg.so
ldconfig
# -----------------------------------------------------------------------------
# Build and install LAME (libmp3lame) from source
# -----------------------------------------------------------------------------
echo "Building LAME (libmp3lame) from source"

cd "$WORKDIR"
rm -rf lame-3.100 lame-3.100.tar.gz
wget -q https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
tar xf lame-3.100.tar.gz
cd lame-3.100
./configure --enable-static --disable-shared --prefix="$PREFIX"
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

apk add --no-cache build-base autoconf automake libtool pkgconf freetype-dev harfbuzz-dev fribidi-dev pkgconfig git

git clone --depth 1 https://github.com/libass/libass.git
cd libass

# generate configure if needed
./autogen.sh    # only required if building from git

# configure for static-only
./configure --prefix=/usr/local \
            --enable-static --disable-shared \
            --with-freetype-prefix=/usr/local \
            --with-harfbuzz-prefix=/usr/local \
            --with-fribidi-prefix=/usr/local

make -j$(nproc)
make install

#libnuma
git clone --depth 1 https://github.com/numactl/numactl.git
cd numactl
./autogen.sh || true
./configure --prefix="$PREFIX" --enable-static --disable-shared
make -j"$NPROC"
make install

# -----------------------------------------------------------------------------
# Build and install speexdsp and speex from source if pkg-config can't find them
# -----------------------------------------------------------------------------
echo "Checking speex and speexdsp"
# libspeex
git clone --depth 1 https://github.com/xiph/speex.git speex
cd speex
./autogen.sh || true
./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic
make -j"$NPROC"
make install
cd ..

# speexdsp (if separate)
git clone --depth 1 https://github.com/xiph/speexdsp.git speexdsp
cd speexdsp
./autogen.sh || true
./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic
make -j"$NPROC"
make install
cd ..

#libvpx
git clone --depth 1 https://chromium.googlesource.com/webm/libvpx
cd libvpx

# configure for static-only
./configure --prefix="$PREFIX" \
            --enable-static --disable-shared \
            --disable-examples --disable-unit-tests \
            --disable-docs \
            --disable-runtime-cpu-detect

make -j"$NPROC"
make install

#libopus
git clone --depth 1 https://github.com/xiph/opus.git
cd opus

./autogen.sh || true
./configure --prefix="$PREFIX" \
            --enable-static --disable-shared \
            --with-pic
make -j"$NPROC"
make install
#verify

ls -l $PREFIX/lib/libopus.a
pkg-config --static --libs opus


ls -l $PREFIX/lib/libvpx.a
pkg-config --static --libs vpx

# libogg
git clone --depth 1 https://github.com/xiph/ogg.git
cd ogg
./autogen.sh
./configure --prefix="$PREFIX" --enable-static --disable-shared
make -j"$NPROC"
make install
cd ..

# libvorbis
git clone --depth 1 https://github.com/xiph/vorbis.git
cd vorbis
./autogen.sh
./configure --prefix="$PREFIX" --enable-static --disable-shared
make -j"$NPROC"
make install

# libjansson
git clone --depth 1 https://github.com/akheron/jansson.git
cd jansson
cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON .
make -j"$NPROC"
make install

#fix for fribidi
export CFLAGS="-std=gnu11 $CFLAGS"
#libfribidi 
git clone --depth 1 https://github.com/fribidi/fribidi.git
cd fribidi
meson setup build -Ddefault_library=static -Dbuildtype=release -Dprefix="$PREFIX" -Ddocs=false -Dtests=false -Dbin=false || true
meson compile -C build
meson install -C build
cd ..

export PREFIX=/usr/local
export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export CPPFLAGS="-I$PREFIX/include -I/usr/include $CPPFLAGS"
export CFLAGS="-I$PREFIX/include -I/usr/include -fPIC $CFLAGS"
export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib $LDFLAGS"
export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH"

#graphite2
git clone --depth 1 https://github.com/silnrsi/graphite.git
cd graphite
mkdir build && cd build

cmake .. \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON

make -j$(nproc)
make install



#skip for now
#fontconfig
#git clone --depth 1 https://gitlab.freedesktop.org/fontconfig/fontconfig.git
#cd fontconfig
#./autogen.sh || true
#./configure --prefix="$PREFIX" --enable-static --disable-shared --with-add-fonts=/usr/share/fonts || true
#make -j"$NPROC" && make install || true
#cd ..

#harfbuzz
git clone --depth 1 https://github.com/harfbuzz/harfbuzz.git
cd harfbuzz
meson setup build -Ddefault_library=static -Dglib=disabled -Dgraphite=enabled -Dintrospection=disabled -Dtests=disabled -Dprefix="$PREFIX"
meson compile -C build
meson install -C build
cd ..

#this will probably fail
git clone --depth 1 https://gitlab.gnome.org/GNOME/glib.git
cd glib
meson setup build \
  -Ddefault_library=static \
  -Dinternal_pcre=false \
  -Dlibmount=false \
  -Dselinux=false \
  -Dman=false \
  -Dinstalled_tests=false \
  -Dtests=false \
  -Diconv=external \
  -Dprefix="$PREFIX" || true
meson compile -C build || true
meson install -C build || true

#libtheora
git clone --depth 1 https://github.com/xiph/theora.git
cd theora
./autogen.sh
./configure --prefix="$PREFIX" --enable-static --disable-shared
make -j"$NPROC" && make install
cd ..





# Re-export pkg-config path in case files were added
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export CPPFLAGS="-I$PREFIX/include $CPPFLAGS"
export LDFLAGS="-L$PREFIX/lib $LDFLAGS"

pkg-config --static --libs speex 
ls -l $PREFIX/lib/libspeex.a

# ln -sf /usr/local/include/turbojpeg.h /usr/include/turbojpeg.h || true
# ln -sf /usr/local/lib64/pkgconfig/libturbojpeg.pc /usr/lib64/pkgconfig/libturbojpeg.pc || true
ldconfig || true

# -----------------------------------------------------------------------------
# Clone and build HandBrakeCLI (no GUI)
# -----------------------------------------------------------------------------
# Found packages
echo "Listing packages."
echo "method1"
pkg-config --list-all | awk '{print $1}' | while read -r pkg; do
  if pkg-config --static --libs "$pkg" >/dev/null 2>&1; then
    echo "$pkg"
  fi
done
echo "method2"
for pc in $(pkg-config --variable pc_path pkg-config 2>/dev/null | tr ':' '\n' | sed -n '1,100p' | xargs -I{} find {} -name '*.pc' 2>/dev/null); do
  if grep -qE 'Libs.private|\.a' "$pc"; then
    basename "$pc" .pc
  fi
done | sort -u

echo "Libraries installed to $PREFIX"

sleep 10
