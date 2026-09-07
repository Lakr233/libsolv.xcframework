public enum Selection: Sendable {
    case package(PackageID)
    case name(String)
    case providing(Dependency)
    case all
}
