import Foundation

/// A simple data model used for testing and demonstration purposes.
///
/// Use ``DemoModel`` to represent a basic item with an identifier,
/// title, subtitle, and an associated image URL.
public struct DemoModel: Codable, Equatable, Sendable {
	/// The model’s unique identifier.
	public let id: UUID

	/// The primary title of the model.
	public var title: String

	/// A secondary subtitle describing the model.
	public var subtitle: String

	/// A URL pointing to an associated image.
	public var imageURL: URL

	/// Creates a new ``DemoModel`` with the given values.
	///
	/// - Parameters:
	///   - id: A unique identifier. Defaults to a newly generated UUID.
	///   - title: The primary title.
	///   - subtitle: A secondary subtitle describing the model.
	///   - imageURL: A URL pointing to an associated image.
	public init(id: UUID = UUID(), title: String, subtitle: String, imageURL: URL) {
		self.id = id
		self.title = title
		self.subtitle = subtitle
		self.imageURL = imageURL
	}
}
