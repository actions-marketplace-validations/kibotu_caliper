import Foundation

/// Reporter for generating JSON output
struct JSONReporter {
    
    /// Generate and output JSON report
    func generate(
        modules: [String: ModuleSize],
        totalSize: (packageSize: Int64, installSize: Int64),
        modulesByOwner: [String: [String: ModuleSize]]?,
        outputPath: String?
    ) throws -> String {
        let outputData = CaliperOutput(
            modules: modules,
            totalPackageSize: totalSize.packageSize,
            totalInstallSize: totalSize.installSize,
            modulesByOwner: modulesByOwner
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData = try encoder.encode(outputData)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw CaliperError.invalidOutput
        }
        
        // Write to file or stdout
        if let path = outputPath {
            try jsonString.write(toFile: path, atomically: true, encoding: .utf8)
            fputs("✅ Report saved to: \(path)\n", stderr)
        } else {
            print(jsonString)
        }
        
        return jsonString
    }
}

