apt update
apt install -y \
  --no-install-recommends \
  build-essential \
  wget \
  flex bison \
  libgmp-dev \
  libmpfr-dev \
  libmpc-dev \
  libisl-dev \
  texinfo \
  lld

wget https://ftp.gnu.org/gnu/gcc/gcc-16.2.0/gcc-16.2.0.tar.xz
tar -xf gcc-16.2.0.tar.xz
cd gcc-16.2.0
export LDFLAGS="-fuse-ld=lld"
./contrib/download_prerequisites

mkdir build
cd build

LDFLAGS="-fuse-ld=lld" ../configure \
  --enable-languages=c,c++ \
  --disable-multilib \
  --prefix=/opt/gcc-15

make -j$(nproc)

make install

export PATH=/opt/gcc-15/bin:$HOME/.local/bin:$PATH
export PREFIX=/usr/local
export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export CPPFLAGS="-I$PREFIX/include -I/usr/include $CPPFLAGS"
export CFLAGS="-I$PREFIX/include -I/usr/include -O3 -mavx2 $CFLAGS"
export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib -static -static-libgcc -static-libstdc++ $LDFLAGS"
export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH"


echo "Building autoconf 2.71"
apt install build-essential m4 perl texinfo

wget https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz
tar -xf autoconf-2.71.tar.gz
cd autoconf-2.71

./configure
make -j$(nproc)
make install

echo "deleting unneceserry files..."
rm -rf /work

apt-get autoremove -y
