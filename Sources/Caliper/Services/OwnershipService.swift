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
    
    /// Automatically tag the app module as internal with owner 'App'
    /// The app module is identified from the .app directory name in the IPA
    func tagAppModule(
        in modules: [String: ModuleSize],
        appInfo: AppInfo?
    ) {
        // Get the app module name from the .app directory
        guard let appModuleName = appInfo?.appModuleName else {
            return
        }
        
        // Check if this module exists in our modules list
        guard let appModule = modules[appModuleName] else {
            ProgressReporter.warning("App module '\(appModuleName)' not found in modules list")
            return
        }
        
        var changes: [String] = []
        
        // Only set if not already set by ownership file
        if appModule.owner == nil {
            appModule.owner = "App"
            changes.append("owner='App'")
        }
        
        if appModule.internal == nil {
            appModule.internal = true
            changes.append("internal=true")
        }
        
        if !changes.isEmpty {
            ProgressReporter.message("Tagged app module '\(appModuleName)' with \(changes.joined(separator: ", "))")
        }
    }
    
}
