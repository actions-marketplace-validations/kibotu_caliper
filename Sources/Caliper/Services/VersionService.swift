import Foundation

/// Service to manage package version information from Package.resolved
struct VersionService {
    
    /// Assign versions to modules based on package resolved data
    /// - Parameters:
    ///   - modules: Dictionary of module names to ModuleSize objects
    ///   - versionMapping: Dictionary mapping package names to version strings
    func assignVersions(to modules: [String: ModuleSize], using versionMapping: [String: String]) {
        for (moduleName, moduleSize) in modules {
            // Try exact match first
            if let version = versionMapping[moduleName] {
                moduleSize.version = version
                continue
            }
            
            // Try case-insensitive match
            let lowercasedName = moduleName.lowercased()
            for (packageName, version) in versionMapping {
                if packageName.lowercased() == lowercasedName {
                    moduleSize.version = version
                    break
                }
            }
            
            // Try partial match (e.g., module "FirebaseAnalytics" matches package "firebaseiossdk")
            if moduleSize.version == nil {
                for (packageName, version) in versionMapping {
                    if lowercasedName.contains(packageName.lowercased()) || 
                       packageName.lowercased().contains(lowercasedName) {
                        moduleSize.version = version
                        break
                    }
                }
            }
        }
    }
}

