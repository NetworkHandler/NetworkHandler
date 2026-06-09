import Foundation
import HTTPTypes

@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	/// Represents an incoming HTTP request to the mock server.
	public struct IncomingRequest: Sendable {
		/// The request path segments.
		public let path: Path

		/// The HTTP method (e.g. GET, POST).
		public let method: Method

		/// The request headers.
		public let headers: HTTPFields

		/// The request body payload, if any.
		public let payload: Data?

		/// Create an incoming request instance.
		public init(path: Path, method: Method, headers: HTTPFields, payload: Data?) {
			self.path = path
			self.method = method
			self.headers = headers
			self.payload = payload
		}
	}
}
