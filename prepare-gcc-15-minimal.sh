apt update
apt install -y \
  build-essential \
  wget \
  flex bison \
  libgmp-dev \
  libmpfr-dev \
  libmpc-dev \
  libisl-dev \
  texinfo

wget https://ftp.gnu.org/gnu/gcc/gcc-15.2.0/gcc-15.2.0.tar.xz
tar -xf gcc-15.2.0.tar.xz
cd gcc-15.2.0

./contrib/download_prerequisites

mkdir build
cd build

../configure \
  --enable-languages=c,c++ \
  --disable-multilib \
  --prefix=/opt/gcc-15

make -j$(nproc)

make install
