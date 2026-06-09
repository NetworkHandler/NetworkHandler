@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	/// Thrown when a mocking server encounters an HTTP error during request handling.
	public struct HTTPError: Error {
		/// The HTTP status code associated with this error.
		public let code: Int

		/// A human-readable description of the error.
		public let errorDescription: String?

		/// Creates a new HTTP error.
		/// - Parameters:
		///   - code: The HTTP status code. Defaults to `500`.
		///   - errorDescription: An optional human-readable description.
		public init(code: Int = 500, errorDescription: String? = nil) {
			self.code = code
			self.errorDescription = errorDescription
		}

		/// Captures errors from an async throwing closure, converting any errors to `HTTPError`
		/// If an error is already HTTPError, it's forwarded. Timeouts and cancellations are detected and converted accordingly.
		/// - Parameter throwing: The async closure that may throw.
		/// - Returns: The result of the closure.
		/// - Throws: `HTTPError` if an error occurs, or the original error wrapped.
		public static func capture<T>(_ throwing: () async throws -> T) async throws(HTTPError) -> T {
			do {
				return try await throwing()
			} catch {
				return try capture { throw error }
			}
		}

		/// Captures errors from a throwing closure, converting any errors to `HTTPError`.
		/// If an error is already HTTPError, it's forwarded. Timeouts and cancellations are detected and converted accordingly.
		/// - Parameter throwing: The closure that may throw.
		/// - Returns: The result of the closure.
		/// - Throws: `HTTPError` for timeouts, cancellations, or unexpected errors.
		public static func capture<T>(_ throwing: () throws -> T) throws(HTTPError) -> T {
			do {
				return try throwing()
			} catch let error as HTTPError {
				throw error
			} catch {
				if error.isTimeout() {
					throw HTTPError(errorDescription: "Server timeout")
				}
				if error.isCancellation() {
					throw HTTPError(errorDescription: "Server cancellation")
				}

				throw HTTPError(errorDescription: "Unexpected error: \(error)")
			}
		}
	}
}
