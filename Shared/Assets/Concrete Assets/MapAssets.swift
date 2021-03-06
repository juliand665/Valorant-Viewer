import Foundation
import ValorantAPI

extension AssetClient {
	func getMapInfo() async throws -> [MapInfo] {
		try await send(MapInfoRequest())
	}
}

private struct MapInfoRequest: AssetRequest {
	let path = "/v1/maps"
	
	typealias Response = [MapInfo]
}

struct MapInfo: AssetItem, Codable, Identifiable {
	private var mapUrl: MapID
	var id: MapID { mapUrl } // lazy rename
	var displayName: String
	var coordinates: String?
	/// the minimap (also used for game event visualization)
	var displayIcon: AssetImage?
	/// a smaller icon used in-game for lists
	var listViewIcon: AssetImage
	var splash: AssetImage
	var assetPath: String
	var xMultiplier, yMultiplier: Double
	var xScalarToAdd, yScalarToAdd: Double
	
	var images: [AssetImage] {
		displayIcon
		listViewIcon
		splash
	}
}
