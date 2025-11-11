import Foundation

/// Represents size information for a module/framework
/// Class is used for reference semantics - allows mutation during incremental parsing
final class ModuleSize: Codable, @unchecked Sendable {
    let name: String
    var owner: String?
    var `internal`: Bool?
    var version: String?
    var binarySize: Int64 = 0
    var imageSize: Int64 = 0
    var imageFileSize: Int64 = 0
    var proguard: Int64 = 0
    var resources: [String: Resource] = [:]
    var top: [String: Int64] = [:]
    var files: [FileSize] = []
    
    // Internal dictionary for building files during parsing
    private var filesDict: [String: FileSize] = [:]
    
    init(name: String) {
        self.name = name
    }
    
    /// Add a resource to this module
    func addResource(type: String, size: Int64) {
        resources[type, default: Resource()].size += size
        resources[type, default: Resource()].count += 1
    }
    
    /// Track a file in the top files list
    func addToTop(file: String, size: Int64) {
        top[file] = size
    }
    
    /// Finalize the top files list (sort by size)
    func finalizeTop() {
        top = Dictionary(uniqueKeysWithValues: top.sorted { $0.value > $1.value })
    }
    
    /// Add file size information
    func addFileSize(fileName: String, size: Int64) {
        var fileSize = filesDict[fileName] ?? FileSize(fileName: fileName, size: 0, symbolCount: 0)
        fileSize.size += size
        fileSize.symbolCount += 1
        filesDict[fileName] = fileSize
    }
    
    /// Finalize the files list (convert to sorted array by size, largest first)
    /// Filters out the module-level entry (unattributed code)
    func finalizeFiles() {
        files = filesDict.values
            .filter { $0.fileName != name }
            .sorted { $0.size > $1.size }
        filesDict.removeAll()
    }
    
    enum CodingKeys: String, CodingKey {
        case name, owner, `internal`, version, binarySize, imageSize, imageFileSize, proguard, resources, top, files
    }
}
