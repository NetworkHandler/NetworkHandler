import Foundation

@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	public actor DatabaseMock {
		public private(set) var store: [String: Data] = [:]

		private static let encoder = JSONEncoder()
		private static let decoder = JSONDecoder()

		public func set<Value: Codable & Sendable>(_ value: Value, for key: String) {
			let data = try? Self.encoder.encode(value)

			store[key] = data
		}

		public func get<Value: Codable & Sendable>(for key: String) -> Value? {
			guard let data = store[key] else { return nil }

			return try? Self.decoder.decode(Value.self, from: data)
		}
	}
}
