import Foundation

/// Parser for LinkMap files to extract module sizes
struct LinkMapParser {
    
    /// Parse a LinkMap file and return module sizes
    func parse(linkMapPath: String) throws -> [String: Int64] {
        var moduleSizes: [String: Int64] = ["other": 0]
        var fileIndices: [String: String] = [:]
        
        let content = try readLinkMapFile(at: linkMapPath)
        let lines = content.components(separatedBy: .newlines)
        
        var currentSection = ""
        
        for line in lines {
            if line.hasPrefix("#") {
                let newSection = identifySection(from: line)
                if !newSection.isEmpty {
                    currentSection = newSection
                }
                continue
            }
            
            switch currentSection {
            case "files":
                parseFileLine(line: line, fileIndices: &fileIndices)
            case "symbols":
                parseSymbolLine(line: line, fileIndices: fileIndices, moduleSizes: &moduleSizes)
            default:
                break
            }
        }
        
        return moduleSizes
    }
    
    // MARK: - Private Methods
    
    private func readLinkMapFile(at path: String) throws -> String {
        // Try reading with UTF-8, fallback to ASCII, then ISO Latin 1
        if let content = try? String(contentsOfFile: path, encoding: .utf8) {
            return content
        }
        
        if let content = try? String(contentsOfFile: path, encoding: .ascii) {
            return content
        }
        
        // Last resort: read as data and convert
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let content = String(data: data, encoding: .utf8) ??
                           String(data: data, encoding: .ascii) ??
                           String(data: data, encoding: .isoLatin1) else {
            throw CaliperError.linkMapParsingFailed("Cannot read file with any known encoding")
        }
        
        return content
    }
    
    private func identifySection(from line: String) -> String {
        let lowercased = line.lowercased()
        if lowercased.contains("object files") {
            return "files"
        } else if lowercased.contains("symbols") && !lowercased.contains("dead") {
            return "symbols"
        }
        return ""
    }
    
    private func parseFileLine(line: String, fileIndices: inout [String: String]) {
        let components = line.components(separatedBy: "]")
        guard components.count > 1 else { return }
        
        let indexPart = components[0]
            .replacingOccurrences(of: "[", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        let pathPart = components[1].trimmingCharacters(in: .whitespaces)
        let pathComponents = pathPart.components(separatedBy: "/")
        
        guard let fileName = pathComponents.last?.trimmingCharacters(in: .whitespaces) else {
            return
        }
        
        // Remove file extension to get base name
        let baseName = fileName
            .replacingOccurrences(of: ".o", with: "")
            .replacingOccurrences(of: ".a", with: "")
        
        // Find module name
        let moduleName = findModuleName(baseName: baseName, pathComponents: pathComponents)
        fileIndices[indexPart] = moduleName
    }
    
    private func findModuleName(baseName: String, pathComponents: [String]) -> String {
        // Known module prefixes (check in order of specificity)
        let modulePrefixes = [
            "ProfisPartnerMover",
            "ProfisPartnerCraftsmen",
            "ProfisPartnerEvents",
            "ProfisPartnerPortal",
            "C24ProfisNativeMessenger",
            "ProfisPartnerCore"
        ]
        
        // Check for prefix match
        for prefix in modulePrefixes {
            if baseName.lowercased().hasPrefix(prefix.lowercased()) {
                return prefix
            }
        }
        
        // Check for .build directory in path
        for component in pathComponents {
            if component.hasSuffix(".build") {
                return component.replacingOccurrences(of: ".build", with: "")
            }
        }
        
        // Default to base filename
        return baseName
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
        let indexPart = indexComponents[0]
            .replacingOccurrences(of: "[", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        // Add size to appropriate module
        if let moduleName = fileIndices[indexPart] {
            moduleSizes[moduleName, default: 0] += size
        } else {
            moduleSizes["other", default: 0] += size
        }
    }
}

