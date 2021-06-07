import SwiftUI

struct AccountView: View {
	@ObservedObject var dataStore: ClientDataStore
	@EnvironmentObject private var assetManager: AssetManager
	
	var body: some View {
		ScrollView {
			VStack {
				if let user = dataStore.data?.user {
					VStack(spacing: 20) {
						(Text("Signed in as ") + Text(verbatim: user.name).fontWeight(.semibold))
							.font(.title2)
							.multilineTextAlignment(.center)
						
						Button("Sign Out") {
							dataStore.data = nil
						}
					}
				} else {
					LoginForm(data: $dataStore.data, credentials: .init(from: dataStore.keychain) ?? .init())
						.withLoadManager()
				}
				
				Spacer()
				
				if let progress = assetManager.progress {
					VStack {
						Text("\(progress.completed)/\(progress.total) Assets Downloaded…")
						
						ProgressView(value: progress.fractionComplete)
					}
					.padding()
				}
			}
			.padding(.top, 40)
		}
		.navigationTitle("Account")
		.withToolbar()
	}
}

#if DEBUG
struct AccountView_Previews: PreviewProvider {
	static var previews: some View {
		AccountView(dataStore: PreviewData.mockDataStore)
			.withPreviewAssets()
		
		AccountView(dataStore: PreviewData.emptyDataStore)
			.environmentObject(AssetManager.mockDownloading)
	}
}
#endif
