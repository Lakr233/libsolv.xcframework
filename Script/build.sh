#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test -f .root
for platform in macos ios tvos watchos visionos; do
    ./Script/build-platform.sh "$platform" ./build/dest
done
./Script/merge-xcframework.sh ./build/dest ./build/CLibSolv.xcframework.zip
