import Foundation
import Logging

// swiftlint:disable line_length
/*
Idea to resolve non blocking issue in [this test](test://com.apple.xcode/NetworkHandler/NetworkHandlerTests/NetworkCacheTests/testCacheAddRemove)

create a cache-cache. Create a dict that stores the value right away, (using a lock for thread safety). then periodically check if the backing cache value is populated.
once it's populated, clear from the cache-cache. in the meantime, the cache-cache can serve up the content
*/
// swiftlint:enable line_length

/// Essentially just a wrapper for NSCache, but adds redundancy in a disk cache. Specifically purposed for
/// use with NetworkHandler
public final class DefaultNetworkCache: NetworkCachable {
	// MARK: - Properties
	nonisolated(unsafe) // NSCache is documented as being thread safe.
	private let cache = NSCache<Box<NetworkCacheKey>, Box<NetworkCacheStore>>()
	let diskCache: NetworkCachable
	private static let diskEncoder = PropertyListEncoder()
	private static let diskDecoder = PropertyListDecoder()

	/// The maximum number of objects the cache should hold.
	///
	/// If 0, there is no count limit. The default value is 0.
	/// This is not a strict limit—if the cache goes over the limit, an object in the cache could be evicted instantly,
	/// later, or possibly never, depending on the implementation details of the cache.
	public var countLimit: Int {
		get { cache.countLimit }
		set { cache.countLimit = newValue }
	}

	/// The maximum total cost that the cache can hold before it starts evicting objects.
	///
	/// If `0`, there is no total cost limit. The default value is `0`.
	/// When you add an object to the cache, you may pass in a specified cost for the object, such as the size
	/// in bytes of the object. If adding this object to the cache causes the cache’s total cost to rise above
	/// `totalCostLimit`, the cache may automatically evict objects until its total cost falls below
	/// `totalCostLimit`. The order in which the cache evicts objects is not guaranteed. This is not a
	///  strict limit, and if the cache goes over the limit, an object in the cache could be evicted instantly, at
	///  a later point in time, or possibly never, all depending on the implementation details of the cache.
	public var totalCostLimit: Int {
		get { cache.totalCostLimit }
		set { cache.totalCostLimit = newValue }
	}

	/// The name of the cache. The default is "NetworkHandler: DefaultNetworkCache"
	public var name: String {
		get { cache.name }
		set { cache.name = newValue }
	}

	/// Retrieves the cached object associated with a specific `key`.
	///
	/// - Parameter key: The unique `NetworkCacheKey` representing the object to retrieve.
	/// - Returns: The `NetworkCacheStore` associated with the provided key, or `nil` if no item exists in
	/// either the memory cache or disk cache.
	///
	/// This method checks the in-memory cache first for faster access. If the item is not found in memory,
	/// it falls back to the disk-based backing store, where the data is decoded into a `NetworkCacheStore`.
	///
	/// A cache hit log is emitted when the item is found in memory; a cache miss is logged otherwise.
	public func cachedItem(for key: NetworkCacheKey) -> NetworkCacheStore? {
		if let cachedItem = cache.object(forKey: .init(key)) {
			logger.debug("Cache hit", metadata: ["Key": "\(key)"])
			return cachedItem.value
		} else if let diskStored = diskCache.cachedItem(for: key) {
			return diskStored
		}
		logger.debug("Cache miss", metadata: ["Key": "\(key)"])
		return nil
	}

	/// Stores or removes a cached object associated with a specific `key`.
	///
	/// - Parameters:
	///   - newValue: The `NetworkCacheStore` to cache, or `nil` to remove an existing entry.
	///   - key: The unique `NetworkCacheKey` identifying the object.
	///
	/// When a non-`nil` value is provided:
	/// - Adds the item to the in-memory cache with a cost based on the data's byte count.
	/// - Persists the item to the disk cache.
	/// - Logs the storage activity for debugging.
	///
	/// When `nil` is provided:
	/// - Removes the entry from both the in-memory cache and the disk cache.
	public func setCachedItem(_ newValue: NetworkCacheStore?, for key: NetworkCacheKey) {
		if let newData = newValue {
			cache.setObject(.init(newData), forKey: .init(key), cost: newData.cost)
			logger.debug("Stored cache data", metadata: ["Key": "\(key)"])
			diskCache.setCachedItem(newValue, for: key)
		} else {
			cache.removeObject(forKey: .init(key))
			diskCache.setCachedItem(nil, for: key)
		}
	}

	public let logger: Logger

	// MARK: - Init
	/// Creates a new instance of `DefaultNetworkCache` with a given name, logger, and disk cache capacity.
	///
	/// - Parameters:
	///   - name: The name of the cache, used for organization and logging clarity.
	///   - logger: A `Logger` instance to report cache activity.
	///   - diskCache: A concrete implementation of a disk cache
	///
	/// This initializer sets up both an in-memory cache and a redundant disk
	/// cache, providing robust, persistent storage. A secondary logger is configured for the disk cache, based on
	/// the provided logger's settings.
	init(name: String, logger: Logger, diskCache: NetworkCachable? = nil) {
		self.logger = logger
		var diskLogger = Logger(label: "\(logger.label) - Disk Cache")
		diskLogger.logLevel = logger.logLevel
		diskLogger.handler = logger.handler
		self.diskCache = diskCache ?? DefaultNetworkDiskCache(
			capacity: .max,
			cacheName: name,
			logger: diskLogger)
		self.name = name
	}

	// MARK: - Methods
	/// Clears the contents of the cache either in memory, on disk, or both.
	///
	/// - Parameters:
	///   - memory: A Boolean value indicating whether to clear the in-memory cache. Defaults to `true`.
	///   - disk: A Boolean value indicating whether to clear the disk cache. Defaults to `true`.
	///
	/// Use this method to completely wipe the cache, ensuring that no stale or outdated data remains.
	/// Logs these operations for visibility.
	public func reset(memory: Bool = true, disk: Bool = true) {
		if memory {
			cache.removeAllObjects()
			logger.debug("Cleared memory cache.", metadata: ["Name": "\(name)"])
		}
		if disk {
			diskCache.reset()
		}
	}

	public func reset() {
		reset(memory: true, disk: true)
	}
}

extension DefaultNetworkCache {
	@dynamicMemberLookup
	package final class Box<Wrapped> {
		package var value: Wrapped

		package init(_ value: Wrapped) {
			self.value = value
		}

		package subscript<T>(dynamicMember member: WritableKeyPath<Wrapped, T>) -> T {
			get { value[keyPath: member] }
			set { value[keyPath: member] = newValue }
		}

		package subscript<T>(dynamicMember member: KeyPath<Wrapped, T>) -> T {
			value[keyPath: member]
		}
	}
}

extension DefaultNetworkCache.Box: Equatable where Wrapped: Equatable {
	package static func == (lhs: DefaultNetworkCache.Box<Wrapped>, rhs: DefaultNetworkCache.Box<Wrapped>) -> Bool {
		lhs.value == rhs.value
	}
}

extension DefaultNetworkCache.Box: Hashable where Wrapped: Hashable {
	package func hash(into hasher: inout Hasher) {
		hasher.combine(value)
	}
}

extension DefaultNetworkCache.Box: @unchecked Sendable where Wrapped: Sendable {}

extension DefaultNetworkCache.Box: CustomStringConvertible where Wrapped: CustomStringConvertible {
	package var description: String { value.description }
}

extension DefaultNetworkCache.Box: CustomDebugStringConvertible where Wrapped: CustomDebugStringConvertible {
	package var debugDescription: String { value.debugDescription }
}
