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
    
    // MARK: - Main Execution
    
    func run() throws {
        // Initialize services
        let ipaService = IPAService()
        let ownershipService = OwnershipService()
        let sizeCalculator = SizeCalculator()
        let ipaParser = IPAParser()
        let linkMapParser = LinkMapParser()
        let jsonReporter = JSONReporter()
        let htmlReporter = HTMLReporter()
        
        // Verify IPA exists
        try ipaService.verifyIPAExists(at: ipaPath)
        
        // Determine unzipped path
        let (actualUnzippedPath, shouldCleanup) = ipaService.determineUnzippedPath(
            ipaPath: ipaPath,
            userProvidedPath: unzippedPath
        )
        
        // Unzip if needed
        let needsUnzip = ipaService.needsUnzip(at: actualUnzippedPath)
        if needsUnzip {
            ProgressReporter.section("📦 Unzipping IPA to: \(actualUnzippedPath)")
            try ipaService.unzip(ipaPath: ipaPath, destination: actualUnzippedPath)
            ProgressReporter.success("IPA unzipped successfully")
        } else {
            ProgressReporter.info("Using existing unzipped directory: \(actualUnzippedPath)")
        }
        
        // Setup cleanup
        defer {
            if shouldCleanup && needsUnzip {
                ipaService.cleanup(path: actualUnzippedPath)
            }
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
            unzippedPath: actualUnzippedPath,
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
            unzippedPath: actualUnzippedPath
        )
        
        // Assign owners to modules
        if !ownershipEntries.isEmpty {
            ownershipService.assignOwners(to: appSizeReport, using: ownershipEntries)
        }
        
        // Filter by owner if specified
        var filteredModules = appSizeReport
        if let owner = filterOwner {
            filteredModules = ownershipService.filterModules(appSizeReport, byOwner: owner)
        }
        
        // Group by owner if requested
        var modulesByOwner: [String: [String: ModuleSize]]? = nil
        if groupByOwner && !ownershipEntries.isEmpty {
            modulesByOwner = ownershipService.groupModulesByOwner(filteredModules)
        }
        
        // Generate JSON output
        ProgressReporter.section("Generating JSON output...")
        let jsonString = try jsonReporter.generate(
            modules: filteredModules,
            totalSize: totalSize,
            modulesByOwner: modulesByOwner,
            outputPath: output
        )
        
        // Generate HTML report if output file is specified
        if let outputPath = output {
            ProgressReporter.section("📊 Generating HTML report...")
            let htmlPath = htmlReporter.determineOutputPath(from: outputPath)
            do {
                try htmlReporter.generate(jsonString: jsonString, outputPath: htmlPath)
                ProgressReporter.success("HTML report saved to: \(htmlPath)")
            } catch {
                ProgressReporter.error("Failed to generate HTML report: \(error)")
                throw error
            }
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
