import Foundation
import HTTPTypes
import SwiftPizzaSnips

/// Represents an HTTP request for most HTTP interactions, such as sending or retrieving JSON or binary responses.
/// While upload progress is not tracked, download progress is monitored.
///
/// This is a lowst common denominator representation of an HTTP request. If you're conforming your own
/// engine to `NetworkEngine`, you'll most likely want to add a computed property or function to convert
/// a `NetworkRequest` to the request type native to your engine.
public struct NetworkRequest: Hashable, Sendable, Withable {
	/// Defines the range of acceptable HTTP response status codes for a request.
	/// This type encapsulates response codes as a set of integers and provides
	/// conveniences for constructing it from individual integers, ranges, or arrays.
	///
	/// Example:
	/// ```swift
	/// let successCodes: ResponseCodes = [200, 201, 202]
	/// let any2xxCode = ResponseCodes(range: 200..<300)
	/// ```
	public struct ResponseCodes:
		Hashable,
		Sendable,
		Withable,
		RawRepresentable,
		ExpressibleByIntegerLiteral,
		ExpressibleByArrayLiteral {

		public var rawValue: Set<Int>

		public init(rawValue: Set<Int>) {
			self.rawValue = rawValue
		}

		public init(arrayLiteral elements: Int...) {
			self.init(rawValue: Set(elements))
		}

		public init(integerLiteral value: IntegerLiteralType) {
			self.init(rawValue: [value])
		}

		public init(range: Range<Int>) {
			self.init(rawValue: range.reduce(into: .init(), { $0.insert($1) } ))
		}
	}

	/// Specifies the range or list of HTTP response codes that are considered valid for this request.
	/// Responses falling outside this range may be treated as errors, depending on the network engine's logic.
	///
	/// Example:
	/// ```swift
	/// commonData.expectedResponseCodes = [200, 201, 202]
	/// commonData.expectedResponseCodes = ResponseCodes(range: 200..<300)
	/// ```
	public var expectedResponseCodes: ResponseCodes

	/// Gets or sets the expected size of the response payload in bytes via the `Content-Length` header.
	///
	/// When set, the `Content-Length` header is automatically updated.
	/// Setting this to `nil` removes the header from the metadata.
	public var expectedContentLength: Int? {
		get { headers[.contentLength].flatMap(Int.init) }
		set {
			guard let newValue else {
				headers[.contentLength] = nil
				return
			}
			headers[.contentLength] = "\(newValue)"
		}
	}

	public var headers: HTTPFields = [:]

	public var method: HTTPRequest.Method = .get

	public var url: URL

	public var timeoutInterval: TimeInterval = 60

	private let extensionStorage = UncheckedLockBox([String: AnyHashable]())

	/// The unique ID used to identify this request. Follows the `X-Request-ID` HTTP header convention.
	///
	/// Automatically populated with a UUID string upon initialization if autogeneration is enabled.
	/// To disable this behavior, pass `autogenerateRequestID: false` during construction.
	///
	/// See [X-Request-ID](https://http.dev/x-request-id) for more info. Note that while it's an optional header,
	/// convention dictates that it should be the same when retrying a request.
	public var requestID: String? {
		get { headers[.xRequestID] }
		set {
			guard let newValue else {
				headers[.xRequestID] = nil
				return
			}
			headers[.xRequestID] = "\(newValue)"
		}
	}

	/// Stores platform or library-specific metadata in a key-value dictionary.
	///
	/// This mechanism allows extending `NetworkRequest` with custom properties, especially
	/// in extensions (since extensions cannot introduce stored properties).
	///
	/// Stored values MUST be `Hashable & Sendable` so `NetworkRequest` itself can maintain conformance.
	///
	/// - Parameters:
	///   - value: The value to store. Setting `nil` removes the key from the storage.
	///   - key: A unique identifier for the metadata entry.
	///
	/// For example, if you want to use Foundation's networking as your engine and use URLRequest, you could add
	///
	/// ```swift
	/// extension NetworkEngine {
	/// 	var allowsCellularAccess: Bool {
	/// 		get { (extensionStorageRetrieve(valueForKey: "allowsCellularAccess") ?? true }
	/// 		set { extensionStorage(store: newValue, with: "allowsCellularAccess") }
	/// 	}
	/// }
	/// ```
	public mutating func extensionStorage<T: Hashable & Sendable>(store value: T?, with key: String) {
		extensionStorage.withLock {
			$0[key] = value
		}
	}

	/// To support specialized properties for your platform, you can create an extension that stores its values here
	/// (since extensions only support computed properties)
	///
	/// For example, if you want to use Foundation's networking as your engine and use URLRequest, you could add
	///
	/// ```swift
	/// extension NetworkEngine {
	/// 	var allowsCellularAccess: Bool {
	/// 		get { (extensionStorageRetrieve(valueForKey: "allowsCellularAccess") ?? true }
	/// 		set { extensionStorage(store: newValue, with: "allowsCellularAccess") }
	/// 	}
	/// }
	/// ```
	public func extensionStorageRetrieve<T: Hashable & Sendable>(valueForKey key: String) -> T? {
		extensionStorage.withLock {
			$0[key] as? T
		}
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
		self.expectedResponseCodes = expectedResponseCodes
		self.headers = headers
		self.method = method
		self.url = url
		guard autogenerateRequestID else { return }
		self.requestID = UUID().uuidString
	}

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
