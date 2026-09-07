#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test -f .root
ROOT_DIR=$(pwd)
VARIANT=${1:?variant required}
OUTPUT_DIR=${2:?output directory required}
CATALYST_TARGET=""
case "$VARIANT" in
macosx)           SYSTEM_NAME=Darwin   SDK=macosx           ARCHS="x86_64 arm64"          MIN_VERSION=10.13 ;;
maccatalyst)      SYSTEM_NAME=Darwin   SDK=macosx           ARCHS="x86_64 arm64"          MIN_VERSION=""    CATALYST_TARGET=ios13.1-macabi ;;
iphoneos)         SYSTEM_NAME=iOS      SDK=iphoneos         ARCHS="arm64 arm64e"          MIN_VERSION=12.0 ;;
iphonesimulator)  SYSTEM_NAME=iOS      SDK=iphonesimulator  ARCHS="x86_64 arm64"          MIN_VERSION=12.0 ;;
appletvos)        SYSTEM_NAME=tvOS     SDK=appletvos        ARCHS="arm64"                 MIN_VERSION=12.0 ;;
appletvsimulator) SYSTEM_NAME=tvOS     SDK=appletvsimulator ARCHS="x86_64 arm64"          MIN_VERSION=12.0 ;;
# armv7k is dropped: current linkers refuse it ("ld: -arch armv7k is no longer
# supported"), and arm64_32 already covers every watch that can run watchOS 5.
watchos)          SYSTEM_NAME=watchOS  SDK=watchos          ARCHS="arm64_32 arm64"        MIN_VERSION=5.0 ;;
watchsimulator)   SYSTEM_NAME=watchOS  SDK=watchsimulator   ARCHS="x86_64 arm64"          MIN_VERSION=5.0 ;;
xros)             SYSTEM_NAME=visionOS SDK=xros             ARCHS="arm64"                 MIN_VERSION=1.0 ;;
xrsimulator)      SYSTEM_NAME=visionOS SDK=xrsimulator      ARCHS="arm64"                 MIN_VERSION=1.0 ;;
*)
    echo "[!] unknown variant: $VARIANT"
    exit 1
    ;;
esac


WORK_DIR="$ROOT_DIR/build/work/$VARIANT"
SRC_DIR="$ROOT_DIR/build/src/libsolv"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR/$VARIANT/lib"
rm -rf "$OUTPUT_DIR/$VARIANT/include"
mkdir -p "$OUTPUT_DIR/$VARIANT/include"
LIBRARIES=()
for ARCH in $ARCHS; do
    BUILD_DIR="$WORK_DIR/$ARCH"
    FLAGS="-ffile-prefix-map=$ROOT_DIR=. -Werror=unguarded-availability-new"
    if [ -n "$CATALYST_TARGET" ]; then
        FLAGS="$FLAGS -target $ARCH-apple-$CATALYST_TARGET -Wno-overriding-option"
    fi
    cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SYSTEM_NAME="$SYSTEM_NAME" -DCMAKE_OSX_SYSROOT="$SDK" \
        -DCMAKE_OSX_ARCHITECTURES="$ARCH" -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_VERSION" \
        -DCMAKE_C_FLAGS="$FLAGS" -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
        -DHAVE_STRCHRNUL=0 -DHAVE_LINKER_VERSION_SCRIPT=0 -DHAVE_LINKER_AS_NEEDED=0 \
        -DDISABLE_SHARED=ON -DMULTI_SEMANTICS=ON \
        -DENABLE_PYTHON=OFF -DENABLE_PERL=OFF -DENABLE_RUBY=OFF \
        -DENABLE_TCL=OFF -DENABLE_LUA=OFF -DENABLE_DEBIAN=OFF
    cmake --build "$BUILD_DIR" --target libsolv --parallel 4
    LIBRARIES+=("$BUILD_DIR/src/libsolv.a")
    if nm -u "$BUILD_DIR/src/libsolv.a" | grep -q ' _strchrnul$'; then
        echo "Unexpected deployment-incompatible strchrnul import" >&2; exit 1
    fi
done
DEST="$OUTPUT_DIR/$VARIANT"
lipo -create "${LIBRARIES[@]}" -output "$DEST/lib/CLibSolv.a"
# Install only core public headers; building the install target would also build tools/ext.
sed -n '/^SET (libsolv_HEADERS/,/solvversion.h)/p' "$SRC_DIR/src/CMakeLists.txt" | \
    tr ' ()' '\n' | grep -E '^[a-z_]+\.h$' | while read -r header; do
    cp "$SRC_DIR/src/$header" "$DEST/include/"
done
cp "$BUILD_DIR/src/solvversion.h" "$DEST/include/"
cp Vendor/CLibSolv.h "$DEST/include/"
cat > "$DEST/include/module.modulemap" <<'EOF'
module CLibSolv {
    umbrella header "CLibSolv.h"
    export *
}
EOF
lipo -info "$DEST/lib/CLibSolv.a"
