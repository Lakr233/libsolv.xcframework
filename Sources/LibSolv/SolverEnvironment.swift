import CLibSolv
import Foundation

/// Owns one mutable C pool. Confine each environment to one thread/task.
/// Separate environments can be used concurrently; no global solver state is shared.
public final class SolverEnvironment {
    private let owner = UUID()
    private let pool: UnsafeMutablePointer<Pool>

    public init(distribution: Distribution = .debian, architecture: String) throws {
        try Self.validate(architecture)
        pool = pool_create()
        pool_setdisttype(pool, distribution.rawValue)
        pool_setarch(pool, architecture)
    }

    deinit { pool_free(pool) }

    public func addRepository(name: String, priority: Int32 = 0, subpriority: Int32 = 0) throws -> RepositoryID {
        try Self.validate(name)
        let repo = repo_create(pool, name)!
        repo.pointee.priority = priority
        repo.pointee.subpriority = subpriority
        return RepositoryID(owner: owner, raw: repo.pointee.repoid)
    }

    public func setInstalledRepository(_ repository: RepositoryID) throws {
        pool_set_installed(pool, try repo(repository))
    }

    @discardableResult
    public func addPackage(_ definition: PackageDefinition, to repository: RepositoryID) throws -> PackageID {
        let repositoryPointer = try repo(repository)
        try Self.validate(definition.name)
        try Self.validate(definition.version)
        try Self.validate(definition.architecture)
        // Validate before adding a solvable so an error never leaves a partial package.
        let groups = [definition.requires, definition.prerequisites, definition.provides,
                      definition.conflicts, definition.obsoletes, definition.recommends, definition.suggests]
        let dependencies = try groups.map { try $0.map(dependencyID) }
        pool_freewhatprovides(pool)
        let id = repo_add_solvable(repositoryPointer)
        let solvable = pool_id2solvable(pool, id)!
        solvable.pointee.name = pool_str2id(pool, definition.name, 1)
        solvable.pointee.evr = pool_str2id(pool, definition.version, 1)
        solvable.pointee.arch = pool_str2id(pool, definition.architecture, 1)
        solvable_add_deparray(solvable, Id(SOLVABLE_PROVIDES.rawValue), solvable_selfprovidedep(solvable), 0)
        let keys = [SOLVABLE_REQUIRES, SOLVABLE_REQUIRES, SOLVABLE_PROVIDES,
                    SOLVABLE_CONFLICTS, SOLVABLE_OBSOLETES, SOLVABLE_RECOMMENDS, SOLVABLE_SUGGESTS]
        for (index, values) in dependencies.enumerated() {
            for dependency in values {
                solvable_add_deparray(solvable, Id(keys[index].rawValue), dependency,
                                     index == 1 ? Id(SOLVABLE_PREREQMARKER.rawValue) : 0)
            }
        }
        return PackageID(owner: owner, raw: id)
    }

    /// Uses libsolv EVRCMP_COMPARE verbatim, including its absent-release ordering.
    public func compareVersions(_ lhs: String, _ rhs: String) throws -> ComparisonResult {
        try Self.validate(lhs)
        try Self.validate(rhs)
        let result = pool_evrcmp_str(pool, lhs, rhs, EVRCMP_COMPARE)
        return result < 0 ? .orderedAscending : result > 0 ? .orderedDescending : .orderedSame
    }

