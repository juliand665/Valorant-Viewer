import SwiftUI
import ValorantAPI
import HandyOperators

struct UserView: View {
	@State private var matchList: MatchList
	@State private var shouldShowUnranked = true
	
	@Environment(\.valorantLoad) private var load
	
	init(for user: User) {
		_matchList = .init(wrappedValue: .init(user: user))
	}
	
	var body: some View {
		MatchListView(matchList: $matchList, shouldShowUnranked: $shouldShowUnranked)
			.navigationBarTitleDisplayMode(.large)
	}
}

struct MatchListView: View {
	@Binding var matchList: MatchList
	@Binding var shouldShowUnranked: Bool
	
	@Environment(\.valorantLoad) private var load
	
	private var shownMatches: [CompetitiveUpdate] {
		shouldShowUnranked
			? matchList.matches
			: matchList.matches.filter(\.isRanked)
	}
	
	var body: some View {
		List {
			ForEach(shownMatches, id: \.id) {
				MatchCell(match: $0, userID: matchList.user.id)
			}
			
			if matchList.canLoadOlderMatches {
				Button(role: nil) {
					await updateMatchList(update: ValorantClient.loadOlderMatches)
				} label: {
					Label("Load Older Matches", systemImage: "ellipsis")
				}
			}
		}
		.toolbar {
			Button(shouldShowUnranked ? "Hide Unranked" : "Show Unranked") {
				withAnimation { shouldShowUnranked.toggle() }
			}
		}
		.task {
			if matchList.matches.isEmpty {
				await loadMatches()
			}
		}
		.refreshable(action: loadMatches)
		.loadErrorAlertTitle("Could not load matches!")
		.navigationTitle(matchList.user.name)
	}
	
	func loadMatches() async {
		await updateMatchList(update: ValorantClient.loadMatches)
	}
	
	func updateMatchList(update: @escaping (ValorantClient) -> (inout MatchList) async throws -> Void) async {
		await load { client in
			let updater = update(client)
			let updated = try await matchList <- { try await updater(&$0) }
			withAnimation { matchList = updated }
		}
	}
}

#if DEBUG
struct MatchListView_Previews: PreviewProvider {
	static var previews: some View {
		MatchListView(matchList: .constant(PreviewData.matchList), shouldShowUnranked: .constant(true))
			.withToolbar()
			//.inEachColorScheme()
			.listStyle(.grouped)
	}
}
#endif