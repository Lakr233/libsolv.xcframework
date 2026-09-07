/// Copied values remain valid after the environment is mutated or released.
public struct Resolution: Sendable {
    /// libsolv's transaction order; not a dpkg unpack/configure execution plan.
    public let steps: [TransactionStep]
    public let installed: [ResolvedPackage]
}
