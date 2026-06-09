@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	/// An endpoint handler that takes an incoming request and a response stream,
	/// and returns `Void` or throws an `HTTPError`.
	public typealias Endpoint = @Sendable (
		_ request: IncomingRequest,
		_ stream: ResponseStream.Block
	) async throws(HTTPError) -> Void

	/// An endpoint handler similar to `Endpoint` but with an additional
	/// `DatabaseMock` parameter for database interactions.
	public typealias DBEndpoint = @Sendable (
		_ request: IncomingRequest,
		_ dbMock: DatabaseMock,
		_ stream: ResponseStream.Block
	) async throws(HTTPError) -> Void
}
