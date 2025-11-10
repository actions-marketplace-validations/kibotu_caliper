import Foundation
import Yams

/// Service for handling package name mapping configuration
struct PackageMappingService {
    
    /// Load package name mappings from a YAML file
    /// - Parameter path: Path to the mapping YAML file
    /// - Returns: Array of PackageNameMapping entries
    /// - Throws: CaliperError if parsing fails
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
    /// - Parameter mappings: Array of PackageNameMapping entries
    /// - Returns: Dictionary mapping module names to package identities
    func buildMappingDictionary(from mappings: [PackageNameMapping]) -> [String: String] {
        var dictionary: [String: String] = [:]
        
        for mapping in mappings {
            dictionary[mapping.moduleName] = mapping.packageIdentity
        }
        
        return dictionary
    }
}

