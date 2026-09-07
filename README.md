# libsolv.xcframework

Use [libsolv](https://github.com/openSUSE/libsolv) as a self-contained static Apple
XCFramework with a Swift 6 binding. Binaries are built and tested by GitHub
Actions before publication. You do not need Python, Ruby, Perl, SWIG, a Homebrew
runtime, or an external helper process.

## Install

Requires Swift tools **6.0** or later. Swift sources use Swift 6 language mode.
The package release version is independent of the Swift tools version.

```swift
.package(url: "https://github.com/Lakr233/libsolv.xcframework.git", from: "0.1.0")
```

Use the `LibSolv` product for normal linking, or `LibSolvDynamic` when multiple
targets need a shared dynamic library. Both use the same static C artifact.
The C module is `CLibSolv`; the Swift module is `LibSolv`, avoiding module-name
collisions on case-insensitive filesystems. `import LibSolv` also exposes the
upstream C API.

```swift
import LibSolv

let environment = try SolverEnvironment(distribution: .debian, architecture: "arm64")
let repository = try environment.addRepository(name: "example")
try environment.addPackage(
    PackageDefinition(name: "library", version: "2", architecture: "all"),
    to: repository
)
var app = PackageDefinition(name: "app", version: "1", architecture: "arm64")
app.requires = [.versioned("library", .greaterThanOrEqual, "2")]
let appID = try environment.addPackage(app, to: repository)
let result = try environment.solve([Job(.install, .package(appID))])
for package in result.installed {
    print(package.name, package.version)
}
```

Create another repository and call `setInstalledRepository` to model the current
installation. `Job(.update, .all)` requests updates; `.remove` and `.lock` accept
the same selections. Set options for uninstall and downgrade permission,
recommendations, and strict repository priority. Defaults keep libsolv's
recommendation behavior, forbid implicit uninstall and downgrade, and leave
strict repository priority off.

A `SolverEnvironment` is **not Sendable**. Keep
it within one thread or task. Independent environments can solve concurrently.
Package and repository IDs are checked against their owning environment. A
`Resolution`, its packages and diagnostic strings are copied values; they
remain valid after further solves or destruction of the environment. `solve`
does not mutate the installed repository: callers explicitly supply installed
state for subsequent transactions.

## Minimum Operating Systems

The C library and Swift binding target the minimum OS versions below.
Each architecture can have its own minimum; arm64 variants can require a
newer OS than older architectures.

| Platform | Architectures | Minimum OS |
| --- | --- | --- |
| macOS | x86_64 / arm64 | 10.13 / 11.0 |
| Mac Catalyst | x86_64 / arm64 | 13.1 / 14.0 |
| iOS | arm64 / arm64e | 12.0 / 14.0 |
| iOS Simulator | x86_64 / arm64 | 12.0 / 14.0 |
| tvOS | arm64 | 12.0 |
| tvOS Simulator | x86_64 / arm64 | 12.0 / 14.0 |
| watchOS | arm64_32 / arm64 | 5.0 / 26.0 |
| watchOS Simulator | x86_64 / arm64 | 5.0 / 7.0 |
| visionOS and Simulator | arm64 | 1.0 |

For watchOS apps, restrict device architectures to `arm64_32 arm64`
(or exclude `armv7k` in the application build settings). Some Xcode versions
include `armv7k` by default for a watchOS 5 target; that legacy architecture
is not shipped. visionOS Simulator supports arm64 only.

Tests use Swift Testing on macOS 13 and iOS 16 or later. That does not raise
the library's minimum OS.

## What Is Included

Includes libsolv core with Debian, RPM, Arch, Haiku, and APK semantics.
Repository readers from libsolvext, language bindings, executables
and compression libraries are not built or shipped. Supply package definitions
programmatically, or use the upstream core API for its native `.solv` format.

This package wraps **libsolv**, not APT. Repository priorities are libsolv
priorities, not APT pin values. `obsoletes` is not Debian `Replaces`, and ordered
transaction steps are not a dpkg unpack/configure plan. Handle
distribution-specific metadata, policy, and execution in your app.

With `.debian` selected, libsolv 0.7.39 orders version `1` before `1-0`. dpkg
treats them as equal. This binding keeps libsolv's comparison. Selecting
`.debian` does not make the solver match APT or dpkg.

## Build and Test

Install Xcode, CMake and Ninja, then:

```sh
./Script/build.sh
python3 Script/verify-binary.py
./Script/test.sh
./Script/test-simulator.sh
swift test --sanitize address
```

Build scripts fetch the pinned libsolv commit. The Apple compatibility patch
in `Vendor/` keeps the library building on older OS versions.

`BinaryTarget/CLibSolv.xcframework` overrides the remote binary for local tests.
After removing it, run `swift package clean` and `swift package purge-cache`
before switching back to a remote artifact. `Package.swift` is generated;
change `Package.swift.template` instead.

To rebuild only one platform group:

```sh
./Script/build-platform.sh ios ./build/dest
```

## Releases

The **Build libsolv** workflow publishes binaries after tests pass. Releases
are built with Xcode 26.3.

- `upstream.<commit12>.<revision>` stores `CLibSolv.xcframework.zip` and build provenance.
- `0.1.0` and later semantic tags identify a commit containing the matching
  binary URL and SHA-256 checksum in `Package.swift`.

Official binaries are published only by CI.

## License

Packaging and Swift binding: MIT. libsolv: BSD and the permissive notices in
[`Licenses`](Licenses). These notices are also included inside the XCFramework
archive.
