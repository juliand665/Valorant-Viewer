import SwiftUI
import ValorantAPI
import Algorithms

extension AssetClient {
	func getSeasons() async throws -> SeasonCollection {
		async let seasons = send(SeasonRequest())
		async let compSeasons = send(CompetitiveSeasonRequest())
		async let compTiers = send(CompetitiveTierRequest())
		return try await SeasonCollection(
			seasons: seasons,
			compSeasons: compSeasons,
			compTiers: compTiers
		)
	}
}

private struct SeasonRequest: AssetRequest {
	let path = "/v1/seasons"
	
	typealias Response = [SeasonInfo]
}

private struct CompetitiveSeasonRequest: AssetRequest {
	let path = "/v1/seasons/competitive"
	
	typealias Response = [CompetitiveSeasonInfo]
}

private struct CompetitiveTierRequest: AssetRequest {
	let path = "/v1/competitivetiers"
	
	typealias Response = [CompetitiveTier.Collection]
}

private extension SeasonCollection {
	init(
		seasons: [SeasonInfo],
		compSeasons: [CompetitiveSeasonInfo],
		compTiers: [CompetitiveTier.Collection]
	) {
		let seasonsByID = Dictionary(values: seasons)
		
		episodesInOrder = compSeasons.filter { $0.borders == nil }.map { compSeason in
			let season = seasonsByID[compSeason.seasonID]!
			
			return Episode(
				id: season.id,
				name: season.displayName,
				timeSpan: .init(start: season.startTime, end: season.endTime)
			)
		}
		episodes = .init(values: episodesInOrder)
		
		actsInOrder = compSeasons.compactMap { [episodes] compSeason in
			guard let borders = compSeason.borders else { return nil } // skip episode definitions
			
			let season = seasonsByID[compSeason.seasonID]!
			let episode = season.parent.map { episodes[$0]! }
			
			return Act(
				id: season.id,
				name: season.displayName,
				timeSpan: .init(start: season.startTime, end: season.endTime),
				episode: episode,
				borders: borders,
				competitiveTiers: compSeason.tierCollectionID
			)
		}
		acts = .init(values: actsInOrder)
		
		competitiveTiers = .init(values: compTiers)
		assert(Set(competitiveTiers.keys) == Set(actsInOrder.map(\.competitiveTiers)))
	}
}

private struct SeasonInfo: Identifiable, Codable {
	var id: Season.ID
	var parent: Season.ID?
	var displayName: String
	var startTime, endTime: Date
	
	private enum CodingKeys: String, CodingKey {
		case id = "uuid"
		case parent = "parentUuid"
		case displayName
		case startTime, endTime
	}
}

private struct CompetitiveSeasonInfo: Codable {
	var id: ObjectID<Self, LowercaseUUID>
	var seasonID: Season.ID
	var tierCollectionID: CompetitiveTier.Collection.ID
	var startTime, endTime: Date
	var borders: [ActRankBorder]?
	
	private enum CodingKeys: String, CodingKey {
		case id = "uuid"
		case startTime, endTime
		case tierCollectionID = "competitiveTiersUuid"
		case seasonID = "seasonUuid"
		case borders
	}
}
