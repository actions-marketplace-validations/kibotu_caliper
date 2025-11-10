import Foundation

/// Parser for Package.resolved files to extract Swift package version information
struct PackageResolvedParser {
    
    /// Parse a Package.resolved file and return a mapping of module names to versions
    /// - Parameter path: Path to the Package.resolved file
    /// - Returns: Dictionary mapping package identities to version strings
    /// - Throws: CaliperError if parsing fails
    func parse(path: String) throws -> [String: String] {
        let url = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw CaliperError.fileNotFound(path)
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        
        do {
            let packageResolved = try decoder.decode(PackageResolved.self, from: data)
            
            var versionMapping: [String: String] = [:]
            
            for pin in packageResolved.pins {
                // Extract the package name from identity
                // Identity format is typically: "owner.PackageName" or "ext.PackageName"
                let packageName = extractPackageName(from: pin.identity)
                
                // Determine version string
                let versionString = extractVersionString(from: pin.state)
                
                // Store both the full identity and extracted name
                versionMapping[pin.identity] = versionString
                versionMapping[packageName] = versionString
            }
            
            ProgressReporter.success("Loaded version info for \(packageResolved.pins.count) packages")
            
            return versionMapping
            
        } catch {
            throw CaliperError.parseError("Failed to parse Package.resolved: \(error.localizedDescription)")
        }
    }
    
    /// Extract the package name from the identity
    /// - Parameter identity: The full identity (e.g., "ext.firebaseiossdk")
    /// - Returns: The extracted package name (e.g., "firebaseiossdk")
    private func extractPackageName(from identity: String) -> String {
        let components = identity.split(separator: ".")
        if components.count > 1 {
            // Return everything after the first dot
            return components.dropFirst().joined(separator: ".")
        }
        return identity
    }
    
    /// Extract a version string from package state
    /// - Parameter state: The package state containing version/revision/branch info
    /// - Returns: A formatted version string
    private func extractVersionString(from state: PackageState) -> String {
        if let version = state.version {
            return version
        } else if let revision = state.revision {
            // Return shortened revision (first 7 characters)
            let shortRevision = String(revision.prefix(7))
            return "rev:\(shortRevision)"
        } else if let branch = state.branch {
            return "branch:\(branch)"
        }
        return "unknown"
    }
}

