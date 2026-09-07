public struct TransactionStep: Sendable, Equatable {
    public let kind: Kind
    public let package: ResolvedPackage
}
