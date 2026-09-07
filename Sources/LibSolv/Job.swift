public struct Job: Sendable {
    public var action: Action
    public var selection: Selection
    public var forceBest: Bool

    public init(_ action: Action, _ selection: Selection, forceBest: Bool = false) {
        self.action = action
        self.selection = selection
        self.forceBest = forceBest
    }
}
