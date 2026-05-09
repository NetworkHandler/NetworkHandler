import Foundation
import HTTPTypes
import NetworkHalpers
import SwiftPizzaSnips

/// An HTTP request type designed specifically for uploading larger payloads, such as files or
/// large binary data. Unlike `GeneralEngineRequest`, this tracks both upload and download progress.
///
/// The request metadata is shared with `EngineRequestMetadata`, simplifying configuration for things
/// like headers and request IDs.
///
/// This is a lowst common denominator representation of an HTTP request. If you're conforming your own
/// engine to `NetworkEngine`, you'll most likely want to add a computed property or function to convert
/// a `UploadEngineRequest` to the request type native to your engine.
@dynamicMemberLookup
public struct UploadEngineRequest: Hashable, Sendable, Withable {
	package var commonData: EngineRequestCommonData

	public subscript<T>(dynamicMember member: WritableKeyPath<EngineRequestCommonData, T>) -> T {
		get { commonData[keyPath: member] }
		set { commonData[keyPath: member] = newValue }
	}

	public subscript<T>(dynamicMember member: KeyPath<EngineRequestCommonData, T>) -> T {
		commonData[keyPath: member]
	}

	/// - Parameters:
	///   - expectedResponseCodes: Accepted response status codes from the server.
	///   - headers: Headers for the request
	///   - method: HTTP Method to use for the request. Defaults to `.post`
	///   - url: URL for the request.
	///   - autogenerateRequestID: When set to `true`(default) a UUID is generated and put in the request ID header.
	public init(
		expectedResponseCodes: ResponseCodes = [200],
		headers: HTTPFields = [:],
		method: HTTPRequest.Method = .post,
		url: URL,
		autogenerateRequestID: Bool = true
	) {
		self.commonData = EngineRequestCommonData(
			expectedResponseCodes: expectedResponseCodes,
			headers: headers,
			method: method,
			url: url,
			autogenerateRequestID: autogenerateRequestID)
	}

	public typealias ResponseCodes = EngineRequestCommonData.ResponseCodes
}
