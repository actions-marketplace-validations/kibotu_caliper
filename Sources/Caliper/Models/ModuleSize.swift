import Foundation

/// Represents size information for a module/framework
final class ModuleSize: Codable {
    let name: String
    var owner: String?
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
        self.owner = nil
        self.version = nil
    }
    
    /// Add a resource to this module
    func addResource(type: String, size: Int64) {
        if resources[type] == nil {
            resources[type] = Resource()
        }
        resources[type]?.size += size
        resources[type]?.count += 1
    }
    
    /// Track a file in the top files list
    func addToTop(file: String, size: Int64) {
        top[file] = size
    }
    
    /// Finalize the top files list (sort and keep top 30)
    func finalizeTop() {
        let sorted = top.sorted { $0.value > $1.value }.prefix(30)
        top = [:]
        for (key, value) in sorted {
            top[key] = value
        }
    }
    
    /// Add file size information
    func addFileSize(fileName: String, size: Int64) {
        if filesDict[fileName] == nil {
            filesDict[fileName] = FileSize(fileName: fileName)
        }
        filesDict[fileName]?.size += size
        filesDict[fileName]?.symbolCount += 1
    }
    
    /// Finalize the files list (convert to sorted array by size, largest first)
    func finalizeFiles() {
        files = filesDict.values.sorted { $0.size > $1.size }
        // Clear the internal dictionary to save memory
        filesDict.removeAll()
    }
    
    enum CodingKeys: String, CodingKey {
        case name, owner, version, binarySize, imageSize, imageFileSize, proguard, resources, top, files
    }
}

