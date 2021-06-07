import SwiftUI
import SwiftUIMissingPieces
import Combine
import UserDefault
import HandyOperators

class LoadManager: ObservableObject {
	@Published private var loadTask: AnyCancellable?
	@Published fileprivate var loadError: PresentedError?
	
	var isLoading: Bool {
		loadTask != nil
	}
	
	init() {}
	
	#if DEBUG
	static let mockLoading = LoadManager() <- {
		$0.loadTask = Future { _ in } // never completes
			.sink {}
	}
	#endif
	
	func runTask<P: Publisher>(
		_ task: P,
		onSuccess: @escaping (P.Output) -> Void
	) {
		loadTask = task
			.receive(on: DispatchQueue.main)
			.sinkResult(
				onSuccess: onSuccess,
				onFailure: { self.loadError = .init($0) },
				always: { self.loadTask = nil }
			)
	}
}

extension View {
	func withLoadManager() -> some View {
		withLoadManager(LoadManager())
	}
	
	func withLoadManager<Manager: LoadManager>(_ manager: Manager) -> some View {
		LoadWrapper(loadManager: manager) { self }
	}
}

private struct LoadWrapper<Content: View, Manager: LoadManager>: View {
	@StateObject var loadManager: Manager
	@ViewBuilder let content: () -> Content
	@State private var errorTitle = "Error loading data!"
	
	var body: some View {
		content()
			.onPreferenceChange(LoadErrorTitleKey.self) {
				errorTitle = $0 ?? errorTitle
			}
			.environmentObject(loadManager)
			.alert(item: $loadManager.loadError) { error in
				Alert(
					title: Text(errorTitle),
					message: Text(verbatim: error.error.localizedDescription),
					dismissButton: .default(Text("OK"))
				)
			}
	}
}

private enum LoadErrorTitleMarker {}
private typealias LoadErrorTitleKey = SimplePreferenceKey<LoadErrorTitleMarker, String>

extension View {
	func loadErrorTitle(_ title: String) -> some View {
		preference(key: LoadErrorTitleKey.self, value: title)
	}
}

private struct PresentedError: Identifiable {
	let id = UUID()
	
	let error: Error
	
	init(_ error: Error) {
		self.error = error
	}
}