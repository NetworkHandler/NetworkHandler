import Crypto
import Foundation
import Logging
import SwiftPizzaSnips

/// A disk-based network cache implementation storing cached items with configurable capacity and automatic eviction.
///
/// Uses SHA-1 hashing to map cache keys to file paths, manages file locks for thread safety,
/// and evicts the least recently modified files when capacity is exceeded.
public final class DefaultNetworkDiskCache: CustomDebugStringConvertible, Sendable, NetworkCachable {
	nonisolated(unsafe)
	private let fileManager = FileManager.default

	// should only operate within Self.globalLock
	nonisolated(unsafe)
	private var _size: UInt64 = 0

	/// The total size in bytes of all cached items in this cache.
	///
	/// Thread-safe; returns the current size under lock protection.
	public var size: UInt64 {
		Self.globalLock.withLock { _size }
	}

	// should only operate within Self.globalLock
	nonisolated(unsafe)
	private var _capacity: UInt64 {
		didSet { _enforceCapacity() }
	}

	/// The maximum size in bytes for the cache.
	///
	/// Exceeding this capacity triggers automatic eviction of the least recently modified files.
	public var capacity: UInt64 {
		get { Self.globalLock.withLock { _capacity } }
		set { Self.globalLock.withLock { _capacity = newValue } }
	}

	/// The name identifying this cache instance.
	public let name: String

	// should only operate within Self.globalLock
	nonisolated(unsafe)
	private var _count: Int = 0

	/// The number of items currently stored in this cache.
	///
	/// Thread-safe; returns the current count under lock protection.
	public var count: Int {
		Self.globalLock.withLock { _count }
	}

	/// Whether the cache contains zero items.
	public var isEmpty: Bool { count == 0 } // swiftlint:disable:this empty_count

	private let cacheLocation: URL

	static private let globalLock = NSRecursiveLock()
	nonisolated(unsafe)
	private var fileLocks: [URL: MutexLock] = [:]

	public let logger: Logger

	private static let diskEncoder = PropertyListEncoder()
	private static let diskDecoder = PropertyListDecoder()

	/// Creates a new disk cache instance with the given configuration.
	///
	/// - Parameters:
	///   - capacity: Maximum total size in bytes for cached items. Defaults to `.max`.
	///   - cacheName: Human-readable namespace for this cache. Defaults to `"DefaultNetworkDiskCache"`.
	///   - logger: Logger instance for recording cache operations and errors.
	///
	/// The cache directory is created under the user domain's caches folder. Upon initialization,
	/// the actual disk usage is calculated and capacity is enforced.
	public init(capacity: UInt64 = .max, cacheName: String? = nil, logger: Logger) {
		Self.globalLock.lock()
		defer { Self.globalLock.unlock() }
		self.logger = logger
		self._capacity = capacity
		self.name = cacheName ?? "DefaultNetworkDiskCache"
		self.cacheLocation = Self.getCacheURL(cacheName: name)

		_refreshSize()
		_enforceCapacity()
	}

	/// Retrieves the cached store item associated with the given key.
	///
	/// Decodes the raw bytes from disk into a `NetworkCacheStore` instance.
	/// Returns `nil` if no item is cached for the key or decoding fails.
	///
	/// - Parameter key: The cache key to look up.
	/// - Returns: The decoded cache item, or `nil` if absent or invalid.
	public func cachedItem(for key: NetworkCacheKey) -> NetworkCacheStore? {
		guard let data = getData(for: key) else { return nil }

		return try? Self.diskDecoder.decode(NetworkCacheStore.self, from: data)
	}

	/// Stores or removes a cache item associated with the given key.
	///
	/// - Parameters:
	///   - newValue: The cache item to store, or `nil` to remove an existing entry.
	///   - key: The key to associate the item with.
	///
	/// When `newValue` is non-nil, it is encoded to disk. When `nil`, any existing entry for
	/// the key is removed. If encoding fails, the item is silently skipped.
	public func setCachedItem(_ newValue: NetworkCacheStore?, for key: NetworkCacheKey) {
		if let newValue {
			guard let data = try? Self.diskEncoder.encode(newValue) else { return }

			setData(data, key: key)
		} else {
			setData(nil, key: key)
		}
	}

