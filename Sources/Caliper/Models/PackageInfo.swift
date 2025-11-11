import Foundation

/// Represents a package pin entry from Package.resolved
struct PackagePin: Codable {
    let identity: String
    let kind: String
    let location: String
    let state: PackageState
}

/// Represents the state of a package including version
struct PackageState: Codable {
    let version: String?
    let revision: String?
    let branch: String?
}

/// Root structure of Package.resolved
struct PackageResolved: Codable {
    let originHash: String?
    let pins: [PackagePin]
    let version: Int
}
