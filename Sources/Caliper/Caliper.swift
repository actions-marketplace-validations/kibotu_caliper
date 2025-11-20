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
    
    @Option(name: .long, help: "Optional YAML file containing package name mappings (for handling namespaced packages)")
    var packageMappingFile: String?
    
    // MARK: - Main Execution
    
    func run() throws {
        ProgressReporter.section("🔧 Initializing Caliper...")
        
        // Initialize services
        let (ipaService, appInfoService) = (IPAService(), AppInfoService())
        let (ipaParser, linkMapParser, packageResolvedParser) = (IPAParser(), LinkMapParser(), PackageResolvedParser())
        let (ownershipService, versionService, packageMappingService) = (OwnershipService(), VersionService(), PackageMappingService())
        let (sizeCalculator, jsonReporter, htmlReporter) = (SizeCalculator(), JSONReporter(), HTMLReporter())
        
        // Verify IPA exists
        ProgressReporter.message("Verifying IPA file: \(ipaPath)")
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
        
        // Extract app info
        ProgressReporter.section("📱 Extracting app information...")
        let appInfo = try? appInfoService.extractAppInfo(from: unzippedPath)
        appInfo?.appName.map { ProgressReporter.message("App Name: \($0)") }
        appInfo?.versionString.map { ProgressReporter.message("Version: \($0)") }
        appInfo?.bundleIdentifier.map { ProgressReporter.message("Bundle ID: \($0)") }
        
        // Load ownership configuration
        let (ownershipEntries, moduleMapping) = try loadOwnershipConfiguration(
            ownershipService: ownershipService
        )
        
        // Generate report from IPA
        ProgressReporter.section("📋 Analyzing IPA contents...")
        let report = try ipaParser.generateReport(ipaPath: ipaPath)
        
        // Build app size report
        var appSizeReport = try ipaParser.buildAppSizeReport(
            report: report,
            unzippedPath: unzippedPath,
            moduleMapping: moduleMapping
        )
        
        // Parse LinkMap if provided
        if let linkMapPath = linkMapPath {
            ProgressReporter.section("📊 Parsing LinkMap file...")
            ProgressReporter.message("LinkMap path: \(linkMapPath)")
            let linkMapDetails = try linkMapParser.parseDetailed(linkMapPath: linkMapPath)
            ProgressReporter.message("Found \(linkMapDetails.moduleSizes.count) modules in LinkMap")
            
            // Count total files
            let totalFiles = linkMapDetails.fileDetails.values.reduce(0) { $0 + $1.count }
            ProgressReporter.message("Found \(totalFiles) source files across all modules")
            
            ProgressReporter.message("Updating binary sizes...")
            sizeCalculator.updateBinarySizesDetailed(
                in: &appSizeReport,
                moduleMapping: moduleMapping,
                linkMapDetails: linkMapDetails
            )
            ProgressReporter.success("Binary sizes updated from LinkMap")
        }
        
        // Calculate total sizes
        ProgressReporter.section("📏 Calculating total sizes...")
        let totalSize = try sizeCalculator.calculateTotalSize(
            ipaPath: ipaPath,
            unzippedPath: unzippedPath
        )
        ProgressReporter.message("Total IPA size: \(totalSize.packageSize) bytes")
        ProgressReporter.message("Total install size: \(totalSize.installSize) bytes")
        
        // Parse Package.resolved if provided
        if let packageResolvedPath = packageResolvedPath {
            ProgressReporter.section("📦 Parsing Package.resolved file...")
            ProgressReporter.message("Package.resolved path: \(packageResolvedPath)")
            let versionMapping = try packageResolvedParser.parse(path: packageResolvedPath)
            ProgressReporter.message("Found \(versionMapping.count) package versions")
            
            // Load package name mapping if provided
            let packageNameMapping: [String: String]? = try packageMappingFile.map { mappingPath in
                ProgressReporter.section("🔗 Loading package name mappings...")
                ProgressReporter.message("Mapping file: \(mappingPath)")
                let mappings = try packageMappingService.loadMappingFile(from: mappingPath)
                let dict = packageMappingService.buildMappingDictionary(from: mappings)
                ProgressReporter.message("Loaded \(dict.count) package name mappings")
                return dict
            }
            
            ProgressReporter.message("Assigning versions to modules...")
            versionService.assignVersions(
                to: appSizeReport,
                using: versionMapping,
                packageNameMapping: packageNameMapping
            )
            ProgressReporter.success("Package versions assigned")
        }
        
        // Assign owners to modules
        if !ownershipEntries.isEmpty {
            ProgressReporter.section("👥 Assigning module ownership...")
            ProgressReporter.message("Using \(ownershipEntries.count) ownership rules")
            ownershipService.assignOwners(to: appSizeReport, using: ownershipEntries)
            ProgressReporter.success("Module ownership assigned")
        }
        
        // Automatically tag the app module as internal with owner 'App'
        ownershipService.tagAppModule(in: appSizeReport, appInfo: appInfo)
        
        // Generate JSON output (always to report.json)
        ProgressReporter.section("Generating JSON output...")
        let jsonOutputPath = "report.json"
        let jsonString = try jsonReporter.generate(
            appInfo: appInfo,
            modules: appSizeReport,
            totalSize: totalSize,
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
        return (entries, [:])  // Empty mapping - ownership is assigned via pattern matching, not renaming
    }
}
