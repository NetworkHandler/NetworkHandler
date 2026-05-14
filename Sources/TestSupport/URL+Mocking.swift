import Foundation

extension URL {
	public func withPort(_ port: UInt16) -> URL {
		// swiftlint:disable force_unwrapping
		var components = URLComponents(url: self, resolvingAgainstBaseURL: true)!
		components.port = Int(port)
		return components.url!
		// swiftlint:enable force_unwrapping
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	public var mockingPath: MockingServer.Path {
		MockingServer.Path(rawValue: Array(pathComponents.dropFirst()))
	}
}
