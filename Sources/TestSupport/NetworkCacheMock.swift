import Logging
import NetworkHandler
import SwiftPizzaSnips

/// A mock implementation of `NetworkCachable` for testing purposes.
///
/// Provides an in-memory cache with thread-safe access using a lock.
/// Useful for unit tests that need to verify caching behavior without
/// the complexity of a real cache implementation.
public final class NetworkCacheMock: NetworkCachable {
	/// The name of this cache instance, used for identification in logs and tests.
	public let name: String

	public var countLimit: Int {
		get { 0 }
		set { } // swiftlint:disable:this unused_setter_value
	}
	public var totalCostLimit: Int {
		get { 0 }
		set { } // swiftlint:disable:this unused_setter_value
	}

	/// The logger used by this cache instance.
	public let logger: Logger

	private let lock = MutexLock()
	nonisolated(unsafe)
	private var store: [NetworkCacheKey: NetworkCacheStore] = [:]

	/// Creates a new network cache mock.
	/// - Parameters:
	///   - name: A name for identification purposes.
	///   - logger: A logger for recording cache events.
	public init(
		name: String,
		logger: Logger
	) {
		self.name = name
		self.logger = logger
	}

	/// Returns the cached item for the given key, if one exists.
	/// - Parameter key: The cache key to look up.
	/// - Returns: The cached `NetworkCacheStore` or `nil` if no entry exists.
	public func cachedItem(for key: NetworkCacheKey) -> NetworkCacheStore? {
		lock.withLock { store[key] }
	}

	/// Sets or removes a cached item for the given key.
	/// - Parameters:
	///   - newValue: The new cached value, or `nil` to remove an existing entry.
	///   - key: The cache key to set.
	public func setCachedItem(_ newValue: NetworkCacheStore?, for key: NetworkCacheKey) {
		lock.withLock { store[key] = newValue }
	}

	/// Clears all cached items.
	public func reset() {
		lock.withLock { store = [:] }
	}
}
