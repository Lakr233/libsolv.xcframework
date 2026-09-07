import Foundation

public struct RepositoryID: Hashable, Sendable {
    let owner: UUID
    let raw: Int32
}
