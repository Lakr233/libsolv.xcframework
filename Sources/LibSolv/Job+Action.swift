extension Job {
    public enum Action: Int32, Sendable {
        case install = 0x0100, remove = 0x0200, update = 0x0300, lock = 0x0600
    }
}
