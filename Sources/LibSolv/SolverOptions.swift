public struct SolverOptions: Sendable {
    public var allowUninstall = false
    public var allowDowngrade = false
    public var installRecommendations = true
    public var strictRepositoryPriority = false
    public init() {}
}
