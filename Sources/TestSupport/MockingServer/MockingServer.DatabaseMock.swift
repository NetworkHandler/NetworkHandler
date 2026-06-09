import Foundation

@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	/// A in-memory key-value store for mock server responses.
	///
	/// Provides a way to store and retrieve `Codable` values as `Data`
	/// using string keys. Used by ``MockingServer/DBEndpoint`` handlers
	/// to resolve mock responses dynamically.
	public actor DatabaseMock {
		/// The underlying key-value store mapping string keys to `Data` values.
		public private(set) var store: [String: Data] = [:]

		private static let encoder = JSONEncoder()
		private static let decoder = JSONDecoder()

		/// Encodes `value` as JSON data and stores it under `key`.
		///
		/// - Parameters:
		///     - value: A `Codable & Sendable` value to encode and store.
		///     - key: The string key under which to store the encoded data.
		public func set<Value: Codable & Sendable>(_ value: Value, for key: String) {
			let data = try? Self.encoder.encode(value)

			store[key] = data
		}

		/// Returns the `Codable` value stored under `key`, or `nil` if no value exists.
		///
		/// - Parameter key: The string key for the stored value.
		/// - Returns: The decoded value, or `nil` if the key does not exist or decoding fails.
		public func get<Value: Codable & Sendable>(for key: String) -> Value? {
			guard let data = store[key] else { return nil }

			return try? Self.decoder.decode(Value.self, from: data)
		}
	}
}
