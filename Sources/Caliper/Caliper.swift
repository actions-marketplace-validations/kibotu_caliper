import Foundation
import ArgumentParser
import Yams

@main
struct Caliper: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Measure binary and bundle sizes for Swift packages in an IPA",
        version: "1.0.0"
    )
    
    @Option(name: .long, help: "Path to the IPA file")
    var ipaPath: String
    
    @Option(name: .long, help: "Path to the unzipped IPA directory (optional - will auto-generate if not provided)")
    var unzippedPath: String?
    
    @Option(name: .long, help: "Optional path to LinkMap file for accurate binary sizes")
    var linkMapPath: String?
    
    @Option(name: .long, help: "YAML file containing module ownership configuration")
    var ownershipFile: String?
    
    @Option(name: .long, help: "Filter output to show only modules owned by specific owner")
    var filterOwner: String?
    
    @Option(name: .shortAndLong, help: "Output file path for JSON report (default: stdout). HTML report will be auto-generated with .html extension")
    var output: String?
    
    @Flag(name: .long, help: "Group output by owner")
    var groupByOwner: Bool = false
    
    func run() throws {
        // Verify IPA file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: ipaPath) else {
            fputs("❌ Error: IPA file not found: \(ipaPath)\n", stderr)
            throw CaliperError.invalidIPA
        }
        
        // Determine unzipped path (auto-generate if not provided)
        let shouldCleanup: Bool
        let actualUnzippedPath: String
        
        if let userProvidedPath = unzippedPath {
            actualUnzippedPath = userProvidedPath
            shouldCleanup = false // User provided path, don't auto-cleanup
        } else {
            // Auto-generate path: <ipa-name>_unzipped
            let ipaURL = URL(fileURLWithPath: ipaPath)
            let ipaName = ipaURL.deletingPathExtension().lastPathComponent
            actualUnzippedPath = "\(ipaName)_unzipped"
            shouldCleanup = true // Always cleanup auto-generated directories
            
            fputs("ℹ️  Using auto-generated unzipped path: \(actualUnzippedPath)\n", stderr)
        }
        
        // Unzip IPA if needed
        let needsUnzip = !fileManager.fileExists(atPath: actualUnzippedPath)
        if needsUnzip {
            fputs("\n📦 Unzipping IPA to: \(actualUnzippedPath)\n", stderr)
            try unzipIPA(ipaPath: ipaPath, destination: actualUnzippedPath)
            fputs("✅ IPA unzipped successfully\n", stderr)
        } else {
            fputs("ℹ️  Using existing unzipped directory: \(actualUnzippedPath)\n", stderr)
        }
        
        // Setup cleanup defer early in main function scope
        defer {
            if shouldCleanup && needsUnzip {
                fputs("\n🧹 Cleaning up temporary directory: \(actualUnzippedPath)\n", stderr)
                try? fileManager.removeItem(atPath: actualUnzippedPath)
            }
        }
        
        // Load ownership file if provided
        var ownershipEntries: [OwnershipEntry] = []
        var moduleMapping: [String: String] = [:]
        
        if let ownershipPath = ownershipFile {
            ownershipEntries = try loadOwnershipFile(from: ownershipPath)
            
            // Build module mappings from ownership file
            for entry in ownershipEntries {
                if let moduleName = entry.module {
                    // Extract framework name from identifier
                    let frameworkName = entry.identifier.replacingOccurrences(of: "*", with: "")
                    if !frameworkName.isEmpty {
                        moduleMapping[frameworkName] = moduleName
                    }
                }
            }
        }
        
        // Generate report from IPA
        let report = try generateReport(ipaPath: ipaPath)
        
        // Build app size report
        var appSizeReport = try buildAppSizeReport(
            report: report,
            unzippedPath: actualUnzippedPath,
            moduleMapping: moduleMapping
        )
        
        // Parse LinkMap if provided
        if let linkMapPath = linkMapPath {
            fputs("\nParsing LinkMap file...\n", stderr)
            do {
                let moduleSizes = try parseLinkMap(linkMapPath: linkMapPath)
                fputs("Found \(moduleSizes.count) modules in LinkMap\n", stderr)
                updateBinarySizes(&appSizeReport, moduleMapping: moduleMapping, moduleSizes: moduleSizes)
            } catch {
                fputs("Error parsing LinkMap: \(error)\n", stderr)
                throw error
            }
        }
        
        // Calculate totals
        let totalSize = try calculateTotalSize(ipaPath: ipaPath, unzippedPath: actualUnzippedPath)
        
        // Assign owners to modules
        if !ownershipEntries.isEmpty {
            for (moduleName, moduleSize) in appSizeReport {
                if let owner = findOwner(for: moduleName, in: ownershipEntries) {
                    moduleSize.owner = owner
                }
            }
        }
        
        // Filter by owner if specified
        var filteredModules = appSizeReport
        if let owner = filterOwner {
            filteredModules = appSizeReport.filter { $0.value.owner?.lowercased() == owner.lowercased() }
        }
        
        // Group by owner if requested
        var modulesByOwner: [String: [String: ModuleSize]]? = nil
        if groupByOwner && !ownershipEntries.isEmpty {
            var grouped: [String: [String: ModuleSize]] = [:]
            for (moduleName, moduleSize) in filteredModules {
                let owner = moduleSize.owner ?? "unknown"
                if grouped[owner] == nil {
                    grouped[owner] = [:]
                }
                grouped[owner]?[moduleName] = moduleSize
            }
            modulesByOwner = grouped
        }
        
        // Output JSON
        fputs("\nGenerating JSON output...\n", stderr)
        let outputData = CaliperOutput(
            modules: filteredModules,
            totalPackageSize: totalSize.packageSize,
            totalInstallSize: totalSize.installSize,
            modulesByOwner: modulesByOwner
        )
        
        // Always use pretty print for better readability
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let jsonData = try encoder.encode(outputData)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                fputs("Error converting JSON to string\n", stderr)
                throw CaliperError.invalidOutput
            }
            
            // Write to file or stdout
            if let outputPath = output {
                try jsonString.write(toFile: outputPath, atomically: true, encoding: .utf8)
                fputs("✅ Report saved to: \(outputPath)\n", stderr)
                
                // Always generate HTML report when output file is specified
                let url = URL(fileURLWithPath: outputPath)
                let htmlPath: String
                
                // Replace extension with .html (or add .html if no extension)
                if !url.pathExtension.isEmpty {
                    htmlPath = url.deletingPathExtension().appendingPathExtension("html").path
                } else {
                    htmlPath = outputPath + ".html"
                }
                
                fputs("\n📊 Generating HTML report...\n", stderr)
                do {
                    try generateHTMLReport(jsonString: jsonString, outputPath: htmlPath)
                    fputs("✅ HTML report saved to: \(htmlPath)\n", stderr)
                } catch {
                    fputs("⚠️  Warning: Failed to generate HTML report: \(error)\n", stderr)
                }
            } else {
                print(jsonString)
            }
        } catch {
            fputs("Error encoding JSON: \(error)\n", stderr)
            throw error
        }
    }
    
    private func loadOwnershipFile(from path: String) throws -> [OwnershipEntry] {
        let yamlString = try String(contentsOfFile: path, encoding: .utf8)
        let entries = try YAMLDecoder().decode([OwnershipEntry].self, from: yamlString)
        return entries
    }
    
    private func findOwner(for moduleName: String, in entries: [OwnershipEntry]) -> String? {
        for entry in entries {
            if entry.matches(moduleName) {
                return entry.owner
            }
        }
        return nil
    }
    
    private func unzipIPA(ipaPath: String, destination: String) throws {
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
    
    private func generateReport(ipaPath: String) throws -> String {
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
        
        // Parse unzip -v output to get: uncompressed_size compressed_size file_path
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
    
    private func buildAppSizeReport(
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
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3 else { continue }
            
            guard let uncompressedSize = Int64(parts[0]),
                  let compressedSize = Int64(parts[1]) else {
                continue
            }
            
            let filePath = String(parts[2])
            
            // Extract module name from path
            // Paths can be:
            // - "Payload/App.app/Frameworks/MyFramework.framework/..." (dynamic frameworks)
            // - "Payload/App.app/ProfisPartnerCore_ProfisPartnerCore.bundle/..." (resource bundles for static modules)
            var containerName: String? = nil
            var moduleName: String
            
            // Try to extract framework name
            if let frameworkRange = filePath.range(of: ".framework") {
                let beforeFramework = filePath[..<frameworkRange.lowerBound]
                if let lastSlash = beforeFramework.lastIndex(of: "/") {
                    containerName = String(beforeFramework[beforeFramework.index(after: lastSlash)...])
                }
            }
            // Try to extract bundle name (for statically linked modules)
            else if let bundleRange = filePath.range(of: ".bundle") {
                let beforeBundle = filePath[..<bundleRange.lowerBound]
                if let lastSlash = beforeBundle.lastIndex(of: "/") {
                    let fullBundleName = String(beforeBundle[beforeBundle.index(after: lastSlash)...])
                    // Bundle names are like "ProfisPartnerCore_ProfisPartnerCore", extract the first part
                    if let underscoreIndex = fullBundleName.firstIndex(of: "_") {
                        containerName = String(fullBundleName[..<underscoreIndex])
                    } else {
                        containerName = fullBundleName
                    }
                }
            }
            
            // If we have a container name (framework or bundle), use it
            if let container = containerName {
                // Check if there's a mapping for it, otherwise use container name directly
                if let mappedName = moduleMapping[container] {
                    moduleName = mappedName
                } else {
                    // No mapping - use container name directly
                    moduleName = container
                }
            } else {
                // Not a framework or bundle file, skip it
                continue
            }
            
            // Initialize module if not exists
            if result[moduleName] == nil {
                result[moduleName] = ModuleSize(name: moduleName)
            }
            
            guard let moduleSize = result[moduleName] else { continue }
            
            // Get file extension
            let components = filePath.split(separator: ".")
            guard let ext = components.last else { continue }
            let fileExtension = String(ext).lowercased()
            
            // Categorize by file type
            switch fileExtension {
            case "pdf", "gif", "jpg", "jpeg", "png":
                // Images
                moduleSize.imageSize += compressedSize
                moduleSize.imageFileSize += uncompressedSize
                moduleSize.addResource(type: fileExtension, size: compressedSize)
                moduleSize.addToTop(file: filePath, size: compressedSize)
                
            case "nib":
                // NIB files
                let resourceType = filePath.contains(".storyboardc") ? "storyboardc" : "nib"
                moduleSize.addResource(type: resourceType, size: compressedSize)
                moduleSize.addToTop(file: filePath, size: compressedSize)
                
            case "plist", "mov", "strings", "json":
                // Resources
                moduleSize.addResource(type: fileExtension, size: compressedSize)
                moduleSize.addToTop(file: filePath, size: compressedSize)
                
            case "car":
                // Asset catalogs - need to parse with assetutil
                try? parseAssetCatalog(
                    filePath: "\(unzippedPath)/\(filePath)",
                    moduleSize: moduleSize
                )
                
            default:
                // Check if it's the main binary (framework or bundle executable)
                if let container = containerName {
                    // For frameworks: file ends with framework name (e.g., "Lottie.framework/Lottie")
                    // For bundles: we don't expect binary files, but add to top anyway
                    if filePath.hasSuffix(container) {
                        moduleSize.binarySize = compressedSize
                    }
                }
                moduleSize.addToTop(file: filePath, size: compressedSize)
            }
            
            // Update proguard (uncompressed total size)
            moduleSize.proguard += uncompressedSize
        }
        
        // Finalize top files for each module (sort and keep top 30)
        for (_, moduleSize) in result {
            moduleSize.finalizeTop()
        }
        
        return result
    }
    
    private func parseAssetCatalog(filePath: String, moduleSize: ModuleSize) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["--sdk", "iphoneos", "assetutil", "--info", filePath]
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        // Print progress with full path
        fputs("  Parsing: \(filePath)\n", stderr)
        
        // Accumulate output data in background to prevent buffer blocking
        var outputData = Data()
        var errorData = Data()
        
        // Read stdout asynchronously to prevent blocking
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let availableData = handle.availableData
            if !availableData.isEmpty {
                outputData.append(availableData)
            }
        }
        
        // Read stderr asynchronously to prevent blocking
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let availableData = handle.availableData
            if !availableData.isEmpty {
                errorData.append(availableData)
            }
        }
        
        do {
            try process.run()
        } catch {
            fputs("  ⚠️  Warning: Failed to start assetutil\n", stderr)
            fputs("     File: \(filePath)\n", stderr)
            fputs("     Error: \(error)\n", stderr)
            return
        }
        
        // Wait for process to complete (with timeout)
        let timeout: TimeInterval = 10.0
        let startTime = Date()
        
        while process.isRunning && Date().timeIntervalSince(startTime) < timeout {
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Clean up handlers
        pipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        
        // If still running after timeout, terminate
        if process.isRunning {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.2)
            fputs("  ⚠️  Warning: assetutil timed out after \(Int(timeout))s\n", stderr)
            fputs("     File: \(filePath)\n", stderr)
            return
        }
        
        // Check exit code
        if process.terminationStatus != 0 {
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            fputs("  ⚠️  Warning: assetutil failed (exit code: \(process.terminationStatus))\n", stderr)
            fputs("     File: \(filePath)\n", stderr)
            if !errorOutput.isEmpty {
                fputs("     Error output: \(errorOutput)\n", stderr)
            }
            return
        }
        
        guard let output = String(data: outputData, encoding: .utf8) else { return }
        
        // Drop first line (header) and parse JSON array
        let lines = output.components(separatedBy: .newlines)
        guard lines.count > 1 else { return }
        
        let jsonString = "[" + lines.dropFirst().joined(separator: " ")
        guard let jsonData = jsonString.data(using: .utf8) else { return }
        
        do {
            let assets = try JSONDecoder().decode([AssetInfo].self, from: jsonData)
            
            for asset in assets {
                guard let name = asset.RenditionName,
                      let sizeOnDisk = asset.SizeOnDisk else {
                    continue
                }
                
                let size = Int64(sizeOnDisk)
                let components = name.split(separator: ".")
                guard let ext = components.last else { continue }
                let fileExtension = String(ext).lowercased()
                
                switch fileExtension {
                case "svg", "png", "pdf":
                    moduleSize.imageSize += size
                    moduleSize.imageFileSize += size
                    moduleSize.addResource(type: fileExtension, size: size)
                    moduleSize.addToTop(file: name, size: size)
                    
                case "0-gamut0", "1-gamut0":
                    moduleSize.addResource(type: fileExtension, size: size)
                    moduleSize.addToTop(file: name, size: size)
                    
                default:
                    break
                }
            }
        } catch {
            // Silently fail if asset parsing fails
            fputs("  ⚠️  Warning: Failed to parse asset data\n", stderr)
            fputs("     File: \(filePath)\n", stderr)
        }
    }
    
    private func parseLinkMap(linkMapPath: String) throws -> [String: Int64] {
        var moduleSizes: [String: Int64] = ["other": 0]
        var fileIndices: [String: String] = [:]
        
        // Try reading with UTF-8, fallback to ASCII
        var content: String
        do {
            content = try String(contentsOfFile: linkMapPath, encoding: .utf8)
        } catch {
            fputs("  Warning: UTF-8 reading failed, trying ASCII...\n", stderr)
            do {
                content = try String(contentsOfFile: linkMapPath, encoding: .ascii)
            } catch {
                fputs("  Warning: ASCII reading failed, trying data approach...\n", stderr)
                // Last resort: read as data and convert, replacing invalid characters
                let data = try Data(contentsOf: URL(fileURLWithPath: linkMapPath))
                guard let str = String(data: data, encoding: .utf8) ??
                                String(data: data, encoding: .ascii) ??
                                String(data: data, encoding: .isoLatin1) else {
                    throw NSError(domain: "CaliperError", code: 1, 
                                 userInfo: [NSLocalizedDescriptionKey: "Cannot read LinkMap file with any known encoding"])
                }
                content = str
            }
        }
        
        let lines = content.components(separatedBy: .newlines)
        
        var currentSection = ""
        
        for line in lines {
            if line.hasPrefix("#") {
                if line.lowercased().contains("files") {
                    currentSection = "files"
                } else if line.lowercased().contains("symbols") {
                    currentSection = "symbols"
                }
                continue
            }
            
            if currentSection == "files" {
                parseFileLine(line: line, fileIndices: &fileIndices)
            } else if currentSection == "symbols" {
                parseSymbolLine(line: line, fileIndices: fileIndices, moduleSizes: &moduleSizes)
            }
        }
        
        return moduleSizes
    }
    
    private func parseFileLine(line: String, fileIndices: inout [String: String]) {
        let components = line.components(separatedBy: "]")
        guard components.count > 1 else { return }
        
        let indexPart = components[0].replacingOccurrences(of: "[", with: "").trimmingCharacters(in: .whitespaces)
        let pathPart = components[1].trimmingCharacters(in: .whitespaces)
        
        // Extract module name from path
        // Following the Groovy script approach: look at the LAST path component (filename)
        // and match against known module prefixes
        
        let pathComponents = pathPart.components(separatedBy: "/")
        guard let fileName = pathComponents.last?.trimmingCharacters(in: .whitespaces) else {
            return
        }
        
        // Remove file extension to get the base name
        let baseName = fileName.replacingOccurrences(of: ".o", with: "")
            .replacingOccurrences(of: ".a", with: "")
        
        // Known module prefixes to check (matching Groovy script's modules list)
        let modulePrefixes = [
            "ProfisPartnerMover",
            "ProfisPartnerCraftsmen",
            "ProfisPartnerEvents",
            "ProfisPartnerPortal",
            "C24ProfisNativeMessenger",
            "ProfisPartnerCore"  // Check ProfisPartnerCore last as it's the catch-all
        ]
        
        // Find matching module by prefix
        var moduleName: String? = nil
        for prefix in modulePrefixes {
            if baseName.lowercased().hasPrefix(prefix.lowercased()) {
                moduleName = prefix
                break
            }
        }
        
        // If no prefix match, treat the filename itself as a module (for external dependencies)
        if moduleName == nil {
            // Check if it's in a .build directory to use that as module name
            for component in pathComponents {
                if component.hasSuffix(".build") {
                    moduleName = component.replacingOccurrences(of: ".build", with: "")
                    break
                }
            }
            
            // If still no match, use the base filename as module name
            if moduleName == nil {
                moduleName = baseName
            }
        }
        
        if let name = moduleName {
            fileIndices[indexPart] = name
        }
    }
    
    private func parseSymbolLine(line: String, fileIndices: [String: String], moduleSizes: inout [String: Int64]) {
        let components = line.components(separatedBy: "\t")
        guard components.count > 2 else { return }
        
        // Parse hex size
        let sizeComponents = components[1].components(separatedBy: "x")
        guard sizeComponents.count > 1,
              let size = Int64(sizeComponents[1], radix: 16) else {
            return
        }
        
        // Parse file index
        let indexComponents = components[2].components(separatedBy: "]")
        let indexPart = indexComponents[0].replacingOccurrences(of: "[", with: "").trimmingCharacters(in: .whitespaces)
        
        if let moduleName = fileIndices[indexPart] {
            moduleSizes[moduleName, default: 0] += size
        } else {
            moduleSizes["other", default: 0] += size
        }
    }
    
    private func updateBinarySizes(
        _ appSizeReport: inout [String: ModuleSize],
        moduleMapping: [String: String],
        moduleSizes: [String: Int64]
    ) {
        // First pass: Update binary sizes for ALL modules found in LinkMap
        for (moduleName, size) in moduleSizes {
            // Skip "other" synthetic module
            if moduleName == "other" {
                continue
            }
            
            if let existingModule = appSizeReport[moduleName] {
                // Update existing module (created from bundle/framework processing)
                existingModule.binarySize = size
                existingModule.proguard += size
            } else {
                // Create new module from LinkMap (for modules without bundles/frameworks)
                let newModule = ModuleSize(name: moduleName)
                newModule.binarySize = size
                newModule.proguard = size
                appSizeReport[moduleName] = newModule
            }
        }
        
        // Second pass: Handle any module mappings (if provided)
        for (originalName, mappedName) in moduleMapping {
            if let size = moduleSizes[originalName] {
                if let moduleSize = appSizeReport[mappedName] {
                    // Update the mapped module with the original's size
                    moduleSize.binarySize = size
                    moduleSize.proguard += size
                }
            }
        }
    }
    
    private func calculateTotalSize(ipaPath: String, unzippedPath: String) throws -> (packageSize: Int64, installSize: Int64) {
        // Package size (compressed IPA)
        let ipaURL = URL(fileURLWithPath: ipaPath)
        let attributes = try FileManager.default.attributesOfItem(atPath: ipaURL.path)
        let packageSize = attributes[.size] as? Int64 ?? 0
        
        // Install size (uncompressed)
        let installSize = try directorySize(at: unzippedPath)
        
        return (packageSize, installSize)
    }
    
    private func directorySize(at path: String) throws -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(atPath: path) {
            for case let file as String in enumerator {
                let filePath = (path as NSString).appendingPathComponent(file)
                let attributes = try fileManager.attributesOfItem(atPath: filePath)
                totalSize += attributes[.size] as? Int64 ?? 0
            }
        }
        
        return totalSize
    }
    
    private func generateHTMLReport(jsonString: String, outputPath: String) throws {
        let htmlTemplate = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>App Size Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Helvetica Neue', sans-serif; background: #f5f5f5; padding: 20px; line-height: 1.6; }
        .container { max-width: 1400px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); overflow: hidden; }
        header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; }
        header h1 { font-size: 32px; margin-bottom: 10px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; padding: 30px; background: #f8f9fa; border-bottom: 1px solid #e0e0e0; }
        .summary-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .summary-card h3 { font-size: 14px; color: #666; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 0.5px; }
        .summary-card .value { font-size: 28px; font-weight: bold; color: #333; }
        .controls { padding: 20px 30px; background: white; border-bottom: 1px solid #e0e0e0; display: flex; gap: 15px; flex-wrap: wrap; align-items: center; }
        .controls input { padding: 10px 15px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px; flex: 1; min-width: 200px; }
        .controls select { padding: 10px 15px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px; background: white; cursor: pointer; }
        .modules-grid { padding: 30px; }
        .module-card { background: white; border: 1px solid #e0e0e0; border-radius: 8px; margin-bottom: 20px; overflow: hidden; transition: box-shadow 0.2s; }
        .module-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
        .module-header { padding: 20px; background: #fafafa; border-bottom: 1px solid #e0e0e0; cursor: pointer; display: flex; justify-content: space-between; align-items: center; }
        .module-header:hover { background: #f0f0f0; }
        .module-title { font-size: 18px; font-weight: 600; color: #333; }
        .module-owner { font-size: 12px; color: #666; margin-top: 4px; }
        .module-size { font-size: 16px; color: #667eea; font-weight: bold; }
        .module-details { padding: 20px; display: none; }
        .module-details.open { display: block; }
        .size-bars { margin-bottom: 30px; }
        .size-bar { margin-bottom: 15px; }
        .size-bar-label { display: flex; justify-content: space-between; margin-bottom: 5px; font-size: 14px; }
        .size-bar-label .name { color: #333; font-weight: 500; }
        .size-bar-label .value { color: #666; }
        .size-bar-fill { height: 8px; background: #e0e0e0; border-radius: 4px; overflow: hidden; }
        .size-bar-progress { height: 100%; background: linear-gradient(90deg, #667eea 0%, #764ba2 100%); transition: width 0.3s; }
        .resources-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 30px; }
        .resource-card { background: #f8f9fa; padding: 15px; border-radius: 6px; }
        .resource-type { font-size: 12px; color: #666; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 5px; }
        .resource-size { font-size: 18px; font-weight: bold; color: #333; }
        .resource-count { font-size: 12px; color: #999; }
        .top-files { margin-top: 20px; }
        .top-files h4 { font-size: 16px; margin-bottom: 15px; color: #333; }
        .file-item { display: flex; justify-content: space-between; padding: 10px; background: #f8f9fa; margin-bottom: 5px; border-radius: 4px; font-size: 13px; }
        .file-path { color: #666; flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-family: 'Courier New', monospace; }
        .file-size { color: #333; font-weight: 500; margin-left: 15px; }
        .no-results { text-align: center; padding: 60px 20px; color: #999; font-size: 16px; }
        .expand-icon { transition: transform 0.2s; }
        .expand-icon.open { transform: rotate(180deg); }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📱 App Size Report</h1>
            <p>Detailed analysis of app module sizes and resources</p>
        </header>
        <div class="summary" id="summary"></div>
        <div class="controls">
            <input type="text" id="searchInput" placeholder="Search modules..." />
            <select id="sortSelect">
                <option value="size">Sort by: Total Size</option>
                <option value="binary">Sort by: Binary Size</option>
                <option value="name">Sort by: Name</option>
            </select>
            <select id="ownerFilter"><option value="">All Owners</option></select>
        </div>
        <div class="modules-grid" id="modulesGrid"></div>
    </div>
    <script>
        const data = __DATA__;
        function formatBytes(bytes) {
            if (bytes === 0) return '0 B';
            const k = 1024;
            const sizes = ['B', 'KB', 'MB', 'GB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }
        function calculateModuleTotal(module) { return module.proguard || 0; }
        function renderSummary() {
            const totalPackageSize = data.totalPackageSize || 0;
            const totalInstallSize = data.totalInstallSize || 0;
            const moduleCount = Object.keys(data.modules).length;
            const totalBinarySize = Object.values(data.modules).reduce((sum, m) => sum + (m.binarySize || 0), 0);
            document.getElementById('summary').innerHTML = `
                <div class="summary-card"><h3>Package Size (IPA)</h3><div class="value">${formatBytes(totalPackageSize)}</div></div>
                <div class="summary-card"><h3>Install Size</h3><div class="value">${formatBytes(totalInstallSize)}</div></div>
                <div class="summary-card"><h3>Total Binary Size</h3><div class="value">${formatBytes(totalBinarySize)}</div></div>
                <div class="summary-card"><h3>Module Count</h3><div class="value">${moduleCount}</div></div>
            `;
        }
        function getUniqueOwners() {
            const owners = new Set();
            Object.values(data.modules).forEach(module => { if (module.owner) owners.add(module.owner); });
            return Array.from(owners).sort();
        }
        function populateOwnerFilter() {
            const owners = getUniqueOwners();
            const select = document.getElementById('ownerFilter');
            owners.forEach(owner => {
                const option = document.createElement('option');
                option.value = owner;
                option.textContent = owner;
                select.appendChild(option);
            });
        }
        function renderModules(searchTerm = '', sortBy = 'size', ownerFilter = '') {
            let modules = Object.values(data.modules);
            if (searchTerm) modules = modules.filter(m => m.name.toLowerCase().includes(searchTerm.toLowerCase()));
            if (ownerFilter) modules = modules.filter(m => m.owner === ownerFilter);
            modules.sort((a, b) => {
                switch(sortBy) {
                    case 'size': return calculateModuleTotal(b) - calculateModuleTotal(a);
                    case 'binary': return (b.binarySize || 0) - (a.binarySize || 0);
                    case 'name': return a.name.localeCompare(b.name);
                    default: return 0;
                }
            });
            const grid = document.getElementById('modulesGrid');
            if (modules.length === 0) { grid.innerHTML = '<div class="no-results">No modules found</div>'; return; }
            const maxSize = Math.max(...modules.map(m => calculateModuleTotal(m)));
            grid.innerHTML = modules.map((module, index) => {
                const totalSize = calculateModuleTotal(module);
                const binaryPercent = maxSize > 0 ? (module.binarySize || 0) / maxSize * 100 : 0;
                const imagePercent = maxSize > 0 ? (module.imageFileSize || 0) / maxSize * 100 : 0;
                const resourcesHTML = Object.keys(module.resources || {}).length > 0 ? `
                    <h4 style="margin-top: 20px; margin-bottom: 15px; color: #333;">Resources</h4>
                    <div class="resources-grid">
                        ${Object.entries(module.resources).map(([type, res]) => `
                            <div class="resource-card">
                                <div class="resource-type">${type}</div>
                                <div class="resource-size">${formatBytes(res.size)}</div>
                                <div class="resource-count">${res.count} files</div>
                            </div>
                        `).join('')}
                    </div>
                ` : '';
                const topFiles = Object.entries(module.top || {}).sort((a, b) => b[1] - a[1]).slice(0, 10);
                const topFilesHTML = topFiles.length > 0 ? `
                    <div class="top-files">
                        <h4>Top 10 Largest Files</h4>
                        ${topFiles.map(([path, size]) => `
                            <div class="file-item">
                                <span class="file-path" title="${path}">${path}</span>
                                <span class="file-size">${formatBytes(size)}</span>
                            </div>
                        `).join('')}
                    </div>
                ` : '';
                return `
                    <div class="module-card">
                        <div class="module-header" onclick="toggleModule(${index})">
                            <div>
                                <div class="module-title">${module.name}</div>
                                ${module.owner ? `<div class="module-owner">Owner: ${module.owner}</div>` : ''}
                            </div>
                            <div style="text-align: right;">
                                <div class="module-size">${formatBytes(totalSize)}</div>
                                <span class="expand-icon" id="icon-${index}">▼</span>
                            </div>
                        </div>
                        <div class="module-details" id="module-${index}">
                            <div class="size-bars">
                                <div class="size-bar">
                                    <div class="size-bar-label"><span class="name">Binary Size</span><span class="value">${formatBytes(module.binarySize || 0)}</span></div>
                                    <div class="size-bar-fill"><div class="size-bar-progress" style="width: ${binaryPercent}%"></div></div>
                                </div>
                                <div class="size-bar">
                                    <div class="size-bar-label"><span class="name">Image Assets</span><span class="value">${formatBytes(module.imageFileSize || 0)}</span></div>
                                    <div class="size-bar-fill"><div class="size-bar-progress" style="width: ${imagePercent}%"></div></div>
                                </div>
                                <div class="size-bar">
                                    <div class="size-bar-label"><span class="name">Total (Uncompressed)</span><span class="value">${formatBytes(module.proguard || 0)}</span></div>
                                    <div class="size-bar-fill"><div class="size-bar-progress" style="width: 100%"></div></div>
                                </div>
                            </div>
                            ${resourcesHTML}
                            ${topFilesHTML}
                        </div>
                    </div>
                `;
            }).join('');
        }
        function toggleModule(index) {
            document.getElementById(`module-${index}`).classList.toggle('open');
            document.getElementById(`icon-${index}`).classList.toggle('open');
        }
        document.getElementById('searchInput').addEventListener('input', (e) => {
            renderModules(e.target.value, document.getElementById('sortSelect').value, document.getElementById('ownerFilter').value);
        });
        document.getElementById('sortSelect').addEventListener('change', (e) => {
            renderModules(document.getElementById('searchInput').value, e.target.value, document.getElementById('ownerFilter').value);
        });
        document.getElementById('ownerFilter').addEventListener('change', (e) => {
            renderModules(document.getElementById('searchInput').value, document.getElementById('sortSelect').value, e.target.value);
        });
        renderSummary();
        populateOwnerFilter();
        renderModules();
    </script>
</body>
</html>
"""
        
        let html = htmlTemplate.replacingOccurrences(of: "__DATA__", with: jsonString)
        try html.write(toFile: outputPath, atomically: true, encoding: .utf8)
    }
}

// MARK: - Models

class ModuleSize: Codable {
    var name: String
    var owner: String?
    var binarySize: Int64 = 0
    var imageSize: Int64 = 0
    var imageFileSize: Int64 = 0
    var proguard: Int64 = 0
    var resources: [String: Resource] = [:]
    var top: [String: Int64] = [:]
    
    init(name: String) {
        self.name = name
        self.owner = nil
    }
    
    func addResource(type: String, size: Int64) {
        if resources[type] == nil {
            resources[type] = Resource()
        }
        resources[type]?.size += size
        resources[type]?.count += 1
    }
    
    func addToTop(file: String, size: Int64) {
        top[file] = size
    }
    
    func finalizeTop() {
        // Sort by size (descending) and keep only top 30
        // Build a new ordered dictionary with sorted entries
        let sorted = top.sorted { $0.value > $1.value }.prefix(30)
        top = [:]
        for (key, value) in sorted {
            top[key] = value
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name, owner, binarySize, imageSize, imageFileSize, proguard, resources, top
    }
}

struct Resource: Codable {
    var size: Int64 = 0
    var count: Int = 0
}

struct AssetInfo: Codable {
    let RenditionName: String?
    let SizeOnDisk: Int?
}

struct CaliperOutput: Codable {
    let modules: [String: ModuleSize]
    let totalPackageSize: Int64
    let totalInstallSize: Int64
    let modulesByOwner: [String: [String: ModuleSize]]?
    
    enum CodingKeys: String, CodingKey {
        case modules, totalPackageSize, totalInstallSize, modulesByOwner
    }
}

struct OwnershipEntry: Codable {
    let identifier: String
    let owner: String
    let module: String?
    
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

enum CaliperError: Error {
    case unzipFailed
    case invalidIPA
    case invalidOwnershipFile
    case invalidOutput
}
