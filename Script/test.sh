#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test -f .root
mkdir -p build/logs
swift test
for destination in \
    'generic/platform=macOS' \
    'generic/platform=macOS,variant=Mac Catalyst' \
    'generic/platform=iOS' 'generic/platform=iOS Simulator' \
    'generic/platform=tvOS' 'generic/platform=tvOS Simulator' \
    'generic/platform=watchOS' 'generic/platform=watchOS Simulator' \
    'generic/platform=visionOS' 'generic/platform=visionOS Simulator'; do
    label=$(echo "$destination" | tr -cs '[:alnum:]' '-')
    arch_flags=()
    if [[ "$destination" == *visionOS* ]]; then arch_flags=(ARCHS=arm64); fi
    for scheme in LibSolv LibSolvDynamic; do
        echo "Building $scheme: $destination"
        xcodebuild -scheme "$scheme" -destination "$destination" \
            -derivedDataPath "${DERIVED_DATA:-$HOME/Library/Caches/libsolv-verification}/$label" \
            CODE_SIGNING_ALLOWED=NO "${arch_flags[@]}" build > "build/logs/$scheme-$label.log" 2>&1 || {
            tail -80 "build/logs/$scheme-$label.log"; exit 1;
        }
    done
done
