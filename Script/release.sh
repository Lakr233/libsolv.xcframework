#!/bin/bash
# Only the release workflow calls this script; local builds are never published.
set -euo pipefail
cd "$(dirname "$0")/.."
test -f .root
test "${GITHUB_ACTIONS:-}" = true
test "$GITHUB_REF" = refs/heads/main
[[ "$PACKAGE_TAG" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "$STORAGE_TAG" =~ ^upstream\.[0-9a-f]{12}\.[0-9]+$ ]]
git fetch origin main
test "$(git rev-parse origin/main)" = "$GITHUB_SHA" || {
    echo 'main changed during verification; rerun on the new commit' >&2; exit 1;
}
for tag in "$PACKAGE_TAG" "$STORAGE_TAG"; do
    rc=0
    ./Script/next-tag.sh exists "$tag" || rc=$?
    test "$rc" = 1 || { echo "Tag exists or could not be checked: $tag" >&2; exit 1; }
done
url="https://github.com/$GITHUB_REPOSITORY/releases/download/$STORAGE_TAG/CLibSolv.xcframework.zip"
./Script/build-manifest.sh build/release/CLibSolv.xcframework.zip "$url"
swift package dump-package >/dev/null
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add Package.swift Upstream.versions
git commit -m "Release $PACKAGE_TAG ($STORAGE_TAG)"
commit=$(git rev-parse HEAD)
# The guarded non-force push also catches main moving after the fetch above.
git push origin HEAD:main
gh release create "$STORAGE_TAG" --target "$commit" --title "$STORAGE_TAG" \
    --notes-file build/release/BUILD-INFO.txt \
    build/release/CLibSolv.xcframework.zip build/release/BUILD-INFO.txt
printf 'libsolv static XCFramework and Swift 6 binding.\n\nBinary: `%s`.\nSee BUILD-INFO.txt on the binary release for source pins and CI provenance.\n' "$STORAGE_TAG" > build/release/package-notes.md
gh release create "$PACKAGE_TAG" --target "$commit" --title "$PACKAGE_TAG" --notes-file build/release/package-notes.md
