@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	public struct HTTPError: Error {
		public let code: Int
		public let errorDescription: String?

		public init(code: Int = 500, errorDescription: String? = nil) {
			self.code = code
			self.errorDescription = errorDescription
		}

		public static func capture<T>(_ throwing: () async throws -> T) async throws(HTTPError) -> T {
			do {
				return try await throwing()
			} catch {
				return try capture { throw error }
			}
		}

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
