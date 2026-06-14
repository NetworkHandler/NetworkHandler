import Foundation
import NetworkHandler

extension NetworkRequest {
	/// Creates a configured `URLRequest` from this `NetworkRequest`.
	///
	/// - Parameter uploadFlag: When `false`, the request body is set from the
	///   payload. When `true`, the body is left unset (suitable for uploads).
	/// - Returns: A fully configured `URLRequest` with headers, method, timeout,
	///   and derived request properties applied.
	package func urlRequest(forUpload uploadFlag: Bool) -> URLRequest {
		var new = URLRequest(url: self.url)
		for header in self.headers {
			new.addValue(header.value, forHTTPHeaderField: header.name.rawName)
		}
		new.httpMethod = self.method.rawValue

		if uploadFlag == false {
			new.httpBody = payload
		}
		new.timeoutInterval = self.timeoutInterval

		let storedRequest = self.derivedURLRequest

		new.cachePolicy = storedRequest.cachePolicy
		new.mainDocumentURL = storedRequest.mainDocumentURL
		new.httpShouldHandleCookies = storedRequest.httpShouldHandleCookies
		new.httpShouldUsePipelining = storedRequest.httpShouldUsePipelining
		new.allowsCellularAccess = storedRequest.allowsCellularAccess
		new.allowsConstrainedNetworkAccess = storedRequest.allowsConstrainedNetworkAccess
		new.allowsExpensiveNetworkAccess = storedRequest.allowsExpensiveNetworkAccess
		new.networkServiceType = storedRequest.networkServiceType
		new.attribution = storedRequest.attribution
		if #available(macOS 15.0, iOS 18.0, *) {
			new.allowsPersistentDNS = storedRequest.allowsPersistentDNS
		}
		new.assumesHTTP3Capable = storedRequest.assumesHTTP3Capable
		if #available(iOS 16.1, tvOS 16.1, watchOS 9.1, *) {
			new.requiresDNSSECValidation = storedRequest.requiresDNSSECValidation
		}

		return new
	}
}
