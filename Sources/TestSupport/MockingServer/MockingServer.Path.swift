@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	/// A path for a mock server endpoint.
	///
	/// Represents an HTTP request path as an array of string segments. Supports
	/// initialization from an array of strings, an array literal, or a string
	/// literal with slash-separated segments.
	public struct Path:
		RawRepresentable,
		Sendable,
		Hashable,
		ExpressibleByArrayLiteral,
		ExpressibleByStringLiteral,
		ExpressibleByStringInterpolation {

		/// The path segments as an array of strings.
		public var rawValue: [String]

		/// Creates a new ``Path`` from an array of string segments.
		///
		/// - Parameter rawValue: An array of path segments.
		public init(rawValue: [String]) {
			self.rawValue = rawValue
		}

		/// Creates a new ``Path`` from an array of string elements.
		///
		/// - Parameter elements: The string elements to use as path segments.
		public init(arrayLiteral elements: String...) {
			self.init(rawValue: elements)
		}

		/// Creates a new ``Path`` from a string literal.
		///
		/// The string is split by `/` to produce the path segments. For example,
		/// `"/users/123"` produces `["users", "123"]`.
		///
		/// IMPORTANT: Multiple sequential `/` are consolidated as if they were a
		/// single `/`, so `/foo///bar` resolves to `["foo", "bar"]`
		///
		/// - Parameter value: A string containing slash-separated path segments.
		public init(stringLiteral value: String) {
			let path = value.split(separator: "/").map(String.init)
			self.init(rawValue: path)
		}
	}
}
