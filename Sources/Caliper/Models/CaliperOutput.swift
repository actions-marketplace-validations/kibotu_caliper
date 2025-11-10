import Foundation

/// The complete output structure for Caliper reports
struct CaliperOutput: Codable {
    let modules: [String: ModuleSize]
    let totalPackageSize: Int64
    let totalInstallSize: Int64
    let modulesByOwner: [String: [String: ModuleSize]]?
    
    enum CodingKeys: String, CodingKey {
        case modules, totalPackageSize, totalInstallSize, modulesByOwner
    }
}