	// MARK: - CRUD

	func setData(_ getData: @autoclosure @escaping () -> Data?, key: NetworkCacheKey) {
		let path = path(for: key.rawValue)
		let lock = getLock(for: path)
		lock.withLock {
			_setData(getData(), fileLocation: path)
		}
	}

	// should only operate within its file lock
	private func _setData(_ getData: @autoclosure @escaping () -> Data?, fileLocation: URL) {
		guard let data = getData() else {
			_deleteFile(at: fileLocation)
			return
		}

		let oldFileSize = _fileSize(at: fileLocation)

		do {
			try data.write(to: fileLocation)
			Self.globalLock.withLock {
				_subtractSize(oldFileSize ?? 0, removingFile: false)
				_addSize(for: data)
			}
			_updateAccessDate(fileLocation)
			logger.debug("Saved cached file", metadata: ["URL": "\(fileLocation.absoluteString)"])
		} catch {
			logger.error("Error saving cache data:", metadata: ["Error": "\(error)"])
		}
	}

	func getData(for key: NetworkCacheKey) -> Data? {
		let path = path(for: key.rawValue)
		let lock = getLock(for: path)
		return lock.withLock {
			_getData(for: path)
		}
	}

	// should only operate within its file lock
	private func _getData(for filePath: URL) -> Data? {
		guard let loadedData = try? Data(contentsOf: filePath) else { return nil }
		_updateAccessDate(filePath)

		logger.debug("Cache hit", metadata: ["URL": "\(filePath.absoluteString)"])
		return loadedData
	}

	// should only operate within its file lock
	private func _deleteFile(at path: URL) {
		guard let oldSize = _fileSize(at: path) else {
			return // no size implies no file
		}

		do {
			try fileManager.removeItem(at: path)
			Self.globalLock.withLock {
				_subtractSize(oldSize, removingFile: true)
			}
			logger.debug("Deleted cached file", metadata: ["File": "\(path.path(percentEncoded: false))"])
			releaseLock(for: path)
		} catch {
			logger.error("Error removing \(path):", metadata: ["Error": "\(error)"])
		}
	}

	/// Clears all cached items.
	///
	/// Removes the entire cache directory (falling back to individual file deletion if necessary)
	/// and resets the internal lock dictionary.
	public func reset() {
		Self.globalLock.withLock {
			_resetCache()
			fileLocks = [:]
		}
	}

	// should only operate within Self.globalLock
	private func _resetCache() {
		guard cacheLocation.checkResourceIsAccessible() else { return }
		do {
			try fileManager.removeItem(at: cacheLocation)
			_refreshSize()
			logger.info("Reset disk cache", metadata: ["Name": "\(name)"])
		} catch {
			logger.error(
				"Error resetting disk cache by clearing folder. Trying individual files.",
				metadata: ["Error": "\(error)"])
			do {
				let contents = try fileManager.contentsOfDirectory(at: cacheLocation, includingPropertiesForKeys: [], options: [])

				for file in contents {
					_deleteFile(at: file)
				}
				logger.info("Reset disk cache", metadata: ["Name": "\(name)"])
			} catch {
				logger.error("Error resetting cache:", metadata: ["Error": "\(error)"])
			}
		}
	}

	// MARK: - Utility
	private func getLock(for url: URL) -> MutexLock {
		Self.globalLock.withLock {
			if let existing = fileLocks[url] {
				return existing
			} else {
				let new = MutexLock()
				fileLocks[url] = new
				return new
			}
		}
	}

	private func releaseLock(for url: URL) {
		Self.globalLock.withLock {
			fileLocks[url] = nil
		}
	}

