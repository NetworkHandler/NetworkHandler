import Foundation
import HTTPTypes
import Logging

public protocol NetworkCachable: AnyObject, Sendable {
	var name: String { get }

	var logger: Logger { get }

	func cachedItem(for key: NetworkCacheKey) -> NetworkCacheStore?
	func setCachedItem(_ newValue: NetworkCacheStore?, for key: NetworkCacheKey)

	func reset()
}

extension NetworkCachable {
	subscript(key: NetworkCacheKey) -> NetworkCacheStore? {
		get { cachedItem(for: key) }
		set { setCachedItem(newValue, for: key) }
	}

	/// Removes and optionally returns the cached object associated with the specified key.
	///
	/// - Parameter key: The unique key representing the object to remove from the cache.
	/// - Returns: The `NetworkCacheStore` that was associated with the key, or `nil` if no
	/// matching item was found.
	///
	/// It also logs the key removal for auditability. The return value allows you to retrieve the
	/// removed object if necessary.
	@discardableResult
	func remove(objectFor key: NetworkCacheKey) -> NetworkCacheStore? {
		let cachedItem = cachedItem(for: key)
		setCachedItem(nil, for: key)
		logger.debug("Deleted cached data", metadata: ["Key": "\(key)"])
		return cachedItem
	}
}

public enum NetworkCacheKey: Sendable, Hashable, RawRepresentable {
	private static let separator = "\0.\0"

	public var url: URL? {
		guard case .urlMethod(let url, _) = self else {
			return nil
		}
		return url
	}
	public var method: HTTPRequest.Method? {
		guard case .urlMethod(_, let method) = self else {
			return nil
		}
		return method
	}

	public var rawValue: String {
		switch self {
		case .rawString(let string):
			string
		case .urlMethod(let url, let method):
			"\(method.rawValue)\(Self.separator)\(url.absoluteString)"
		}
	}

	case rawString(String)
	case urlMethod(URL, HTTPRequest.Method)

	public init(rawValue: String) {
		let split = rawValue.split(separator: Self.separator).map(String.init)
		if
			split.count == 2,
			let method = split.first.flatMap(HTTPRequest.Method.init(rawValue:)),
			let url = split.last.flatMap(URL.init(string:)) {

			self = .urlMethod(url, method)
		} else {
			self = .rawString(rawValue)
		}
	}
}

public struct NetworkCacheStore: Sendable, Hashable, Codable {
	public let response: EngineResponseHeader
	public let data: Data
	public var cost: Int { data.count }
}
