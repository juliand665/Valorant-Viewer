import Foundation
import Combine
import HandyOperators

typealias LocalDataPublisher<Value> = AnyPublisher<(Value, wasCached: Bool), Never>

/// - "mom can we have a database?"
/// - "no honey we have a database at home"
/// - database at home:
final actor LocalDataManager<Object: Identifiable & Codable> where Object.ID: LosslessStringConvertible {
	private typealias Subject = PassthroughSubject<Object, Never>
	
	// not @Published so we have manual control, avoiding many publishes when working in bulk
	private var cache: [Object.ID: Entry?] = [:] // nil values represent that we've confirmed there's no cache file
	private var subjects: [Object.ID: Subject] = [:]
	
	let localPath: String
	/// When the object was last updated longer ago than this, it is automatically updated on next fetch.
	let ageCausingAutoUpdate: TimeInterval?
	
	init(localPath: String = "\(Object.self)", ageCausingAutoUpdate: TimeInterval? = nil) {
		self.localPath = localPath
		self.ageCausingAutoUpdate = ageCausingAutoUpdate
		
		try? fileManager.createDirectory(
			at: folderURL,
			withIntermediateDirectories: true,
			attributes: nil
		)
	}
	
	func store<S: Sequence>(_ objects: S, asOf updateTime: Date) where S.Element == Object {
		for object in objects {
			store(object, asOf: updateTime)
		}
	}
	
	func store(_ object: Object, asOf updateTime: Date) {
		let entry = Entry(lastUpdate: updateTime, object: object)
		let existing = cachedEntry(for: object.id)
		if let existing = existing, existing.lastUpdate > updateTime { return }
		
		cache[object.id] = entry
		print("publishing entry for \(object.id)")
		subjects[object.id]?.send(object)
		
		Task.detached(priority: .utility) {
			self.trySave(entry)
		}
	}
	
	private func cachedEntry(for id: Object.ID) -> Entry? {
		cache[id] ?? (tryLoadEntry(with: id) <- { cache[id] = $0 })
	}
	
	func cachedObject(for id: Object.ID) -> Object? {
		cachedEntry(for: id)?.object
	}
	
	nonisolated func objectPublisher(for id: Object.ID) -> LocalDataPublisher<Object> {
		Future { promise in
			Task {
				promise(.success(await self._objectPublisher(for: id)))
			}
		}
		.flatMap { $0 }
		.eraseToAnyPublisher()
	}
	
	private func _objectPublisher(for id: Object.ID) -> LocalDataPublisher<Object> {
		cachedObject(for: id).publisher.map { ($0, wasCached: true) }
			.merge(with: subject(for: id).map { ($0, wasCached: false) })
			.eraseToAnyPublisher()
	}
	
	private func subject(for id: Object.ID) -> Subject {
		subjects[id] ?? (.init() <- { subjects[id] = $0 })
	}
	
	func autoUpdateObject(for id: Object.ID, update: (Object?) async throws -> Object) async throws {
		let cached = cachedEntry(for: id)
		if let cached = cached, !shouldAutoUpdate(cached) {
			return // nothing to do
		}
		// auto-update necessary
		try await tryLoad {
			try await update(cached?.object) <- { store($0, asOf: .now) }
		}
	}
	
	func fetchIfNecessary(for id: Object.ID, fetch: (Object.ID) async throws -> Object) async throws {
		try await autoUpdateObject(for: id) { _ in try await fetch(id) }
	}
	
	func fetchIfNecessary(_ ids: [Object.ID], fetch: ([Object.ID]) async throws -> [Object]) async throws {
		let cached = ids.compactMap { cachedEntry(for: $0) }
		guard cached.count < ids.count || cached.contains(where: shouldAutoUpdate) else { return }
		try await fetch(ids) <- { store($0, asOf: .now) }
	}
	
	@discardableResult
	private nonisolated func tryLoad<T>(load: () async throws -> T) async throws -> T? {
		do {
			return try await load()
		} catch let error as URLError {
			// error loading data: assume offline
			dump(error)
			return nil
		}
	}
	
	private nonisolated var folderURL: URL {
		baseFolderURL.appendingPathComponent(localPath)
	}
	
	private nonisolated func fileURL(for id: Object.ID) -> URL {
		folderURL.appendingPathComponent("\(id.description).json")
	}
	
	private nonisolated func trySave(_ entry: Entry) {
		do {
			try save(entry)
		} catch {
			print("error saving \(entry) to disk: \(error)")
			dump(error)
		}
	}
	
	private func tryLoadEntry(with id: Object.ID) -> Entry? {
		do {
			return try loadEntry(with: id)
		} catch {
			print("error loading entry with id \(id) from disk: \(error)")
			dump(error)
			return nil
		}
	}
	
	private nonisolated func save(_ entry: Entry) throws {
		let raw = try encoder.encode(entry)
		let url = fileURL(for: entry.id)
		print("saving entry at \(url.path)")
		try raw.write(to: url)
	}
	
	private func loadEntry(with id: Object.ID) throws -> Entry? {
		let start = Date()
		defer {
			// TODO: yeah this is probably too long when loading many things at once…
			print("took \(-start.timeIntervalSinceNow * 1000) ms")
		}
		let url = fileURL(for: id)
		print("loading entry at \(url.path)")
		guard fileManager.fileExists(atPath: url.path) else { return nil }
		let data = try Data(contentsOf: url)
		return try decoder.decode(Entry.self, from: data)
	}
	
	private nonisolated func shouldAutoUpdate(_ entry: Entry) -> Bool {
		guard let threshold = ageCausingAutoUpdate else { return false }
		return -entry.lastUpdate.timeIntervalSinceNow > threshold
	}
	
	struct Entry: Codable, Identifiable {
		var lastUpdate = Date()
		var object: Object
		
		var id: Object.ID { object.id }
	}
}

private let decoder = JSONDecoder()
private let encoder = JSONEncoder()

private let fileManager = FileManager.default
private let baseFolderURL = try! fileManager.url(
	for: .cachesDirectory,
	in: .userDomainMask,
	appropriateFor: nil,
	create: true
)
.appendingPathComponent("local")

extension TimeInterval {
	static func minutes(_ minutes: Double) -> Self {
		minutes * 60
	}
	
	static func hours(_ hours: Double) -> Self {
		minutes(hours * 60)
	}
}
