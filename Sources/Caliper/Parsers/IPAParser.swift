import Foundation

/// Parser for IPA files to extract module information
struct IPAParser {
    private let assetCatalogParser = AssetCatalogParser()
    
    /// Generate a report of IPA contents
    func generateReport(ipaPath: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-v", ipaPath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw CaliperError.unzipFailed
        }
        
        return parseUnzipOutput(output)
    }
    
    /// Build a comprehensive app size report from IPA contents
    func buildAppSizeReport(
        report: String,
        unzippedPath: String,
        moduleMapping: [String: String]
    ) throws -> [String: ModuleSize] {
        var result: [String: ModuleSize] = [:]
        let lines = report.components(separatedBy: .newlines)
        
        let totalLines = lines.count
        var processedLines = 0
        var lastProgressUpdate = 0
        
        fputs("Analyzing \(totalLines) files from IPA...\n", stderr)
        
        for line in lines {
            processedLines += 1
            
            // Print progress every 10%
            let progress = (processedLines * 100) / totalLines
            if progress >= lastProgressUpdate + 10 {
                lastProgressUpdate = progress
                fputs("  Progress: \(progress)% (\(processedLines)/\(totalLines) files)\n", stderr)
            }
            
            try processLine(
                line,
                unzippedPath: unzippedPath,
                moduleMapping: moduleMapping,
                result: &result
            )
        }
        
        // Finalize top files for each module
        for (_, moduleSize) in result {
            moduleSize.finalizeTop()
        }
        
        return result
    }
    
    // MARK: - Private Methods
    
    private func parseUnzipOutput(_ output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        var report: [String] = []
        
        // Skip header (first 3 lines) and footer (last 2 lines)
        let dataLines = lines.dropFirst(3).dropLast(2)
        
        for line in dataLines {
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            if components.count >= 8 {
                let uncompressedSize = components[0]
                let compressedSize = components[2]
                let filePath = components[7...].joined(separator: " ")
                report.append("\(uncompressedSize) \(compressedSize) \(filePath)")
            }
        }
        
        return report.joined(separator: "\n")
    }
    
    private func processLine(
        _ line: String,
        unzippedPath: String,
        moduleMapping: [String: String],
        result: inout [String: ModuleSize]
    ) throws {
        let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count == 3 else { return }
        
        guard let uncompressedSize = Int64(parts[0]),
              let compressedSize = Int64(parts[1]) else {
            return
        }
        
        let filePath = String(parts[2])
        
        // Extract module name from path
        guard let moduleName = extractModuleName(
            from: filePath,
            moduleMapping: moduleMapping
        ) else {
            return
        }
        
        // Initialize module if needed
        if result[moduleName] == nil {
            result[moduleName] = ModuleSize(name: moduleName)
        }
        
        guard let moduleSize = result[moduleName] else { return }
        
        // Categorize and process file
        try categorizeFile(
            filePath: filePath,
            unzippedPath: unzippedPath,
            compressedSize: compressedSize,
            uncompressedSize: uncompressedSize,
            moduleSize: moduleSize,
            containerName: extractContainerName(from: filePath)
        )
        
        // Update total uncompressed size
        moduleSize.proguard += uncompressedSize
    }
    
    private func extractModuleName(from filePath: String, moduleMapping: [String: String]) -> String? {
        // Try framework
        if let frameworkRange = filePath.range(of: ".framework") {
            let beforeFramework = filePath[..<frameworkRange.lowerBound]
            if let lastSlash = beforeFramework.lastIndex(of: "/") {
                let containerName = String(beforeFramework[beforeFramework.index(after: lastSlash)...])
                return moduleMapping[containerName] ?? containerName
            }
        }
        
        // Try bundle
        if let bundleRange = filePath.range(of: ".bundle") {
            let beforeBundle = filePath[..<bundleRange.lowerBound]
            if let lastSlash = beforeBundle.lastIndex(of: "/") {
                let fullBundleName = String(beforeBundle[beforeBundle.index(after: lastSlash)...])
                // Bundle names like "ProfisPartnerCore_ProfisPartnerCore"
                let containerName: String
                if let underscoreIndex = fullBundleName.firstIndex(of: "_") {
                    containerName = String(fullBundleName[..<underscoreIndex])
                } else {
                    containerName = fullBundleName
                }
                return moduleMapping[containerName] ?? containerName
            }
        }
        
        return nil
    }
    
    private func extractContainerName(from filePath: String) -> String? {
        // Extract framework name
        if let frameworkRange = filePath.range(of: ".framework") {
            let beforeFramework = filePath[..<frameworkRange.lowerBound]
            if let lastSlash = beforeFramework.lastIndex(of: "/") {
                return String(beforeFramework[beforeFramework.index(after: lastSlash)...])
            }
        }
        
        // Extract bundle name
        if let bundleRange = filePath.range(of: ".bundle") {
            let beforeBundle = filePath[..<bundleRange.lowerBound]
            if let lastSlash = beforeBundle.lastIndex(of: "/") {
                let fullBundleName = String(beforeBundle[beforeBundle.index(after: lastSlash)...])
                if let underscoreIndex = fullBundleName.firstIndex(of: "_") {
                    return String(fullBundleName[..<underscoreIndex])
                }
                return fullBundleName
            }
        }
        
        return nil
    }
    
    private func categorizeFile(
        filePath: String,
        unzippedPath: String,
        compressedSize: Int64,
        uncompressedSize: Int64,
        moduleSize: ModuleSize,
        containerName: String?
    ) throws {
        let components = filePath.split(separator: ".")
        guard let ext = components.last else { return }
        let fileExtension = String(ext).lowercased()
        
        switch fileExtension {
        case "pdf", "gif", "jpg", "jpeg", "png":
            moduleSize.imageSize += compressedSize
            moduleSize.imageFileSize += uncompressedSize
            moduleSize.addResource(type: fileExtension, size: compressedSize)
            moduleSize.addToTop(file: filePath, size: compressedSize)
            
        case "nib":
            let resourceType = filePath.contains(".storyboardc") ? "storyboardc" : "nib"
            moduleSize.addResource(type: resourceType, size: compressedSize)
            moduleSize.addToTop(file: filePath, size: compressedSize)
            
        case "plist", "mov", "strings", "json":
            moduleSize.addResource(type: fileExtension, size: compressedSize)
            moduleSize.addToTop(file: filePath, size: compressedSize)
            
        case "car":
            let fullPath = "\(unzippedPath)/\(filePath)"
            try? assetCatalogParser.parse(filePath: fullPath, moduleSize: moduleSize)
            
        default:
            // Check if it's the main binary
            if let container = containerName, filePath.hasSuffix(container) {
                moduleSize.binarySize = compressedSize
            }
            moduleSize.addToTop(file: filePath, size: compressedSize)
        }
    }
}

