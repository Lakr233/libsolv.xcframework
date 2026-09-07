#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test -f .root
source Upstream.versions
requested=${1:-latest}
tags=$(git ls-remote --tags "$LIBSOLV_REPO")
if [ "$requested" = latest ]; then
    requested=$(printf '%s\n' "$tags" | sed -nE 's|.*refs/tags/([0-9]+\.[0-9]+\.[0-9]+)$|\1|p' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
fi
[[ "$requested" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
ref=$(printf '%s\n' "$tags" | awk -v tag="refs/tags/$requested^{}" '$2 == tag {print $1}')
if [ -z "$ref" ]; then
    ref=$(printf '%s\n' "$tags" | awk -v tag="refs/tags/$requested" '$2 == tag {print $1}')
fi
[[ "$ref" =~ ^[0-9a-f]{40}$ ]]
if [ "${2:-}" = --write ]; then
    printf 'LIBSOLV_REPO=%s\nLIBSOLV_VERSION=%s\nLIBSOLV_REF=%s\n' "$LIBSOLV_REPO" "$requested" "$ref" > Upstream.versions
else
    printf '%s %s\n' "$requested" "$ref"
fi
