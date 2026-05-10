import AsyncHTTPClient
import NetworkHandler
import NIOCore

extension NetworkRequest {
	var httpClientRequest: HTTPClientRequest {
		var request = HTTPClientRequest(url: self.url.absoluteURL.absoluteString)
		request.method = .init(rawValue: self.method.rawValue)
		request.headers = .init(self.headers.map { ($0.name.rawName, $0.value) })

		if let payload {
			request.body = .bytes(ByteBuffer(bytes: payload))
		}

		return request
	}

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
