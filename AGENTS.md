# libsolv.xcframework

Independent Apple binary packaging and a thin, typed Swift wrapper. Do not add
Chromatic-specific APT policy or privileged execution here.

- Pin upstream with a full commit in Upstream.versions; fetch into ignored build/src.
- Package.swift is generated. Edit Package.swift.template, Swift tools 6.0 and Swift 6 mode.
- CLibSolv is the C module; LibSolv is Swift. Do not introduce case-only name differences.
- Build only core libsolv; no ext, tools, language bindings, compression libraries or host runtime dependencies.
- Every public handle must retain owner identity or be copied into a value. Never retain a Solvable pointer across additions: pool arrays reallocate.
- SolverEnvironment is non-Sendable. No unchecked concurrency conformance.
- Test actual solver results and ownership lifetimes. Do not claim APT equivalence.
- Preserve upstream BSD and embedded permissive notices in both the repository and zip.
- Every published binary must come from the Build libsolv workflow. Never upload a local zip as a release artifact.
- Validate all architecture slices, platform minimums and consumer linking before release.
- Build outputs stay in build/ and BinaryTarget/. Xcode DerivedData belongs under ~/Library/Caches.
- Use set -euo pipefail in new scripts; cd to the root and check .root before mutations.
- Fetch may reset only our disposable build/src/libsolv checkout. Never reset the packaging repository.

- One enum, struct or class per Swift file. Nested types belong in separate extension files.
