import HTTPTypes
import NHMacros

@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	public struct OutboundResponseHeader: Sendable {
		public let responseCode: Int
		public let responseHeader: HTTPFields

		public init(responseCode: Int, responseHeader: HTTPFields? = nil) {
			self.responseCode = responseCode
			self.responseHeader = responseHeader ?? .init()
		}

		static func serverError(code: Int = 500, errorDescription: String? = nil) -> OutboundResponseHeader {
			self.init(
				responseCode: code,
				responseHeader: [#HTTPFieldName("Error"): errorDescription ?? "Internal error"])
		}
	}
}
