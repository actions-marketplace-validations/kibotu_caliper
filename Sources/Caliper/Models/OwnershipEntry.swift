import Foundation

/// Represents a module ownership entry from the YAML configuration
struct OwnershipEntry: Codable {
    let identifier: String
    let owner: String
    let module: String?
    
    /// Check if this entry matches the given module name
    /// Supports wildcards (* and ?)
    func matches(_ moduleName: String) -> Bool {
        let pattern = identifier
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return identifier.lowercased() == moduleName.lowercased()
        }
        
        let range = NSRange(moduleName.startIndex..., in: moduleName)
        return regex.firstMatch(in: moduleName, options: [], range: range) != nil
    }
}

