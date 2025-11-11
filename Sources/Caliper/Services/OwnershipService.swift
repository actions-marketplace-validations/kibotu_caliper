import Foundation
import Yams

/// Service for handling module ownership configuration
struct OwnershipService {
    /// Load ownership entries from a YAML file
    func loadOwnershipFile(from path: String) throws -> [OwnershipEntry] {
        let yamlString = try String(contentsOfFile: path, encoding: .utf8)
        return try YAMLDecoder().decode([OwnershipEntry].self, from: yamlString)
    }
    
    /// Find the ownership entry for a given module name
    func findEntry(for moduleName: String, in entries: [OwnershipEntry]) -> OwnershipEntry? {
        entries.first { $0.matches(moduleName) }
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
