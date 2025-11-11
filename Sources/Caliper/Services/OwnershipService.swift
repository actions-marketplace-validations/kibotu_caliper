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
    /// Note: Returns empty dictionary since we don't want to rename modules,
    /// only assign owners. The assignOwners() function handles ownership assignment
    /// using wildcard pattern matching while preserving actual module names.
    func buildModuleMapping(from entries: [OwnershipEntry]) -> [String: String] {
        // Return empty mapping - we don't want to rename modules,
        // we only want to assign owners via assignOwners()
        return [:]
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
    
    /// Find the ownership entry for a given module name
    func findEntry(for moduleName: String, in entries: [OwnershipEntry]) -> OwnershipEntry? {
        for entry in entries {
            if entry.matches(moduleName) {
                return entry
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
            if let entry = findEntry(for: moduleName, in: entries) {
                moduleSize.owner = entry.owner
                moduleSize.internal = entry.`internal`
            }
        }
    }
}

