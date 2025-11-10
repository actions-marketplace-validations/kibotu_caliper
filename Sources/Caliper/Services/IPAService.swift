import Foundation

/// Service for handling IPA file operations
struct IPAService {
    private let fileManager = FileManager.default
    
    /// Verify that an IPA file exists
    func verifyIPAExists(at path: String) throws {
        guard fileManager.fileExists(atPath: path) else {
            throw CaliperError.invalidIPA
        }
    }
    
    /// Unzip an IPA file to a destination
    func unzip(ipaPath: String, destination: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", ipaPath, "-d", destination]
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            fputs("❌ Failed to unzip IPA: \(errorOutput)\n", stderr)
            throw CaliperError.unzipFailed
        }
    }
    
    /// Determine the unzipped path (auto-generate if needed)
    func determineUnzippedPath(
        ipaPath: String,
        userProvidedPath: String?
    ) -> (path: String, shouldCleanup: Bool) {
        if let userPath = userProvidedPath {
            return (userPath, false)
        }
        
        // Auto-generate path: <ipa-name>_unzipped
        let ipaURL = URL(fileURLWithPath: ipaPath)
        let ipaName = ipaURL.deletingPathExtension().lastPathComponent
        let autoPath = "\(ipaName)_unzipped"
        
        fputs("ℹ️  Using auto-generated unzipped path: \(autoPath)\n", stderr)
        return (autoPath, true)
    }
    
    /// Check if unzipping is needed
    func needsUnzip(at path: String) -> Bool {
        return !fileManager.fileExists(atPath: path)
    }
    
    /// Clean up a temporary directory
    func cleanup(path: String) {
        fputs("\n🧹 Cleaning up temporary directory: \(path)\n", stderr)
        try? fileManager.removeItem(atPath: path)
    }
}

