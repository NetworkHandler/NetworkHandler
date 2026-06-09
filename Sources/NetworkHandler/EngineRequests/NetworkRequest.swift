import Foundation
import HTTPTypes
import SwiftPizzaSnips

/// Represents an HTTP request for most HTTP interactions, such as sending or retrieving JSON or binary responses.
/// While upload progress is not tracked, download progress is monitored.
///
/// This is a lowst common denominator representation of an HTTP request. If you're conforming your own
/// engine to `NetworkEngine`, you'll most likely want to add a computed property or function to convert
/// a `NetworkRequest` to the request type native to your engine.
@dynamicMemberLookup
public struct NetworkRequest: Hashable, Sendable, Withable {
	/// Internal metadata used to store common HTTP request properties, such as HTTP headers, response codes,
	/// and URLs. This provides a lightweight container around shared data without duplicating state or logic.
	package var commonData: CommonRequestData

	/// Returns the value of a dynamic member from `commonData` that allows modification.
	///
	/// - Parameter member: A writable key path into the `CommonRequestData` instance.
	/// - Returns: The value at the specified key path.
	public subscript<T>(dynamicMember member: WritableKeyPath<CommonRequestData, T>) -> T {
		get { commonData[keyPath: member] }
		set { commonData[keyPath: member] = newValue }
	}

	/// Returns the value of a dynamic member from `commonData`.
	///
	/// - Parameter member: A key path into the `CommonRequestData` instance.
	/// - Returns: The value at the specified key path.
	public subscript<T>(dynamicMember member: KeyPath<CommonRequestData, T>) -> T {
		commonData[keyPath: member]
	}

	nonisolated(unsafe)
	private static var _defaultEncoder: NHEncoder = JSONEncoder()
	nonisolated(unsafe)
	private static var _defaultDecoder: NHDecoder = JSONDecoder()
	private static let coderLock = MutexLock()

	/// Default encoder used to encode with the `encodeData` function.
	///
	/// Default value is `JSONEncoder()` along with all of its defaults. Being that this
	/// is a static property, it will affect *all* instances.
	public static var defaultEncoder: NHEncoder {
		get { coderLock.withLock { _defaultEncoder } }
		set { coderLock.withLock { _defaultEncoder = newValue } }
	}

	/// Default decoder used to decode data received from this request.
	///
	/// Default value is `JSONDecoder()` along with all of its defaults. Being that this
	/// is a static property, it will affect *all* instances.
	public static var defaultDecoder: NHDecoder {
		get { coderLock.withLock { _defaultDecoder } }
		set { coderLock.withLock { _defaultDecoder = newValue } }
	}

	/// Optional raw data sent as the HTTP request body.
	///
	/// This is commonly used for POST or PUT requests. For structured serialization,
	/// use the `encodeData(_:)` method instead.
	public var payload: Data?

	/// Creates a new `NetworkRequest` instance.
	///
	/// - Parameters:
	///   - expectedResponseCodes: HTTP response codes considered successful. Defaults to `[200]`.
	///   - headers: HTTP header fields for the request. Defaults to an empty dictionary.
	///   - method: The HTTP method. Defaults to `.get`.
	///   - url: The target URL for the request.
	///   - payload: Optional raw data for the request body.
	///   - autogenerateRequestID: Whether to auto-generate a request identifier. Defaults to `true`.
	public init(
		expectedResponseCodes: ResponseCodes = [200],
		headers: HTTPFields = [:],
		method: HTTPRequest.Method = .get,
		url: URL,
		payload: Data? = nil,
		autogenerateRequestID: Bool = true
	) {
		self.payload = payload
		self.commonData = CommonRequestData(
			expectedResponseCodes: expectedResponseCodes,
			headers: headers,
			method: method,
			url: url,
			autogenerateRequestID: autogenerateRequestID)
	}
	/// A type alias for the response codes expected from this request.
	///
	/// Defined as `CommonRequestData.ResponseCodes`.
	public typealias ResponseCodes = CommonRequestData.ResponseCodes

	/// Encodes an object conforming to `Encodable` into a `Data` payload using the specified or default encoder.
	///
	/// Automatically updates the `payload` property with the resulting serialized data upon success.
	///
	/// - Parameters:
	///   - encodableType: The object to encode into the `payload`.
	///   - encoder: An optional encoder conforming to `NHEncoder`. Uses `defaultEncoder` if not explicitly provided.
	/// - Returns: The serialized data now stored in the request's `payload`.
	/// - Throws: Errors from the encoder if the object cannot be serialized.
	@discardableResult
	public mutating func encodeData<EncodableType: Encodable>(
		_ encodableType: EncodableType,
		withEncoder encoder: NHEncoder? = nil
	) throws -> Data {
		let encoder = encoder ?? NetworkRequest.defaultEncoder

		let data = try encoder.encode(encodableType)

		self.payload = data

		return data
	}
}
