import Foundation

/// Represents app information extracted from Info.plist
struct AppInfo: Codable {
    let appName: String?
    let version: String?
    let buildNumber: String?
    let bundleIdentifier: String?
    
    enum CodingKeys: String, CodingKey {
        case appName, version, buildNumber, bundleIdentifier
    }
    
    /// Computed property for displaying version info
    var versionString: String? {
        if let version, let build = buildNumber {
            return "\(version) (\(build))"
        }
        return version ?? buildNumber
    }
}
