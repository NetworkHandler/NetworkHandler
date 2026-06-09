import Foundation

/// A URL extension providing utilities for building test URLs and accessing mocked paths.
extension URL {
	/// Returns a new `URL` with the specified port.
	///
	/// The returned URL shares the same scheme, host, path, query, and other
	/// components as the original, except the port is replaced with `port`.
	///
	/// - Parameter port: The port number to assign to the returned URL.
	/// - Returns: A new `URL` instance with the given port.
	public func withPort(_ port: UInt16) -> URL {
		// swiftlint:disable force_unwrapping
		var components = URLComponents(url: self, resolvingAgainstBaseURL: true)!
		components.port = Int(port)
		return components.url!
		// swiftlint:enable force_unwrapping
	}

	/// Returns the mock server path derived from this URL's path components.
	///
	/// Drops the leading empty path component (if any) and wraps the remaining
	/// components in a `MockingServer.Path`. This is used to identify which
	/// mocked endpoint a request targets.
	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	public var mockingPath: MockingServer.Path {
		MockingServer.Path(rawValue: Array(pathComponents.dropFirst()))
	}
}
