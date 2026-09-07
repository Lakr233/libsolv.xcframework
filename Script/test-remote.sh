#!/bin/bash
set -euo pipefail
version=${1:?package version required}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
work=$(mktemp -d "${TMPDIR:-/tmp}/libsolv-consumer.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/Sources/Consumer"
cat > "$work/Package.swift" <<MANIFEST
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Consumer", platforms: [.macOS(.v13)], dependencies: [
    .package(url: "https://github.com/Lakr233/libsolv.xcframework.git", exact: "$version")
], targets: [.executableTarget(name: "Consumer", dependencies: [.product(name: "LibSolv", package: "libsolv.xcframework")])])
MANIFEST
cat > "$work/Sources/Consumer/main.swift" <<'SWIFT'
import LibSolv
let solver = try SolverEnvironment(architecture: "arm64")
let repo = try solver.addRepository(name: "sample")
try solver.addPackage(PackageDefinition(name: "hello", version: "1", architecture: "all"), to: repo)
let result = try solver.solve([Job(.install, .name("hello"))])
precondition(result.installed.map(\.name) == ["hello"])
print("Remote package download, checksum, linking and resolution passed")
SWIFT
swift run --package-path "$work" --cache-path "$work/cache" --scratch-path "$work/build" Consumer
