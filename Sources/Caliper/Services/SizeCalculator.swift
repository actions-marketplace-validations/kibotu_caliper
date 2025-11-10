import Foundation

/// Service for calculating sizes of files and directories
struct SizeCalculator {
    private let fileManager = FileManager.default
    
    /// Calculate total package and install sizes
    func calculateTotalSize(
        ipaPath: String,
        unzippedPath: String
    ) throws -> (packageSize: Int64, installSize: Int64) {
        // Package size (compressed IPA)
        let ipaURL = URL(fileURLWithPath: ipaPath)
        let attributes = try fileManager.attributesOfItem(atPath: ipaURL.path)
        let packageSize = attributes[.size] as? Int64 ?? 0
        
        // Install size (uncompressed)
        let installSize = try directorySize(at: unzippedPath)
        
        return (packageSize, installSize)
    }
    
    /// Calculate the total size of a directory recursively
    func directorySize(at path: String) throws -> Int64 {
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
    
    /// Update binary sizes from LinkMap data
    func updateBinarySizes(
        in appSizeReport: inout [String: ModuleSize],
        moduleMapping: [String: String],
        moduleSizes: [String: Int64]
    ) {
        // First pass: Update all modules found in LinkMap
        for (moduleName, size) in moduleSizes {
            // Skip synthetic "other" module
            if moduleName == "other" {
                continue
            }
            
            if let existingModule = appSizeReport[moduleName] {
                // If the old binarySize was 0, it means no binary was found during IPA parsing
                // (e.g., statically linked modules with only resource bundles).
                // In this case, we need to ADD the binary size to proguard.
                if existingModule.binarySize == 0 {
                    existingModule.proguard += size
                }
                // Update binary size with accurate LinkMap data
                existingModule.binarySize = size
            } else {
                // Create new module from LinkMap (for statically linked modules without bundles)
                let newModule = ModuleSize(name: moduleName)
                newModule.binarySize = size
                newModule.proguard = size
                appSizeReport[moduleName] = newModule
            }
        }
        
        // Second pass: Handle module mappings
        for (originalName, mappedName) in moduleMapping {
            if let size = moduleSizes[originalName],
               let moduleSize = appSizeReport[mappedName] {
                // If the old binarySize was 0, add to proguard
                if moduleSize.binarySize == 0 {
                    moduleSize.proguard += size
                }
                // Update binary size with the mapped value
                moduleSize.binarySize = size
            }
        }
    }
    
    /// Update binary sizes with detailed file information from LinkMap
    func updateBinarySizesDetailed(
        in appSizeReport: inout [String: ModuleSize],
        moduleMapping: [String: String],
        linkMapDetails: LinkMapDetails
    ) {
        // First update basic binary sizes
        updateBinarySizes(
            in: &appSizeReport,
            moduleMapping: moduleMapping,
            moduleSizes: linkMapDetails.moduleSizes
        )
        
        // Then add file-level details
        for (moduleName, files) in linkMapDetails.fileDetails {
            // Skip synthetic "other" module
            if moduleName == "other" {
                continue
            }
            
            if let moduleSize = appSizeReport[moduleName] {
                // Add file sizes to the module
                for (fileName, size) in files {
                    moduleSize.addFileSize(fileName: fileName, size: size)
                }
                // Finalize to keep only top 50 files
                moduleSize.finalizeFiles()
            }
        }
        
        // Handle module mappings for file details
        for (originalName, mappedName) in moduleMapping {
            if let files = linkMapDetails.fileDetails[originalName],
               let moduleSize = appSizeReport[mappedName] {
                // Add file sizes from mapped module
                for (fileName, size) in files {
                    moduleSize.addFileSize(fileName: fileName, size: size)
                }
                // Finalize to keep only top 50 files
                moduleSize.finalizeFiles()
            }
        }
    }
}

