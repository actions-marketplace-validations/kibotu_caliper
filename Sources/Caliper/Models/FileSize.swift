import Foundation

/// Represents size information for an individual file within a module
struct FileSize: Codable {
    let fileName: String
    var size: Int64
    var symbolCount: Int
    
    init(fileName: String, size: Int64 = 0, symbolCount: Int = 0) {
        self.fileName = fileName
        self.size = size
        self.symbolCount = symbolCount
    }
}

