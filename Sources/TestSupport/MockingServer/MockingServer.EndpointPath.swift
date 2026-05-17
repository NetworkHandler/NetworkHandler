@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	struct EndpointPath: Hashable {
		let path: Path
		let method: Method
	}
}
