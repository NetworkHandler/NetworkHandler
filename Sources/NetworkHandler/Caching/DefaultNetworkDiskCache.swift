import Crypto
import Foundation
import Logging
import NetworkHalpers
import SwiftPizzaSnips

final class DefaultNetworkDiskCache: CustomDebugStringConvertible, Sendable, NetworkCachable {
	nonisolated(unsafe)
	let fileManager = FileManager.default

	nonisolated(unsafe)
	private(set) var size: UInt64 = 0

	nonisolated(unsafe)
	var capacity: UInt64 {
		didSet { enforceCapacity() }
	}

	let name: String

	nonisolated(unsafe)
	private(set) var count: Int = 0

	private let cacheLocation: URL

	static private let globalLock = NSRecursiveLock()
	nonisolated(unsafe)
	private var fileLocks: [URL: MutexLock] = [:]

	let logger: Logger

	private static let diskEncoder = PropertyListEncoder()
	private static let diskDecoder = PropertyListDecoder()

	init(capacity: UInt64 = .max, cacheName: String? = nil, logger: Logger) {
		self.logger = logger
		self.capacity = capacity
		self.name = cacheName ?? "DefaultNetworkDiskCache"
		self.cacheLocation = Self.getCacheURL(cacheName: name)

		Self.globalLock.lock()
		defer { Self.globalLock.unlock() }
		_refreshSize()
		enforceCapacity()
	}

	func cachedItem(for key: NetworkCacheKey) -> NetworkCacheStore? {
		guard let data = getData(for: key) else { return nil }

		return try? Self.diskDecoder.decode(NetworkCacheStore.self, from: data)
	}

	func setCachedItem(_ newValue: NetworkCacheStore?, for key: NetworkCacheKey) {
		if let newValue {
			guard let data = try? Self.diskEncoder.encode(newValue) else { return }

			setData(data, key: key)
		} else {
			setData(nil, key: key)
		}
	}

	func reset() {
		resetCache()
	}

	// MARK: - CRUD

	func setData(_ getData: @autoclosure @escaping () -> Data?, key: NetworkCacheKey) {
		let path = path(for: key.rawValue)
		let lock = getLock(for: path)
		lock.withLock {
			_setData(getData(), fileLocation: path)
		}
	}

	private func _setData(_ getData: @autoclosure @escaping () -> Data?, fileLocation: URL) {
		guard let data = getData() else {
			_deleteFile(at: fileLocation)
			return
		}

		let oldFileSize = _fileSize(at: fileLocation)

		do {
			try data.write(to: fileLocation)
			_subtractSize(oldFileSize ?? 0, removingFile: false)
			_addSize(for: data)
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

	private func _getData(for filePath: URL) -> Data? {
		guard let loadedData = try? Data(contentsOf: filePath) else { return nil }
		_updateAccessDate(filePath)

		logger.debug("Cache hit", metadata: ["URL": "\(filePath.absoluteString)"])
		return loadedData
	}

	private func _deleteFile(at path: URL) {
		guard let oldSize = _fileSize(at: path) else {
			return // no size implies no file
		}

		do {
			try fileManager.removeItem(at: path)
			_subtractSize(oldSize, removingFile: true)
			logger.debug("Deleted cached file", metadata: ["File": "\(path.path(percentEncoded: false))"])
			releaseLock(for: path)
		} catch {
			logger.error("Error removing \(path):", metadata: ["Error": "\(error)"])
		}
	}

	func resetCache() {
		Self.globalLock.withLock {
			_resetCache()
			fileLocks = [:]
		}
	}

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
			let cacheDir = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
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

	private func _updateAccessDate(_ url: URL) {
		let now = Date()
		do {
			try fileManager.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
			logger.trace("Updated disk cache access date", metadata: ["Path": "\(url.path(percentEncoded: false))"])
		} catch {
			logger.error("Error updating access time:", metadata: ["Error": "\(error)"])
		}
	}

	private func _fileSize(at url: URL) -> UInt64? {
		guard
			let sizeValue = try? url.resourceValues(forKeys: [.fileSizeKey]),
			let size = sizeValue.fileSize
		else { return nil }

		return .init(size)
	}

	private func _addSize(for data: Data) {
		let size = UInt64(data.count)
		_addSize(size)
	}

	private func _addSize(_ value: UInt64) {
		size += value
		count += 1
		_enforceCapacity()
	}

	private func _subtractSize(_ value: UInt64, removingFile: Bool) {
		if removingFile { count -= 1 }
		guard value < size else {
			size = 0
			return
		}
		size -= value
	}

	private func enforceCapacity() {
		Self.globalLock.lock()
		defer { Self.globalLock.unlock() }
		_enforceCapacity()
	}

	private func _enforceCapacity() {
		guard size > capacity else { return }

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
				guard size > capacity else { return }

				_deleteFile(at: oldestOnDisk)
			}
			logger.trace("Done enforcing disk capacity")
		} catch {
			logger.error("Error enforcing disk cache capacity:", metadata: ["Error": "\(error)"])
		}
	}

	private func _refreshSize() {
		guard cacheLocation.checkResourceIsAccessible() else {
			size = 0
			count = 0
			return
		}
		do {
			let contents = try fileManager
				.contentsOfDirectory(
					at: cacheLocation,
					includingPropertiesForKeys: [.fileSizeKey],
					options: [])
			size = try contents.reduce(0, {
				let fileSizeValues = try $1.resourceValues(forKeys: [.fileSizeKey])
				guard let fileSize = fileSizeValues.fileSize else { return $0 }

				return $0 + UInt64(fileSize)
			})
			count = contents.count
			logger.trace("Refreshed disk cache size", metadata: ["Size": "\(size)", "Count": "\(count)"])
		} catch {
			logger.error("Error calculating disk cache size:", metadata: ["Error": "\(error)"])
		}
	}

	var debugDescription: String {
		"Network Disk Cache: \(cacheLocation)"
	}
}
