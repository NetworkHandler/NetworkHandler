import NetworkHandler
import AsyncHTTPClient
import Foundation
import NIOHTTP1
import HTTPTypes
import Logging

extension EngineResponseHeader {
	private static let log = Logger(label: "Async Engine Response")

	public init(from response: HTTPClientResponse, with url: URL) {
		let statusCode = Int(response.status.code)
		let headerList = response.headers.compactMap { (name, value) -> HTTPField? in
			guard let fieldName = HTTPField.Name(name) else {
				Self.log.warning("Error: Could not create semantic HTTPField.Name from \(name)")
				return nil
			}
			return HTTPField(name: fieldName, value: value)
		}
		let headers = HTTPFields(headerList)

		self.init(status: statusCode, url: url, headers: headers)
	}
}

extension HTTPClientResponse {
	public init(from response: HTTPResponseHead) {
		self.init(
			version: response.version,
			status: response.status,
			headers: response.headers,
			body: .init())
	}
}
