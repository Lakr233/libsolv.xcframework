/// Structured libsolv dependencies; this is not a Debian control-file parser.
public indirect enum Dependency: Sendable, Equatable {
    case named(String)
    case versioned(String, VersionRelation, String)
    case anyOf(Dependency, Dependency)
}
