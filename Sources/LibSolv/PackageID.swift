import Foundation

public struct PackageID: Hashable, Sendable {
    let owner: UUID
    let raw: Int32
}
