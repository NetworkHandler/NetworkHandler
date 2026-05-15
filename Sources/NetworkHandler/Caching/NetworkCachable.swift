import Foundation
import HTTPTypes
import Logging

public protocol NetworkCachable: AnyObject, Sendable {
	var name: String { get }

	/// The maximum number of objects the cache should hold.
	///
	/// If 0, there is no count limit. The default value is 0.
	/// This is not a strict limit—if the cache goes over the limit, an object in the cache could be evicted instantly,
	/// later, or possibly never, depending on the implementation details of the cache.
	var countLimit: Int { get set }

	var logger: Logger { get }

	/// The maximum total cost that the cache can hold before it starts evicting objects.
	///
	/// If `0`, there is no total cost limit. The default value is `0`.
	/// When you add an object to the cache, you may pass in a specified cost for the object, such as the size
	/// in bytes of the object. If adding this object to the cache causes the cache’s total cost to rise above
	/// `totalCostLimit`, the cache may automatically evict objects until its total cost falls below
	/// `totalCostLimit`. The order in which the cache evicts objects is not guaranteed. This is not a
	///  strict limit, and if the cache goes over the limit, an object in the cache could be evicted instantly, at
	///  a later point in time, or possibly never, all depending on the implementation details of the cache.
	var totalCostLimit: Int { get set }

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
