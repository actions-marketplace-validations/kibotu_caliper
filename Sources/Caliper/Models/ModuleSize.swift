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
    var files: [String: FileSize] = [:]
    
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
        if files[fileName] == nil {
            files[fileName] = FileSize(fileName: fileName)
        }
        files[fileName]?.size += size
        files[fileName]?.symbolCount += 1
    }
    
    /// Finalize the files list (sort and keep all files - no limit for now)
    func finalizeFiles() {
        // Keep all files for now - could limit to top N if needed
        // let sorted = files.sorted { $0.value.size > $1.value.size }.prefix(200)
        // files = [:]
        // for (key, value) in sorted {
        //     files[key] = value
        // }
    }
    
    enum CodingKeys: String, CodingKey {
        case name, owner, version, binarySize, imageSize, imageFileSize, proguard, resources, top, files
    }
}

