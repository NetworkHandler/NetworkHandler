import AsyncHTTPClient
import HTTPTypes
import NetworkHandler
import NIOCore

extension UploadEngineRequest {
	public var httpClientFutureRequest: HTTPClient.Request {
		get throws {
			try HTTPClient.Request(
				url: self.url,
				method: .init(rawValue: self.method.rawValue),
				headers: .init(self.headers.map { ($0.name.rawName, $0.value) }),
				body: nil)
		}
	}
}
