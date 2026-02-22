#!/usr/bin/env bash
set -euo pipefail


echo "Starting HandBrakeCLI build"

# Ensure tools are available
which git
which meson
which ninja
which pkg-config
which nasm

# Clone HandBrake
cd /work
if [ -d HandBrake ]; then
  rm -rf HandBrake
fi
git clone https://github.com/HandBrake/HandBrake.git
cd HandBrake

# Optionally checkout latest stable tag
LATEST_TAG=$(git describe --tags --abbrev=0 || true)
if [ -n "$LATEST_TAG" ]; then
  git checkout "$LATEST_TAG"
fi

# Configure and build CLI only, using bundled x264/x265
# --disable-gtk ensures no GUI deps are required
./configure --disable-gtk --enable-x265 --disable-nvenc --disable-qsv -launch-jobs=$(nproc) --force 

# Install to /usr/local
make --directory=build install

# Verify binary
if [ -x /usr/local/bin/HandBrakeCLI ]; then
  echo "HandBrakeCLI built successfully"
  /usr/local/bin/HandBrakeCLI --version
else
  echo "HandBrakeCLI not found after build"
  ls -la /usr/local/bin || true
  exit 1
fi

# Keep container alive briefly so CI can copy the binary out
echo "Build complete. Binary at /usr/local/bin/HandBrakeCLI"
sleep 2
