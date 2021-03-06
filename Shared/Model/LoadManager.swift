import SwiftUI
import SwiftUIMissingPieces
import UserDefault
import HandyOperators

extension View {
	func withLoadErrorAlerts() -> some View {
		LoadWrapper { self }
	}
}

extension View {
	func loadErrorAlertTitle(_ title: String) -> some View {
		preference(key: LoadErrorTitleKey.self, value: title)
	}
}

private struct LoadWrapper<Content: View>: View {
	@ViewBuilder let content: () -> Content
	@State private var loadError: PresentedError?
	@State private var errorTitle = ""
	
	var body: some View {
		content()
			.onPreferenceChange(LoadErrorTitleKey.self) {
				errorTitle = $0
			}
			.environment(\.loadWithErrorAlerts, runTask)
			.alert(item: $loadError) { error in
				Alert(
					title: Text(errorTitle),
					message: Text(verbatim: error.error.localizedDescription),
					dismissButton: .default(Text("OK"))
				)
			}
	}
	
	func runTask(_ task: () async throws -> Void) async {
		do {
			try await task()
		} catch {
			guard !Task.isCancelled else { return }
			loadError = .init(error)
		}
	}
}

private struct LoadErrorTitleKey: PreferenceKey {
	static let defaultValue = "Error loading data!"
	
	static func reduce(value: inout String, nextValue: () -> String) {
		value = nextValue()
	}
}

extension EnvironmentValues {
	typealias LoadTask = () async throws -> Void
	
	/// Executes some remote loading operation, handling any errors by displaying a dismissable alert.
	var loadWithErrorAlerts: (@escaping LoadTask) async -> Void {
		get { self[Key.self] }
		set { self[Key.self] = newValue }
	}
	
	private struct Key: EnvironmentKey {
		static let defaultValue: (@escaping LoadTask) async -> Void = { _ in
			guard !isInSwiftUIPreview else { return }
			fatalError("no load function provided in environment!")
		}
	}
}

private struct PresentedError: Identifiable {
	let id = UUID()
	
	let error: Error
	
	init(_ error: Error) {
		self.error = error
	}
}
