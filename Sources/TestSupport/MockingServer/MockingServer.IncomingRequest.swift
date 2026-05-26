import Foundation
import HTTPTypes

@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	public struct IncomingRequest: Sendable {
		public let path: Path
		public let method: Method

		public let headers: HTTPFields

		public let payload: Data?

		public init(path: Path, method: Method, headers: HTTPFields, payload: Data?) {
			self.path = path
			self.method = method
			self.headers = headers
			self.payload = payload
		}
	}
}
