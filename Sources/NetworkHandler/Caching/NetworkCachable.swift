import Foundation
import HTTPTypes
import Logging

/// A protocol for types that cache network-related data.
///
/// Conforming types provide a keyed cache backed by `NetworkCacheStore` values,
/// supporting retrieval, insertion, and full reset operations.
public protocol NetworkCachable: AnyObject, Sendable {
	/// A human-readable name for this cache instance.
	var name: String { get }

	/// The ``Logger`` instance used to emit cache-related log events.
	var logger: Logger { get }

	/// Returns the cached ``NetworkCacheStore`` associated with `key`, if one exists.
	///
	/// - Parameter key: The key identifying the cached item to retrieve.
	/// - Returns: The cached ``NetworkCacheStore``, or `nil` if no entry exists.
	func cachedItem(for key: NetworkCacheKey) -> NetworkCacheStore?

	/// Replaces the cached ``NetworkCacheStore`` for `key` with `newValue`.
	///
	/// Passing `nil` removes the entry associated with `key` from the cache.
	///
	/// - Parameters:
	///   - newValue: The new cached value, or `nil` to evict any existing entry.
	///   - key: The key identifying the entry to modify.
	func setCachedItem(_ newValue: NetworkCacheStore?, for key: NetworkCacheKey)

	/// Removes all entries from the cache, returning it to an empty state.
	func reset()
}

extension NetworkCachable {
	/// Returns the cached ``NetworkCacheStore`` associated with `key`, if one exists.
	subscript(key: NetworkCacheKey) -> NetworkCacheStore? {
		get { cachedItem(for: key) }
		set { setCachedItem(newValue, for: key) }
	}

	/// Removes and optionally returns the cached object associated with the specified key.
	///
	/// - Parameter key: The unique key representing the object to remove from the cache.
	/// - Returns: The `NetworkCacheStore` that was associated with the key, or `nil` if no
	///   matching item was found.
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

/// A hashable key type that identifies cached ``NetworkCacheStore`` entries.
///
/// A `NetworkCacheKey` can be constructed from a raw URL string, or from a pair
/// consisting of a ``URL`` and an ``HTTPRequest.Method``. The latter form is
/// typically used to distinguish between HTTP methods that target the same URL.
public enum NetworkCacheKey: Sendable, Hashable, RawRepresentable {
	/// The character sequence separating the HTTP method from the URL in a raw-string key.
	private static let separator = "\0.\0"

	/// The underlying ``URL`` component, if this key was constructed from a URL and method.
	///
	/// Returns `nil` for keys created from raw strings that do not contain URL/method
	/// segment separators.
	public var url: URL? {
		guard case .urlMethod(let url, _) = self else {
			return nil
		}
		return url
	}

	/// The underlying ``HTTPRequest.Method`` component, if this key was constructed from
	/// a URL and method.
	///
	/// Returns `nil` for keys created from raw strings that do not contain URL/method
	/// segment separators.
	public var method: HTTPRequest.Method? {
		guard case .urlMethod(_, let method) = self else {
			return nil
		}
		return method
	}

	/// The raw-string representation of this key.
	///
	/// For ``urlMethod``-backed keys this encodes both method and URL, separated by a
	/// null-bounded dot. For ``rawString``-backed keys it is simply the stored string.
	public var rawValue: String {
		switch self {
		case .rawString(let string):
			string
		case .urlMethod(let url, let method):
			"\(method.rawValue)\(Self.separator)\(url.absoluteString)"
		}
	}

	/// A key backed by a raw string.
	case rawString(String)

	/// A key backed by a ``URL`` and an ``HTTPRequest.Method`` pair.
	case urlMethod(URL, HTTPRequest.Method)

	/// Creates a new key from its raw-string representation.
	///
	/// Attempts to parse the raw value as a method/URL pair separated by a
	/// null-bounded dot. If parsing succeeds the result is ``urlMethod``; otherwise the
	/// result is ``rawString``.
	///
	/// - Parameter rawValue: The raw-string representation to parse.
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

/// A store of a single network response and its associated data.
///
/// Instances hold an ``EngineResponseHeader`` alongside the raw ``Data`` payload,
/// and track a `cost` equal to the number of bytes in the data.
public struct NetworkCacheStore: Sendable, Hashable, Codable {
	/// The response header returned by the network engine.
	public let response: EngineResponseHeader

	/// The raw data payload of the network response.
	public let data: Data

	/// The ``NetworkCacheStore``'s cost in bytes, derived from the length of ``data``.
	public var cost: Int { data.count }
}
