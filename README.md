# libsolv.xcframework

[libsolv](https://github.com/openSUSE/libsolv) as a self-contained static Apple
XCFramework, with a Swift 6 binding. Binaries are built and tested by GitHub
Actions before publication. No Python, Ruby, Perl, SWIG, Homebrew runtime, or
external helper process is needed by an application.

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
upstream C API; `import CLibSolv` can be used directly by a target depending on
this package's product.

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
the same selections. Options expose uninstall/downgrade permission,
recommendations and strict repository priority. Defaults retain libsolv's
recommendation behavior, forbid implicit uninstall/downgrade and leave strict
repository priority disabled.

A `SolverEnvironment` owns its pool and is deliberately **not Sendable**. Keep
it within one thread or task. Independent environments can solve concurrently.
Package and repository IDs are checked against their owning environment. A
`Resolution`, its packages and diagnostic strings are copied values; they
remain valid after further solves or destruction of the environment. `solve`
does not mutate the installed repository: callers explicitly supply installed
state for subsequent transactions.

## Minimum operating systems

The C library and Swift wrapper target the lowest supported floors below.
Actual floors are extracted from every architecture's object load commands;
arm64 variants can have higher floors than older architectures.

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

For watchOS consumers, restrict device architectures to `arm64_32 arm64`
(or exclude `armv7k` in the application build settings). Some Xcode versions
include `armv7k` by default for a watchOS 5 target; that legacy architecture
is not shipped. visionOS Simulator supports arm64 only.

The test suite uses Swift Testing on macOS 13 / iOS 16 or later. These test
requirements do not raise the library deployment target. Device slices are
compiled and linked in CI; execution tests run on macOS and iOS Simulator.

## What is included

libsolv core with `MULTI_SEMANTICS`, including Debian, RPM, Arch, Haiku and APK
semantics. Repository readers from libsolvext, language bindings, executables
and compression libraries are not built or shipped. Supply package definitions
programmatically, or use the upstream core API for its native `.solv` format.

This package wraps **libsolv**, not APT. Repository priorities are libsolv
priorities, not APT pin values. `obsoletes` is not Debian `Replaces`, and ordered
transaction steps are not a dpkg unpack/configure plan. Distribution-specific
metadata parsing, policy and execution belong in the consumer.

Known upstream behavior: with Debian distribution selected, libsolv 0.7.39's
`EVRCMP_COMPARE` orders `1` before `1-0`; dpkg considers them equal. The binding
preserves libsolv's comparison behavior, and tests pin this distinction. Do not
assume selecting `.debian` alone establishes complete APT/dpkg equivalence.

## Build and test

Install Xcode, CMake and Ninja, then:

```sh
./Script/build.sh
python3 Script/verify-binary.py
./Script/test.sh
./Script/test-simulator.sh
swift test --sanitize address
```

Sources are fetched at the full commit in `Upstream.versions`. Only the private
checkout under ignored `build/src` is reset by fetching. `Vendor/` contains the
small Apple compatibility patch and the umbrella header. The patch prevents
new SDKs from introducing `strchrnul`, unavailable on our older deployment
targets. No solver algorithms are modified.

`BinaryTarget/CLibSolv.xcframework` overrides the remote binary for local tests.
After removing it, run `swift package clean` and `swift package purge-cache`
before switching back to a remote artifact. `Package.swift` is generated;
change `Package.swift.template` instead.

To rebuild only one platform group:

```sh
./Script/build-platform.sh ios ./build/dest
```

## Releases

The **Build libsolv** workflow supports pinned or latest stable upstream,
explicit package versions, and build-only runs. A daily check builds new
upstream versions. An incompatible patch or a failed test stops publication.
CI pins Xcode 26.3 and records its build number in `BUILD-INFO.txt`.

- `upstream.<commit12>.<revision>` stores `CLibSolv.xcframework.zip` and build provenance.
- `0.1.0` and later semantic tags identify a commit containing the matching
  binary URL and SHA-256 checksum in `Package.swift`.

All ten destinations build both Swift products before release, alongside
macOS tests, Address Sanitizer, iOS Simulator tests, architecture/OS-floor
checks and binary-path checks. A fresh remote consumer downloads and executes
the released package. Official binaries are published only by CI.

If the default branch advances during a build, publishing stops; rerun on the
new commit. A failure after publishing a storage release never overwrites its
asset: rerun to allocate a new storage revision and the next unused package tag.

## License

Packaging and Swift binding: MIT. libsolv: BSD and the permissive notices in
[`Licenses`](Licenses). These notices are also included inside the XCFramework
archive. Test inputs are generated here; no APT source or GPL test fixtures are
vendored. Build organization follows
[Lakr233/libarchive.xcframework](https://github.com/Lakr233/libarchive.xcframework).
