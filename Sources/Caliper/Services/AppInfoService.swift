import Foundation

/// Service for extracting app information from IPA
struct AppInfoService {
    /// Extract app info from the unzipped IPA directory
    func extractAppInfo(from unzippedPath: String) throws -> AppInfo? {
        // Find the .app directory
        guard let appDirectory = findAppDirectory(in: unzippedPath) else {
            ProgressReporter.warning("Could not find .app directory in IPA")
            return nil
        }
        
        // Extract the app module name from the .app directory name
        let appModuleName = extractAppModuleName(from: appDirectory)
        
        // Read Info.plist
        let infoPlistPath = "\(appDirectory)/Info.plist"
        guard FileManager.default.fileExists(atPath: infoPlistPath) else {
            ProgressReporter.warning("Info.plist not found at: \(infoPlistPath)")
            return nil
        }
        
        return try parseInfoPlist(at: infoPlistPath, appModuleName: appModuleName)
    }
    
    // MARK: - Private Methods
    
    private func findAppDirectory(in unzippedPath: String) -> String? {
        let payloadPath = "\(unzippedPath)/Payload"
        
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: payloadPath) else {
            return nil
        }
        
        return contents.first { $0.hasSuffix(".app") }.map { "\(payloadPath)/\($0)" }
    }
    
    private func extractAppModuleName(from appDirectory: String) -> String? {
        // Extract the .app name from the path
        // e.g., "/path/to/Payload/ProfisPartner.app" -> "ProfisPartner"
        let url = URL(fileURLWithPath: appDirectory)
        let appNameWithExtension = url.lastPathComponent  // "ProfisPartner.app"
        
        // Remove the .app extension
        if appNameWithExtension.hasSuffix(".app") {
            return String(appNameWithExtension.dropLast(4))  // Remove ".app"
        }
        
        return nil
    }
    
    private func parseInfoPlist(at path: String, appModuleName: String?) throws -> AppInfo? {
        let url = URL(fileURLWithPath: path)
        
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            ProgressReporter.warning("Failed to parse Info.plist")
            return nil
        }
        
        let appName = plist["CFBundleDisplayName"] as? String 
            ?? plist["CFBundleName"] as? String
        let version = plist["CFBundleShortVersionString"] as? String
        let buildNumber = plist["CFBundleVersion"] as? String
        let bundleIdentifier = plist["CFBundleIdentifier"] as? String
        
        return AppInfo(
            appName: appName,
            appModuleName: appModuleName,
            version: version,
            buildNumber: buildNumber,
            bundleIdentifier: bundleIdentifier
        )
    }
}