	private static func getCacheURL(cacheName: String) -> URL {
		Self.globalLock.lock()
		defer { Self.globalLock.unlock() }
		do {
			let cacheDir = try FileManager.default.url(
				for: .cachesDirectory,
				in: .userDomainMask,
				appropriateFor: nil,
				create: true)
			let cacheResource = cacheDir.appendingPathComponent(cacheName)

			if cacheResource.checkResourceIsAccessible() == false {
				try FileManager.default.createDirectory(at: cacheResource, withIntermediateDirectories: true)
			}
			return cacheResource
		} catch {
			fatalError("Error retrieving cache directory: \(error)")
		}
	}

	private func path(for key: String) -> URL {
		let sha1 = Insecure.SHA1.hash(data: Data(key.utf8)).hex()
		if cacheLocation.checkResourceIsAccessible() == false {
			try? fileManager.createDirectory(at: cacheLocation, withIntermediateDirectories: true)
		}
		return cacheLocation.appendingPathComponent(sha1)
	}

	// should only operate within its file lock
	private func _updateAccessDate(_ url: URL) {
		let now = Date()
		do {
			try fileManager.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
			logger.trace("Updated disk cache access date", metadata: ["Path": "\(url.path(percentEncoded: false))"])
		} catch {
			logger.error("Error updating access time:", metadata: ["Error": "\(error)"])
		}
	}

	// should only operate within its file lock
	private func _fileSize(at url: URL) -> UInt64? {
		guard
			let sizeValue = try? url.resourceValues(forKeys: [.fileSizeKey]),
			let size = sizeValue.fileSize
		else { return nil }

		return .init(size)
	}

	// should only operate within Self.globalLock
	private func _addSize(for data: Data) {
		let size = UInt64(data.count)
		_addSize(size)
	}

	// should only operate within Self.globalLock
	private func _addSize(_ value: UInt64) {
		_size += value
		_count += 1
		_enforceCapacity()
	}

	// should only operate within Self.globalLock
	private func _subtractSize(_ value: UInt64, removingFile: Bool) {
		if removingFile { _count -= 1 }
		guard value < _size else {
			_size = 0
			return
		}
		_size -= value
	}

	// should only operate within Self.globalLock
	private func _enforceCapacity() {
		guard _size > _capacity else { return }

		do {
			let contents = try fileManager
				.contentsOfDirectory(
					at: cacheLocation,
					includingPropertiesForKeys: [.contentModificationDateKey],
					options: [])

			let sorted = try contents.sorted { a, b in // swiftlint:disable:this identifier_name
				let dateInfoA = try a.resourceValues(forKeys: [.contentModificationDateKey])
				let dateInfoB = try b.resourceValues(forKeys: [.contentModificationDateKey])

				guard
					let dateA = dateInfoA.contentModificationDate,
					let dateB = dateInfoB.contentModificationDate
				else { return false }
				return dateA < dateB
			}

			logger.trace("Enforcing disk capacity...")
			var oldestFirst = sorted.makeIterator()
			while let oldestOnDisk = oldestFirst.next() {
				guard _size > _capacity else { return }

				_deleteFile(at: oldestOnDisk)
			}
			logger.trace("Done enforcing disk capacity")
		} catch {
			logger.error("Error enforcing disk cache capacity:", metadata: ["Error": "\(error)"])
		}
	}

	// should only operate within Self.globalLock
	private func _refreshSize() {
		guard cacheLocation.checkResourceIsAccessible() else {
			_size = 0
			_count = 0
			return
		}
		do {
			let contents = try fileManager
				.contentsOfDirectory(
					at: cacheLocation,
					includingPropertiesForKeys: [.fileSizeKey],
					options: [])
			_size = try contents.reduce(0, {
				let fileSizeValues = try $1.resourceValues(forKeys: [.fileSizeKey])
				guard let fileSize = fileSizeValues.fileSize else { return $0 }

				return $0 + UInt64(fileSize)
			})
			_count = contents.count
			logger.trace("Refreshed disk cache size", metadata: ["Size": "\(size)", "Count": "\(count)"])
		} catch {
			logger.error("Error calculating disk cache size:", metadata: ["Error": "\(error)"])
		}
	}

	/// A human-readable debug description of the cache.
	///
	/// Returns the cache directory URL for inspection and logging.
	public var debugDescription: String {
		"Network Disk Cache: \(cacheLocation)"
	}
}
