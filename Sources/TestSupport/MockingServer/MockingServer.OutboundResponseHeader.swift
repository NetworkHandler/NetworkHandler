import HTTPTypes
import NHMacros

@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	/// An HTTP response header for a mock server.
	///
	/// Wraps a status code and optional HTTP fields to construct outbound
	/// responses from the mock server.
	public struct OutboundResponseHeader: Sendable {
		/// The HTTP status code for the response (e.g., 200, 404, 500).
		public let responseCode: Int

		/// Optional HTTP fields for headers such as Content-Type, Content-Length, etc.
		public let responseHeader: HTTPFields

		/// Creates a new ``OutboundResponseHeader`` with the given `responseCode` and optional `responseHeader`.
		///
		/// - Parameters:
		///     - responseCode: The HTTP status code.
		///     - responseHeader: Optional HTTP fields for response headers. Defaults to an empty `HTTPFields`.
		public init(responseCode: Int, responseHeader: HTTPFields? = nil) {
			self.responseCode = responseCode
			self.responseHeader = responseHeader ?? .init()
		}

		/// Creates an error response header.
		///
		/// - Parameters:
		///     - code: The HTTP error code. Defaults to `500`.
		///     - errorDescription: An optional error description to include as an `"Error"` header.
		/// - Returns: An ``OutboundResponseHeader`` configured as a server error response.
		static func serverError(code: Int = 500, errorDescription: String? = nil) -> OutboundResponseHeader {
			self.init(
				responseCode: code,
				responseHeader: [#HTTPFieldName("Error"): errorDescription ?? "Internal error"])
		}
	}
}
