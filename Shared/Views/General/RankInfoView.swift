import SwiftUI
import ValorantAPI
import HandyOperators

struct RankInfoView: View {
	let summary: CareerSummary?
	var dataOverride: CareerSummary.SeasonInfo?
	
	var lineWidth = 4.0
	var shouldShowProgress = true
	var shouldFadeUnranked = false
	var shouldFallBackOnPrevious = true
	
	@Environment(\.assets) private var assets
	
	var body: some View {
		let thickerWidth = lineWidth * 1.5
		let backgroundCircle = Circle().padding(-0.5 * thickerWidth)
		
		ZStack {
			if let summary = summary {
				let act = assets?.seasons.currentAct()
				let info = summary.competitiveInfo?.inSeason(act?.id)
				let tier = info?.competitiveTier ?? 0
				let tierInfo = assets?.seasons.tierInfo(number: tier, in: act)
				
				let previousAct = assets?.seasons.actBefore(act)
				let previousInfo = summary.competitiveInfo?.inSeason(previousAct?.id)
				
				if shouldShowProgress {
					progressView(for: tierInfo, rankedRating: info?.rankedRating ?? 0)
				}
				
				Group {
					if shouldFallBackOnPrevious, tier == 0, let info = previousInfo {
						previousActIcon(using: CompetitiveTierImage(tier: info.competitiveTier, act: previousAct))
					} else {
						CompetitiveTierImage(tierInfo: tierInfo)
							.opacity(shouldFadeUnranked && tier == 0 ? 0.5 : 1)
					}
				}
				.scaleEffect(shouldShowProgress ? 0.75 : 1)
			} else if let info = dataOverride {
				let tierInfo = assets?.seasons.tierInfo(number: info.competitiveTier, in: info.seasonID)
				
				if shouldShowProgress {
					progressView(for: tierInfo, rankedRating: info.rankedRating)
				}
				
				CompetitiveTierImage(tierInfo: tierInfo)
					.opacity(shouldFadeUnranked && info.competitiveTier == 0 ? 0.5 : 1)
					.scaleEffect(shouldShowProgress ? 0.75 : 1)
			} else {
				backgroundCircle.foregroundColor(.black.opacity(0.1))
			}
		}
		.aspectRatio(1, contentMode: .fit)
		.padding(lineWidth)
	}
	
	@ViewBuilder
	func progressView(for tierInfo: CompetitiveTier?, rankedRating: Int) -> some View {
		let darkening = 0.25
		
		CircularProgressView(
			lineWidth: lineWidth,
			background: {
				ZStack {
					tierInfo?.backgroundColor
					Color.black.opacity(darkening).blendMode(.plusDarker)
				}
			},
			base: { Color.white.opacity(darkening).blendMode(.plusLighter) },
			layers: {
				CircularProgressLayer(
					end: CGFloat(rankedRating) / 100,
					shouldKnockOutSurroundings: true,
					color: .white, opacity: 0.5, blendMode: .plusLighter
				)
			}
		)
	}
	
	@ViewBuilder
	func previousActIcon(using image: CompetitiveTierImage) -> some View {
		ZStack {
			image
			
			GeometryReader { geometry in
				Image(systemName: "clock")
					.font(.system(size: geometry.size.width * 0.3).weight(.bold))
					.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
					.foregroundColor(.white)
					.shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
			}
		}
		.compositingGroup()
		.opacity(0.75)
	}
}

#if DEBUG
struct RankInfoView_Previews: PreviewProvider {
	static let assets = AssetManager.forPreviews.assets!
	static let act = assets.seasons.currentAct()!
	static let ranks = assets.seasons.competitiveTiers[act.competitiveTiers]!
	
	private static func summary(forTier tier: Int) -> CareerSummary {
		PreviewData.summary <- {
			$0.competitiveInfo!.bySeason![act.id]!.competitiveTier = tier
		}
	}
	
	static var previews: some View {
		Group {
			HStack {
				RankInfoView(summary: PreviewData.summary, shouldShowProgress: false)
				RankInfoView(summary: PreviewData.summary <- { $0.infoByQueue = [:] })
				RankInfoView(summary: summary(forTier: 0), shouldFallBackOnPrevious: false)
				RankInfoView(summary: summary(forTier: 0), shouldFallBackOnPrevious: true)
				RankInfoView(summary: nil)
			}
			.fixedSize(horizontal: true, vertical: false)
			.frame(height: 64)
			
			RankInfoView(summary: summary(forTier: 0))
				.inEachColorScheme()
				.frame(height: 64)
			
			RankInfoView(summary: PreviewData.summary, lineWidth: 8)
				.frame(width: 128, height: 128)
			
			LazyHGrid(rows: [.init(), .init(), .init()], spacing: 20) {
				ForEach(ranks.tiers.values.map(\.number).sorted(), id: \.self) {
					// this would be equivalent, but i want to test this overload too
					//RankInfoView(summary: summary(forTier: $0), shouldFallBackOnPrevious: false)
					RankInfoView(summary: nil, dataOverride: .init(
						seasonID: act.id,
						actRank: $0,
						competitiveTier: $0,
						rankedRating: 69
					))
				}
				.frame(width: 64)
			}
			.padding()
			.frame(height: 250)
			.inEachColorScheme()
		}
		.previewLayout(.sizeThatFits)
	}
}
#endif
