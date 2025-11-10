import Foundation

/// Represents a package name mapping entry
struct PackageNameMapping: Codable {
    /// The module name as it appears in the LinkMap or binary
    let moduleName: String
    
    /// The package identity as it appears in Package.resolved (e.g., "ext.adjust_signature_sdk")
    let packageIdentity: String
}

