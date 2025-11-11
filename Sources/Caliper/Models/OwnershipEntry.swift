import Foundation

/// Represents a module ownership entry from the YAML configuration
struct OwnershipEntry: Codable {
    let identifier: String
    let owner: String
    let `internal`: Bool?
    
    /// Matches module name with wildcard support (* and ?)
    func matches(_ moduleName: String) -> Bool {
        let pattern = identifier
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")
        
        guard let regex = try? NSRegularExpression(pattern: "^\(pattern)$", options: [.caseInsensitive]) else {
            return identifier.caseInsensitiveCompare(moduleName) == .orderedSame
        }
        
        let range = NSRange(moduleName.startIndex..., in: moduleName)
        return regex.firstMatch(in: moduleName, options: [], range: range) != nil
    }
}
