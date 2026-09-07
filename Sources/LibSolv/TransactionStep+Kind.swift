extension TransactionStep {
    public enum Kind: Int32, Sendable {
        case erase = 0x10, reinstalled = 0x11, downgraded = 0x12, changed = 0x13
        case upgraded = 0x14, obsoleted = 0x15
        case install = 0x20, reinstall = 0x21, downgrade = 0x22, change = 0x23
        case upgrade = 0x24, obsoletes = 0x25, multiinstall = 0x30, multireinstall = 0x31
    }
}
