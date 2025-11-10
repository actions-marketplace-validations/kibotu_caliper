import Foundation
import ArgumentParser

@main
struct Caliper: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Measure binary and bundle sizes for Swift packages in an IPA",
        version: "1.0.0"
    )
    
    @Option(name: .long, help: "Path to the IPA file")
    var ipaPath: String
    
    @Option(name: .long, help: "Optional path to LinkMap file for accurate binary sizes")
    var linkMapPath: String?
    
    @Option(name: .long, help: "Optional YAML file containing module ownership configuration")
    var ownershipFile: String?
    
    @Option(name: .long, help: "Optional path to Package.resolved file for Swift package version information")
    var packageResolvedPath: String?
    
    // MARK: - Main Execution
    
    func run() throws {
        // Initialize services
        let ipaService = IPAService()
        let ownershipService = OwnershipService()
        let versionService = VersionService()
        let sizeCalculator = SizeCalculator()
        let ipaParser = IPAParser()
        let linkMapParser = LinkMapParser()
        let packageResolvedParser = PackageResolvedParser()
        let jsonReporter = JSONReporter()
        let htmlReporter = HTMLReporter()
        
        // Verify IPA exists
        try ipaService.verifyIPAExists(at: ipaPath)
        
        // Generate unzipped path (always auto-generate and cleanup)
        let ipaURL = URL(fileURLWithPath: ipaPath)
        let ipaName = ipaURL.deletingPathExtension().lastPathComponent
        let unzippedPath = "\(ipaName)_unzipped"
        
        // Remove existing unzipped directory if it exists
        if FileManager.default.fileExists(atPath: unzippedPath) {
            ProgressReporter.info("Removing existing unzipped directory: \(unzippedPath)")
            try? FileManager.default.removeItem(atPath: unzippedPath)
        }
        
        // Unzip IPA
        ProgressReporter.section("📦 Unzipping IPA to: \(unzippedPath)")
        try ipaService.unzip(ipaPath: ipaPath, destination: unzippedPath)
        ProgressReporter.success("IPA unzipped successfully")
        
        // Always cleanup at the end
        defer {
            ipaService.cleanup(path: unzippedPath)
        }
        
        // Load ownership configuration
        let (ownershipEntries, moduleMapping) = try loadOwnershipConfiguration(
            ownershipService: ownershipService
        )
        
        // Generate report from IPA
        let report = try ipaParser.generateReport(ipaPath: ipaPath)
        
        // Build app size report
        var appSizeReport = try ipaParser.buildAppSizeReport(
            report: report,
            unzippedPath: unzippedPath,
            moduleMapping: moduleMapping
        )
        
        // Parse LinkMap if provided
        if let linkMapPath = linkMapPath {
            ProgressReporter.section("Parsing LinkMap file...")
            let moduleSizes = try linkMapParser.parse(linkMapPath: linkMapPath)
            ProgressReporter.message("Found \(moduleSizes.count) modules in LinkMap")
            
            sizeCalculator.updateBinarySizes(
                in: &appSizeReport,
                moduleMapping: moduleMapping,
                moduleSizes: moduleSizes
            )
        }
        
        // Calculate total sizes
        let totalSize = try sizeCalculator.calculateTotalSize(
            ipaPath: ipaPath,
            unzippedPath: unzippedPath
        )
        
        // Parse Package.resolved if provided
        if let packageResolvedPath = packageResolvedPath {
            ProgressReporter.section("📦 Parsing Package.resolved file...")
            let versionMapping = try packageResolvedParser.parse(path: packageResolvedPath)
            versionService.assignVersions(to: appSizeReport, using: versionMapping)
        }
        
        // Assign owners to modules
        if !ownershipEntries.isEmpty {
            ownershipService.assignOwners(to: appSizeReport, using: ownershipEntries)
        }
        
        // Group by owner if ownership file was provided
        var modulesByOwner: [String: [String: ModuleSize]]? = nil
        if !ownershipEntries.isEmpty {
            modulesByOwner = ownershipService.groupModulesByOwner(appSizeReport)
        }
        
        // Generate JSON output (always to report.json)
        ProgressReporter.section("Generating JSON output...")
        let jsonOutputPath = "report.json"
        let jsonString = try jsonReporter.generate(
            modules: appSizeReport,
            totalSize: totalSize,
            modulesByOwner: modulesByOwner,
            outputPath: jsonOutputPath
        )
        
        // Generate HTML report (always to report.html)
        ProgressReporter.section("📊 Generating HTML report...")
        let htmlOutputPath = "report.html"
        do {
            try htmlReporter.generate(jsonString: jsonString, outputPath: htmlOutputPath)
            ProgressReporter.success("HTML report saved to: \(htmlOutputPath)")
        } catch {
            ProgressReporter.error("Failed to generate HTML report: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func loadOwnershipConfiguration(
        ownershipService: OwnershipService
    ) throws -> (entries: [OwnershipEntry], mapping: [String: String]) {
        guard let ownershipPath = ownershipFile else {
            return ([], [:])
        }
        
        let entries = try ownershipService.loadOwnershipFile(from: ownershipPath)
        let mapping = ownershipService.buildModuleMapping(from: entries)
        
        return (entries, mapping)
    }
}
