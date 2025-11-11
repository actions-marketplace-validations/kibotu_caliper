import Foundation
import Yams

/// Service for handling package name mapping configuration
struct PackageMappingService {
    /// Load package name mappings from a YAML file
    func loadMappingFile(from path: String) throws -> [PackageNameMapping] {
        guard FileManager.default.fileExists(atPath: path) else {
            throw CaliperError.fileNotFound(path)
        }
        
        let yamlString = try String(contentsOfFile: path, encoding: .utf8)
        let mappings = try YAMLDecoder().decode([PackageNameMapping].self, from: yamlString)
        
        ProgressReporter.success("Loaded \(mappings.count) package name mappings")
        return mappings
    }
    
    /// Build a dictionary from module names to package identities
    func buildMappingDictionary(from mappings: [PackageNameMapping]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: mappings.map { ($0.moduleName, $0.packageIdentity) })
    }
}
