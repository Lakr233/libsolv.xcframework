import Testing
import Foundation
import LibSolv

private func environment() throws -> (SolverEnvironment, RepositoryID) {
    let solver = try SolverEnvironment(architecture: "arm64")
    return (solver, try solver.addRepository(name: "available"))
}
private func definition(_ name: String, _ version: String = "1", requires: [Dependency] = []) -> PackageDefinition {
    var value = PackageDefinition(name: name, version: version, architecture: "all")
    value.requires = requires
    return value
}

@Test @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
func dependenciesAndOrder() throws {
    let (solver, repo) = try environment()
    let library = try solver.addPackage(definition("library"), to: repo)
    var app = definition("app")
    app.prerequisites = [.named("library")]
    let root = try solver.addPackage(app, to: repo)
    let result = try solver.solve([Job(.install, .package(root))])
    #expect(Set(result.installed.map(\.id)) == [library, root])
    #expect(result.steps.map(\.package.id) == [library, root])
}

@Test(arguments: [true, false]) @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
func alternativesAndVersionedProvides(versioned: Bool) throws {
    let (solver, repo) = try environment()
    var provider = definition("provider")
    provider.provides = [versioned ? .versioned("capability", .equal, "2") : .named("capability")]
    try solver.addPackage(provider, to: repo)
    let app = try solver.addPackage(definition("app", requires: [.anyOf(.named("missing"), .versioned("capability", .greaterThanOrEqual, "2"))]), to: repo)
    if versioned {
        let result = try solver.solve([Job(.install, .package(app))])
        #expect(Set(result.installed.map(\.name)) == ["app", "provider"])
    } else {
        #expect(throws: ResolutionFailure.self) { try solver.solve([Job(.install, .package(app))]) }
    }
}

@Test(arguments: [("1~rc1", "1", -1), ("1:1", "9", 1), ("1.01", "1.1", 0), ("1-2", "1-10", -1), ("1", "1-0", -1)])
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
func debianVersions(lhs: String, rhs: String, expected: Int) throws {
    let (solver, _) = try environment()
    #expect(try solver.compareVersions(lhs, rhs).rawValue == expected)
}

@Test @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
func installedUpdateRemoveAndLock() throws {
    let (solver, repo) = try environment()
    let installed = try solver.addRepository(name: "installed")
    try solver.setInstalledRepository(installed)
    let old = try solver.addPackage(definition("app"), to: installed)
    let new = try solver.addPackage(definition("app", "2"), to: repo)
    #expect(try solver.solve([]).installed.map(\.id) == [old])
    let update = try solver.solve([Job(.update, .all)])
    #expect(update.installed.map(\.id) == [new])
    #expect(update.steps.contains { $0.package.id == new && $0.kind == .upgrade })
    #expect(try solver.solve([Job(.lock, .package(old)), Job(.update, .all)]).installed.map(\.id) == [old])
    #expect(try solver.solve([Job(.remove, .package(old))]).installed.isEmpty)
}

@Test @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
func backtracksAroundConflicts() throws {
    let (solver, repo) = try environment()
    var first = definition("first")
    first.conflicts = [.named("required")]
    try solver.addPackage(first, to: repo)
    try solver.addPackage(definition("second"), to: repo)
    try solver.addPackage(definition("required"), to: repo)
    let root = try solver.addPackage(definition("app", requires: [.anyOf(.named("first"), .named("second")), .named("required")]), to: repo)
    #expect(Set(try solver.solve([Job(.install, .package(root))]).installed.map(\.name)) == ["app", "second", "required"])
}

@Test(arguments: [true, false]) @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
func recommendations(enabled: Bool) throws {
    let (solver, repo) = try environment()
    var app = definition("app")
    app.recommends = [.named("optional")]
    try solver.addPackage(app, to: repo)
    try solver.addPackage(definition("optional"), to: repo)
    var options = SolverOptions()
    options.installRecommendations = enabled
    #expect(try solver.solve([Job(.install, .name("app"))], options: options).installed.count == (enabled ? 2 : 1))
}

@Test @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
func failureDoesNotPoisonNextSolveAndResultsAreCopied() throws {
    let (solver, repo) = try environment()
    let root = try solver.addPackage(definition("app", requires: [.named("later")]), to: repo)
    var messages: [String] = []
    do {
        _ = try solver.solve([Job(.install, .package(root))])
        Issue.record("Missing dependency unexpectedly resolved")
    } catch let failure as ResolutionFailure {
        messages = failure.problems
    }
    #expect(!messages.isEmpty)
    try solver.addPackage(definition("later"), to: repo)
    let first = try solver.solve([Job(.install, .package(root))])
    for i in 0..<1024 { try solver.addPackage(definition("extra-\(i)"), to: repo) }
    #expect(first.installed.count == 2)
    #expect(try solver.solve([Job(.install, .package(root))]).installed == first.installed)
    #expect(messages.joined().contains("later"))
}

@Test @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
func rejectsForeignHandlesAndNULWithoutPartialPackages() throws {
    let (one, repo) = try environment()
    let (two, other) = try environment()
    let id = try one.addPackage(definition("app"), to: repo)
    #expect(throws: InvalidInput.self) { try two.solve([Job(.install, .package(id))]) }
    #expect(throws: InvalidInput.self) { try one.setInstalledRepository(other) }
    #expect(throws: InvalidInput.self) { try one.addPackage(definition("bad", requires: [.named("x\0y")]), to: repo) }
    #expect(throws: ResolutionFailure.self) { try one.solve([Job(.install, .name("bad"))]) }
}

@Test @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
func independentConcurrentEnvironments() async throws {
    try await withThrowingTaskGroup(of: Resolution.self) { group in
        for _ in 0..<32 {
            group.addTask {
                let (solver, repo) = try environment()
                try solver.addPackage(definition("app"), to: repo)
                return try solver.solve([Job(.install, .name("app"))])
            }
        }
        for try await result in group { #expect(result.installed.map(\.name) == ["app"]) }
    }
}

@Test @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
func rawCAPIIsUsable() {
    let pool = pool_create()!
    defer { pool_free(pool) }
    #expect(pool_setdisttype(pool, DISTTYPE_DEB) >= 0)
    #expect(pool_evrcmp_str(pool, "2", "1", EVRCMP_COMPARE) > 0)
}
