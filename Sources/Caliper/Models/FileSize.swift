import Foundation

/// Represents size information for an individual file within a module
struct FileSize: Codable {
    let fileName: String
    var size: Int64
    var symbolCount: Int
}
