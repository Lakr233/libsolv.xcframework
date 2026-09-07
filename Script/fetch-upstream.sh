#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test -f .root
source Upstream.versions
[[ "$LIBSOLV_REF" =~ ^[0-9a-f]{40}$ ]]
SRC=build/src/libsolv
if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$SRC"
    git -C "$SRC" init -q
    git -C "$SRC" remote add origin "$LIBSOLV_REPO"
fi
test "$(git -C "$SRC" remote get-url origin)" = "$LIBSOLV_REPO"
if ! git -C "$SRC" cat-file -e "$LIBSOLV_REF^{commit}" 2>/dev/null; then
    git -C "$SRC" fetch --depth 1 origin "$LIBSOLV_REF"
fi
git -C "$SRC" checkout --detach --force "$LIBSOLV_REF"
git -C "$SRC" apply --check "$PWD/Vendor/apple-strchrnul.patch"
git -C "$SRC" apply "$PWD/Vendor/apple-strchrnul.patch"
