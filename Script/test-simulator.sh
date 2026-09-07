#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test -f .root
# Use a disposable device on an installed iOS runtime, preserving personal simulators.
read -r runtime device_type < <(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(k+" "+x["deviceTypeIdentifier"] for k,devices in d["devices"].items() if ".iOS-" in k for x in devices if "iPhone" in x["deviceTypeIdentifier"]))')
device=$(xcrun simctl create "LibSolv Verification" "$device_type" "$runtime")
trap 'xcrun simctl delete "$device"' EXIT
xcodebuild -scheme LibSolv-Package -destination "platform=iOS Simulator,id=$device" \
    -derivedDataPath "${DERIVED_DATA:-$HOME/Library/Caches/libsolv-simulator}" \
    CODE_SIGNING_ALLOWED=NO test
