@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	public typealias Endpoint = @Sendable (
		_ request: IncomingRequest,
		_ stream: ResponseStream.Block
	) async throws(HTTPError) -> Void

	public typealias DBEndpoint = @Sendable (
		_ request: IncomingRequest,
		_ dbMock: DatabaseMock,
		_ stream: ResponseStream.Block
	) async throws(HTTPError) -> Void
}