    public func solve(_ jobs: [Job], options: SolverOptions = .init()) throws -> Resolution {
        var queue = Queue()
        queue_init(&queue)
        defer { queue_free(&queue) }
        for job in jobs {
            let selector: Int32
            let value: Id
            switch job.selection {
            case let .package(id):
                guard id.owner == owner else { throw InvalidInput(description: "Package belongs to another environment") }
                selector = SOLVER_SOLVABLE
                value = id.raw
            case let .name(name):
                try Self.validate(name)
                selector = SOLVER_SOLVABLE_NAME
                value = pool_str2id(pool, name, 1)
            case let .providing(dependency):
                selector = SOLVER_SOLVABLE_PROVIDES
                value = try dependencyID(dependency)
            case .all:
                selector = SOLVER_SOLVABLE_ALL
                value = 0
            }
            queue_push2(&queue, job.action.rawValue | selector | (job.forceBest ? SOLVER_FORCEBEST : 0), value)
        }
        pool_createwhatprovides(pool)
        let solver = solver_create(pool)!
        defer { solver_free(solver) }
        solver_set_flag(solver, SOLVER_FLAG_ALLOW_UNINSTALL, options.allowUninstall ? 1 : 0)
        solver_set_flag(solver, SOLVER_FLAG_ALLOW_DOWNGRADE, options.allowDowngrade ? 1 : 0)
        solver_set_flag(solver, SOLVER_FLAG_IGNORE_RECOMMENDED, options.installRecommendations ? 0 : 1)
        solver_set_flag(solver, SOLVER_FLAG_STRICT_REPO_PRIORITY, options.strictRepositoryPriority ? 1 : 0)
        guard solver_solve(solver, &queue) == 0 else {
            var problems: [String] = []
            var problem: Id = 0
            while true {
                problem = solver_next_problem(solver, problem)
                if problem == 0 { break }
                problems.append(String(cString: solver_problem2str(solver, problem)))
            }
            throw ResolutionFailure(problems: problems)
        }
        let transaction = solver_create_transaction(solver)!
        defer { transaction_free(transaction) }
        transaction_order(transaction, 0)
        var steps: [TransactionStep] = []
        let values = transaction.pointee.steps
        for index in 0..<Int(values.count) {
            let id = values.elements[index]
            let active: Int32 = pool_id2solvable(pool, id)!.pointee.repo == pool.pointee.installed ? 0 : SOLVER_TRANSACTION_SHOW_ACTIVE
            let raw = transaction_type(transaction, id, active | SOLVER_TRANSACTION_SHOW_ALL | SOLVER_TRANSACTION_SHOW_OBSOLETES)
            if raw == SOLVER_TRANSACTION_IGNORE { continue }
            guard let kind = TransactionStep.Kind(rawValue: raw) else {
                throw InvalidInput(description: "Unsupported libsolv transaction type: \(raw)")
            }
            steps.append(TransactionStep(kind: kind, package: package(id)))
        }
        var installed = Queue()
        queue_init(&installed)
        defer { queue_free(&installed) }
        transaction_installedresult(transaction, &installed)
        return Resolution(steps: steps, installed: (0..<Int(installed.count)).map { package(installed.elements[$0]) })
    }

    private func package(_ id: Id) -> ResolvedPackage {
        let value = pool_id2solvable(pool, id)!.pointee
        return ResolvedPackage(id: PackageID(owner: owner, raw: id),
                               repository: RepositoryID(owner: owner, raw: value.repo.pointee.repoid),
                               name: String(cString: pool_id2str(pool, value.name)),
                               version: String(cString: pool_id2str(pool, value.evr)),
                               architecture: String(cString: pool_id2str(pool, value.arch)))
    }

    private func repo(_ id: RepositoryID) throws -> UnsafeMutablePointer<Repo> {
        guard id.owner == owner else { throw InvalidInput(description: "Repository belongs to another environment") }
        return pool_id2repo(pool, id.raw)!
    }

    private func dependencyID(_ dependency: Dependency) throws -> Id {
        switch dependency {
        case let .named(name):
            try Self.validate(name)
            return pool_str2id(pool, name, 1)
        case let .versioned(name, relation, version):
            try Self.validate(name)
            try Self.validate(version)
            return pool_rel2id(pool, pool_str2id(pool, name, 1), pool_str2id(pool, version, 1), relation.rawValue, 1)
        case let .anyOf(lhs, rhs):
            return pool_rel2id(pool, try dependencyID(lhs), try dependencyID(rhs), REL_OR, 1)
        }
    }

    private static func validate(_ value: String) throws {
        guard !value.isEmpty, !value.utf8.contains(0) else {
            throw InvalidInput(description: "Names, versions and architectures must be nonempty and contain no NUL")
        }
    }
}
