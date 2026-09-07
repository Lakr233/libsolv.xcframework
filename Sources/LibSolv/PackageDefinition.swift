public struct PackageDefinition: Sendable {
    public var name: String
    public var version: String
    public var architecture: String
    public var requires: [Dependency] = []
    public var prerequisites: [Dependency] = []
    public var provides: [Dependency] = []
    public var conflicts: [Dependency] = []
    /// libsolv obsoletes semantics, not Debian Replaces semantics.
    public var obsoletes: [Dependency] = []
    public var recommends: [Dependency] = []
    public var suggests: [Dependency] = []

    public init(name: String, version: String, architecture: String) {
        self.name = name
        self.version = version
        self.architecture = architecture
    }
}
