import Foundation

/// A simple test fixture struct for use in tests.
///
/// Conforms to `Codable`, `Equatable`, and `Sendable` for use in
/// serialization, comparison, and concurrent test scenarios.
public struct DummyType: Codable, Equatable, Sendable {
	/// A unique identifier for the dummy type.
	public let id: Int
	/// A string value for test purposes.
	public let value: String
	/// A numeric value for test purposes.
	public let other: Double

	/// Creates a new dummy type with the given values.
	/// - Parameters:
	///   - id: A unique identifier.
	///   - value: A string value.
	///   - other: A numeric value.
	public init(id: Int, value: String, other: Double) {
		self.id = id
		self.value = value
		self.other = other
	}
}
