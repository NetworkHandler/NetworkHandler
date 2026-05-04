import Foundation
import NetworkHandler
import HTTPTypes
import Logging

extension EngineResponseHeader {
	private static let log = Logger(label: "Engine Response Handler from URLResponse")

	public init(from response: URLResponse) {
		let headers: HTTPFields
		let statusCode: Int
		if let httpResponse = response as? HTTPURLResponse {
			let headerList = httpResponse.allHeaderFields.compactMap { (name, value) -> HTTPField? in
				guard
					let stringName = name as? String,
					let stringValue = value as? String,
					let fieldName = HTTPField.Name(stringName)
				else {
					Self.log.warning("Error: Could not create semantic HTTPField.Name from \(name)")
					return nil
				}
				return HTTPField(name: fieldName, value: stringValue)
			}
			headers = HTTPFields(headerList)
			statusCode = httpResponse.statusCode
		} else {
			let field = HTTPField(name: .init("ERROR")!, value: "Invalid response object - Not an HTTPURLResponse")
			headers = HTTPFields([field])
			statusCode = -1
		}

		self.init(status: statusCode, url: response.url, headers: headers)
	}
}
