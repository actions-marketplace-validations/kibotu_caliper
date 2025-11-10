import Foundation

/// Errors that can occur during Caliper execution
enum CaliperError: Error {
    case unzipFailed
    case invalidIPA
    case invalidOwnershipFile
    case invalidOutput
    case linkMapParsingFailed(String)
    case assetCatalogParsingFailed(String)
}

extension CaliperError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unzipFailed:
            return "Failed to unzip IPA file"
        case .invalidIPA:
            return "Invalid IPA file"
        case .invalidOwnershipFile:
            return "Invalid ownership configuration file"
        case .invalidOutput:
            return "Failed to generate output"
        case .linkMapParsingFailed(let reason):
            return "Failed to parse LinkMap: \(reason)"
        case .assetCatalogParsingFailed(let reason):
            return "Failed to parse asset catalog: \(reason)"
        }
    }
}

