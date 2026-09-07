public enum VersionRelation: Int32, Sendable {
    case greaterThan = 1, equal = 2, greaterThanOrEqual = 3
    case lessThan = 4, lessThanOrEqual = 6
}
