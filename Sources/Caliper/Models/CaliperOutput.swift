import Foundation

/// The complete output structure for Caliper reports
struct CaliperOutput: Codable {
    let appInfo: AppInfo?
    let modules: [String: ModuleSize]
    let totalPackageSize: Int64
    let totalInstallSize: Int64
    
    enum CodingKeys: String, CodingKey {
        case appInfo, modules, totalPackageSize, totalInstallSize
    }
}

