public struct ResolvedPackage: Sendable, Equatable {
    public let id: PackageID
    public let repository: RepositoryID
    public let name: String
    public let version: String
    public let architecture: String
}
