#!/bin/sh
# shellcheck disable=SC2103
# shellcheck disable=SC2003
# shellcheck disable=SC2006
# This script builds a stand-alone binary for the command line version of
# ttfautohint, downloading any necessary libraries.
#
# Version 2019-Aug-14.

# The MIT License (MIT)

# Copyright (c) 2017 Werner Lemberg

# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


#
# User configuration.
#

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# The build directory.
BUILD="$HOME/.tmp/ttfautohint-build"
INST="$HOME/local"

# Excepted build binary path
TTFAUTOHINT_BIN="$INST/bin/ttfautohint"

# The library versions.
FREETYPE_VERSION="2.10.2"
HARFBUZZ_VERSION="2.7.2"
TTFAUTOHINT_VERSION="1.8.3"

# Necessary patches (lists of at most 10 URLs each separated by whitespace,
# to be applied in order).
FREETYPE_PATCHES=""
HARFBUZZ_PATCHES=""
TTFAUTOHINT_PATCHES=""


#
# Nothing to configure below this comment.
#

FREETYPE="freetype-$FREETYPE_VERSION"
HARFBUZZ="harfbuzz-$HARFBUZZ_VERSION"
TTFAUTOHINT="ttfautohint-$TTFAUTOHINT_VERSION"

if test -d "$BUILD" -o -f "$BUILD"; then
  echo "${RED}Error: Build directory \`$BUILD' must not exist.${NC}"
  exit 1
fi

mkdir -p "$BUILD"
mkdir "$INST"

cd "$BUILD" || exit 1


echo "${GREEN}Downloading all necessary archives and patches ...${NC}"

curl -L -O "https://download.savannah.gnu.org/releases/freetype/$FREETYPE.tar.gz"
curl -L -O "https://github.com/harfbuzz/harfbuzz/releases/download/$HARFBUZZ_VERSION/$HARFBUZZ.tar.xz"
curl -L -O "https://download.savannah.gnu.org/releases/freetype/$TTFAUTOHINT.tar.gz"

count=0
for i in $FREETYPE_PATCHES
do
  curl -o ft-patch-$count.diff "$i"
  count=`expr $count + 1`
done

count=0
for i in $HARFBUZZ_PATCHES
do
  curl -o hb-patch-$count.diff "$i"
  count=`expr $count + 1`
done

count=0
for i in $TTFAUTOHINT_PATCHES
do
  curl -o ta-patch-$count.diff "$i"
  count=`expr $count + 1`
done


# Our environment variables.
TA_CPPFLAGS="-I$INST/include"
TA_CFLAGS="-g -O2"
TA_CXXFLAGS="-g -O2"
TA_LDFLAGS="-L$INST/lib -L$INST/lib64"


echo "${GREEN}Extract archives ...${NC}"

tar -xzvf "$FREETYPE.tar.gz"
tar -xvf "$HARFBUZZ.tar.xz"
tar -xzvf "$TTFAUTOHINT.tar.gz"


echo "${GREEN}Apply patches...${NC}"

cd "$FREETYPE" || exit 1
for i in ../ft-patch-*.diff
do
  test -f "$i" || continue
  patch -p1 -N -r - < "$i"
done
cd ..

cd "$HARFBUZZ" || exit 1
for i in ../hb-patch-*.diff
do
  test -f "$i" || continue
  patch -p1 -N -r - < "$i"
done
cd ..

cd "$TTFAUTOHINT" || exit 1
for i in ../ta-patch-*.diff
do
  test -f "$i" || continue
  patch -p1 -N -r - < "$i"
done
cd ..


echo "${GREEN}Building $FREETYPE ...${NC}"

cd "$FREETYPE" || exit 1

# The space in `PKG_CONFIG' ensures that the created `freetype-config' file
# doesn't find a working pkg-config, falling back to the stored strings
# (which is what we want).
./configure \
  --without-bzip2 \
  --without-png \
  --without-zlib \
  --without-harfbuzz \
  --prefix="$INST" \
  --enable-static \
  --disable-shared \
  --enable-freetype-config \
  PKG_CONFIG=" " \
  CFLAGS="$TA_CPPFLAGS $TA_CFLAGS" \
  CXXFLAGS="$TA_CPPFLAGS $TA_CXXFLAGS" \
  LDFLAGS="$TA_LDFLAGS"
make
make install
cd ..


echo "${GREEN}Building $HARFBUZZ ...${NC}"

cd "$HARFBUZZ" || exit 1

# Value `true' for `PKG_CONFIG' ensures that XXX_CFLAGS and XXX_LIBS
# get actually used.
./configure \
  --disable-dependency-tracking \
  --disable-gtk-doc-html \
  --with-glib=no \
  --with-cairo=no \
  --with-fontconfig=no \
  --with-icu=no \
  --prefix="$INST" \
  --enable-static \
  --disable-shared \
  CFLAGS="$TA_CPPFLAGS $TA_CFLAGS" \
  CXXFLAGS="$TA_CPPFLAGS $TA_CXXFLAGS" \
  LDFLAGS="$TA_LDFLAGS" \
  PKG_CONFIG=true \
  FREETYPE_CFLAGS="$TA_CPPFLAGS/freetype2" \
  FREETYPE_LIBS="$TA_LDFLAGS -lfreetype"
make
make install
cd ..


echo "${GREEN}Building $TTFAUTOHINT ... ${NC}"

cd "$TTFAUTOHINT" || exit 1

# Value `true' for `PKG_CONFIG' ensures that XXX_CFLAGS and XXX_LIBS
# get actually used.
./configure \
  --disable-dependency-tracking \
  --without-qt \
  --without-doc \
  --prefix="$INST" \
  --enable-static \
  --disable-shared \
  --with-freetype-config="$INST/bin/freetype-config" \
  CFLAGS="$TA_CPPFLAGS $TA_CFLAGS" \
  CXXFLAGS="$TA_CPPFLAGS $TA_CXXFLAGS" \
  LDFLAGS="$TA_LDFLAGS" \
  PKG_CONFIG=true \
  HARFBUZZ_CFLAGS="$TA_CPPFLAGS/harfbuzz" \
  HARFBUZZ_LIBS="$TA_LDFLAGS -lharfbuzz"
make LDFLAGS="$TA_LDFLAGS -all-static"
make install-strip
cd ..

echo "${GREEN}Cleaning up ...${NC}"
rm -rf $HOME/.tmp/ttfautohint-build

# test for the expected path to the executable
if [ -f "$INST/bin/ttfautohint" ]; then
  echo "${GREEN}ttfautohint compiled successfully!${NC}"
  echo "${GREEN}Path to binary: ${BLUE}$TTFAUTOHINT_BIN${NC}"
else
  echo "${RED}Error: ttfautohint executable was not found on the path $TTFAUTOHINT_BIN${NC}" 1>&2
  exit 1
fi

# eof
