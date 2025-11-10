import Foundation
import Yams

/// Service for handling module ownership configuration
struct OwnershipService {
    
    /// Load ownership entries from a YAML file
    func loadOwnershipFile(from path: String) throws -> [OwnershipEntry] {
        let yamlString = try String(contentsOfFile: path, encoding: .utf8)
        let entries = try YAMLDecoder().decode([OwnershipEntry].self, from: yamlString)
        return entries
    }
    
    /// Build module mapping from ownership entries
    func buildModuleMapping(from entries: [OwnershipEntry]) -> [String: String] {
        var mapping: [String: String] = [:]
        
        for entry in entries {
            if let moduleName = entry.module {
                // Extract framework name from identifier
                let frameworkName = entry.identifier.replacingOccurrences(of: "*", with: "")
                if !frameworkName.isEmpty {
                    mapping[frameworkName] = moduleName
                }
            }
        }
        
        return mapping
    }
    
    /// Find the owner for a given module name
    func findOwner(for moduleName: String, in entries: [OwnershipEntry]) -> String? {
        for entry in entries {
            if entry.matches(moduleName) {
                return entry.owner
            }
        }
        return nil
    }
    
    /// Assign owners to modules in the app size report
    func assignOwners(
        to modules: [String: ModuleSize],
        using entries: [OwnershipEntry]
    ) {
        for (moduleName, moduleSize) in modules {
            if let owner = findOwner(for: moduleName, in: entries) {
                moduleSize.owner = owner
            }
        }
    }
    
    /// Group modules by owner
    func groupModulesByOwner(
        _ modules: [String: ModuleSize]
    ) -> [String: [String: ModuleSize]] {
        var grouped: [String: [String: ModuleSize]] = [:]
        
        for (moduleName, moduleSize) in modules {
            let owner = moduleSize.owner ?? "others"
            if grouped[owner] == nil {
                grouped[owner] = [:]
            }
            grouped[owner]?[moduleName] = moduleSize
        }
        
        return grouped
    }
}

