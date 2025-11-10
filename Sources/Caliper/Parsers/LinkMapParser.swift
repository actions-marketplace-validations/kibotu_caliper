import Foundation

/// Structure to hold file information from LinkMap
struct FileInfo {
    let fileName: String
    let moduleName: String
}

/// Structure to hold detailed parsing results
struct LinkMapDetails {
    var moduleSizes: [String: Int64] = ["other": 0]
    var fileDetails: [String: [String: Int64]] = [:] // [moduleName: [fileName: size]]
}

/// Parser for LinkMap files to extract module sizes
struct LinkMapParser {
    
    /// Parse a LinkMap file and return module sizes
    func parse(linkMapPath: String) throws -> [String: Int64] {
        let details = try parseDetailed(linkMapPath: linkMapPath)
        return details.moduleSizes
    }
    
    /// Parse a LinkMap file and return detailed module and file sizes
    func parseDetailed(linkMapPath: String) throws -> LinkMapDetails {
        var details = LinkMapDetails()
        var fileIndices: [String: FileInfo] = [:]
        
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
                parseSymbolLine(line: line, fileIndices: fileIndices, details: &details)
            default:
                break
            }
        }
        
        return details
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
    
    private func parseFileLine(line: String, fileIndices: inout [String: FileInfo]) {
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
        
        // Store both file name and module name
        fileIndices[indexPart] = FileInfo(fileName: baseName, moduleName: moduleName)
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
    
    private func parseSymbolLine(line: String, fileIndices: [String: FileInfo], details: inout LinkMapDetails) {
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
        
        // Get symbol name (rest of the line after the file index)
        let symbolName = indexComponents.count > 1 ? 
            indexComponents[1].trimmingCharacters(in: .whitespaces) : ""
        
        // Add size to appropriate module and file
        if let fileInfo = fileIndices[indexPart] {
            // Update module size
            details.moduleSizes[fileInfo.moduleName, default: 0] += size
            
            // Try to extract class/type name from symbol for better granularity
            let extractedFileName = extractClassNameFromSymbol(symbolName) ?? fileInfo.fileName
            
            // Update file size within module
            if details.fileDetails[fileInfo.moduleName] == nil {
                details.fileDetails[fileInfo.moduleName] = [:]
            }
            
            // Track both size and count - we aggregate later
            details.fileDetails[fileInfo.moduleName]?[extractedFileName, default: 0] += size
        } else {
            details.moduleSizes["other", default: 0] += size
        }
    }
    
    /// Extract class/type name from a mangled Swift or Objective-C symbol
    private func extractClassNameFromSymbol(_ symbol: String) -> String? {
        // Try using swift-demangle first for better accuracy
        if symbol.hasPrefix("_$s") || symbol.hasPrefix("$s") || symbol.hasPrefix("_$S") || symbol.hasPrefix("$S") {
            if let demangled = demangleSwiftSymbol(symbol) {
                return demangled
            }
            // Fallback to manual parsing
            return extractSwiftClassName(from: symbol)
        }
        
        // Handle Objective-C symbols (e.g., -[ClassName methodName:] or +[ClassName methodName:])
        if symbol.hasPrefix("-[") || symbol.hasPrefix("+[") {
            let withoutPrefix = String(symbol.dropFirst(2))
            if let spaceIndex = withoutPrefix.firstIndex(of: " ") {
                return String(withoutPrefix[..<spaceIndex])
            }
        }
        
        return nil
    }
    
    /// Demangle Swift symbol using swift-demangle or stdlib
    private func demangleSwiftSymbol(_ symbol: String) -> String? {
        // Use stdlib's _stdlib_demangleName if available
        let demangled = _stdlib_demangleImpl(
            mangledName: symbol,
            mangledNameLength: UInt(symbol.utf8.count),
            outputBuffer: nil,
            outputBufferSize: nil,
            flags: 0
        )
        
        if let cString = demangled {
            defer { free(UnsafeMutableRawPointer(mutating: cString)) }
            let demangledString = String(cString: cString)
            
            // Extract class name from demangled string
            // Format: "ModuleName.ClassName.methodName(...)" or similar
            return extractClassNameFromDemangled(demangledString)
        }
        
        return nil
    }
    
    /// Extract class name from a demangled Swift symbol
    private func extractClassNameFromDemangled(_ demangled: String) -> String? {
        // Common patterns:
        // "ProfisPartnerCore.PaymentCenterTutorialHostingController.viewDidLoad() -> ()"
        // "ProfisPartnerCore.PaymentCenterTutorialHostingController.init() -> ProfisPartnerCore.PaymentCenterTutorialHostingController"
        // "(extension in ProfisPartnerCore):__C.NSBundle.module.unsafeMutableAddressor : __C.NSBundle"
        
        // Remove generic parameters and return types for cleaner parsing
        let cleaned = demangled.components(separatedBy: " -> ").first ?? demangled
        
        // Try to find pattern: ModuleName.ClassName
        let components = cleaned.components(separatedBy: ".")
        
        // Handle extension syntax: "(extension in ModuleName):..."
        if cleaned.hasPrefix("(extension in ") {
            let afterExtension = cleaned.replacingOccurrences(of: "(extension in ", with: "")
            if let colonIndex = afterExtension.firstIndex(of: ":") {
                let remaining = String(afterExtension[afterExtension.index(after: colonIndex)...])
                let parts = remaining.components(separatedBy: ".")
                if parts.count >= 2 {
                    // Return the class/type name (usually the second component)
                    return parts[1].components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces)
                }
            }
            return nil
        }
        
        // For regular symbols, extract ClassName (second component typically)
        if components.count >= 2 {
            let className = components[1].components(separatedBy: "(").first?
                .trimmingCharacters(in: .whitespaces)
            
            // Filter out noise
            if let className = className,
               !className.isEmpty,
               !className.hasPrefix("_"),
               className.count < 100,  // Sanity check
               className.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                return className
            }
        }
        
        return nil
    }
    
    /// Swift stdlib demangling function
    @_silgen_name("swift_demangle")
    private func _stdlib_demangleImpl(
        mangledName: UnsafePointer<CChar>?,
        mangledNameLength: UInt,
        outputBuffer: UnsafeMutablePointer<CChar>?,
        outputBufferSize: UnsafeMutablePointer<UInt>?,
        flags: UInt32
    ) -> UnsafeMutablePointer<CChar>?
    
    /// Extract class name from Swift mangled symbol
    /// Format: _$s<ModuleNameLength><ModuleName><ClassNameLength><ClassName>...
    private func extractSwiftClassName(from symbol: String) -> String? {
        // Remove the _$s or $s prefix
        let cleanSymbol = symbol.hasPrefix("_$s") ? String(symbol.dropFirst(3)) : String(symbol.dropFirst(2))
        
        // Try to parse the mangled name format
        var index = cleanSymbol.startIndex
        
        // Skip module name
        if let moduleLength = extractLength(from: cleanSymbol, at: &index) {
            index = cleanSymbol.index(index, offsetBy: moduleLength, limitedBy: cleanSymbol.endIndex) ?? cleanSymbol.endIndex
            
            // Now extract class name
            if index < cleanSymbol.endIndex,
               let classLength = extractLength(from: cleanSymbol, at: &index),
               classLength > 0,
               classLength < 200 { // Sanity check
                let endIndex = cleanSymbol.index(index, offsetBy: classLength, limitedBy: cleanSymbol.endIndex) ?? cleanSymbol.endIndex
                let className = String(cleanSymbol[index..<endIndex])
                
                // Only return if it looks like a valid class name
                if className.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                    return className
                }
            }
        }
        
        return nil
    }
    
    /// Extract a length value from the mangled symbol
    private func extractLength(from string: String, at index: inout String.Index) -> Int? {
        var length = 0
        var digitCount = 0
        
        while index < string.endIndex && string[index].isNumber {
            if let digit = string[index].wholeNumberValue {
                length = length * 10 + digit
                digitCount += 1
            }
            index = string.index(after: index)
        }
        
        return digitCount > 0 ? length : nil
    }
}

