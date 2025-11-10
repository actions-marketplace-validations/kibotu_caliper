import Foundation

/// Represents information about an asset from assetutil output
struct AssetInfo: Codable {
    let RenditionName: String?
    let SizeOnDisk: Int?
}

