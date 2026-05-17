import Foundation
import Logging
@testable import NetworkHandler
import Testing

class DefaultNetworkDiskCacheTests {
	static let dummy1KFile = Data(repeating: 0, count: 1024)
	static let dummy2KFile = Data(repeating: 0, count: 1024 * 2)
	static let dummy5KFile = Data(repeating: 0, count: 1024 * 5)

	// swiftlint:disable:next large_tuple
	static func fileAssortment() -> (
		file1: (key: NetworkCacheKey, data: Data),
		file2: (key: NetworkCacheKey, data: Data),
		file3: (key: NetworkCacheKey, data: Data),
		file4: (key: NetworkCacheKey, data: Data),
		file5: (key: NetworkCacheKey, data: Data)
	) {
		let file1 = (key: NetworkCacheKey.rawString("file1"), data: Self.dummy1KFile)
		let file2 = (key: NetworkCacheKey.rawString("file2"), data: Self.dummy2KFile)
		let file3 = (key: NetworkCacheKey.rawString("file3"), data: Self.dummy5KFile)
		let file4 = (key: NetworkCacheKey.rawString("file4"), data: Self.dummy1KFile)
		let file5 = (key: NetworkCacheKey.rawString("file5"), data: Self.dummy1KFile)
		return (file1, file2, file3, file4, file5)
	}

	/// Verifies basic add, remove, and retrieval operations with sequential async ops.
	@Test func cacheAddRemove() async {
		let (cache, done) = generateDiskCache()
		defer { done() }

		let (file1, file2, file3, file4, file5) = Self.fileAssortment()

		// Given four data writes dispatched concurrently.
		async let file1Load: Void = cache.setData(file1.data, key: file1.key)
		async let file2Load: Void = cache.setData(file2.data, key: file2.key)
		async let file3Load: Void = cache.setData(file3.data, key: file3.key)
		async let file4Load: Void = cache.setData(file4.data, key: file4.key)

		await file1Load
		await file2Load
		await file3Load
		await file4Load

		// Then all written data is retrievable and a non-written key returns nil.
		#expect(cache.getData(for: file1.key) == file1.data)
		#expect(cache.getData(for: file2.key) == file2.data)
		#expect(cache.getData(for: file3.key) == file3.data)
		#expect(cache.getData(for: file4.key) == file4.data)
		#expect(cache.getData(for: file5.key) == nil)

		// When key1 is removed.
		cache.remove(objectFor: file1.key)

		// Then key1 is gone but key2, key3, and key4 remain intact.
		#expect(cache.getData(for: file1.key) == nil)
		#expect(cache.getData(for: file2.key) == file2.data)
		#expect(cache.getData(for: file3.key) == file3.data)
		#expect(cache.getData(for: file4.key) == file4.data)
		#expect(cache.getData(for: file5.key) == nil)

		// When key3 is also removed.
		cache.remove(objectFor: file3.key)

		// Then only key2 and key4 remain.
		#expect(cache.getData(for: file1.key) == nil)
		#expect(cache.getData(for: file2.key) == file2.data)
		#expect(cache.getData(for: file3.key) == nil)
		#expect(cache.getData(for: file4.key) == file4.data)
		#expect(cache.getData(for: file5.key) == nil)
	}

	/// Verifies that reset clears all stored data (size and count).
	@Test func reset() async {
		let (cache, done) = generateDiskCache()
		defer { done() }

		let file1 = Self.fileAssortment().file1

		// Given a single data write.
		async let file1Load: Void = cache.setData(file1.data, key: file1.key)

		await file1Load

		// Then the cache reflects one 1024-byte entry.
		#expect(1024 == cache.size)
		#expect(1 == cache.count)

		// When the cache is reset.
		cache.reset()

		// Then size and count both drop to zero.
		#expect(0 == cache.size)
		#expect(0 == cache.count) // swiftlint:disable:this empty_count
	}

	/// Verifies that exceeding capacity evicts the oldest entries in LRU-ish order.
	///
	/// Capacity is set to 2 KB (2048 bytes). Each test file is 1 KB.
	/// Expecting: writes 4–5 cause eviction of older keys.
	@Test func cacheCapacity() {
		let (cache, done) = generateDiskCache()
		defer { done() }
		cache.capacity = 1024 * 2

		let (file1, file2, file3, file4, file5) = Self.fileAssortment()

		// When file 1 (1 KB) is written.
		cache.setData(file1.data, key: file1.key)
		// Then it is retrievable.
		#expect(file1.data == cache.getData(for: file1.key))

		// When file 2 (2 KB) is written.
		cache.setData(file2.data, key: file2.key)
		// Then file 1 is evicted (over capacity) and file 2 persists.
		#expect(cache.getData(for: file1.key) == nil)
		#expect(file2.data == cache.getData(for: file2.key))

		// When file 3 (5 KB) is written — all previous evicted.
		cache.setData(file3.data, key: file3.key)
		#expect(cache.getData(for: file1.key) == nil)
		#expect(cache.getData(for: file2.key) == nil)
		#expect(cache.getData(for: file3.key) == nil)

		// When file 4 (1 KB) is written.
		cache.setData(file4.data, key: file4.key)
		// Then file 4 persists; file 3 is evicted.
		#expect(cache.getData(for: file1.key) == nil)
		#expect(cache.getData(for: file2.key) == nil)
		#expect(cache.getData(for: file3.key) == nil)
		#expect(file4.data == cache.getData(for: file4.key))

		// When file 5 (1 KB) is written.
		cache.setData(file5.data, key: file5.key)
		// Then both file 4 and file 5 persist (total 2 KB fits capacity).
		#expect(cache.getData(for: file1.key) == nil)
		#expect(cache.getData(for: file2.key) == nil)
		#expect(cache.getData(for: file3.key) == nil)
		#expect(file4.data == cache.getData(for: file4.key))
		#expect(file5.data == cache.getData(for: file5.key))
	}

	@Test func sizeCountRaceOnConcurrentWrites() async {
		let (cache, done) = generateDiskCache()
		defer { done() }

		let items = 128
		let itemSize: UInt64 = 1024 * 100 // 100KB each = longer I/O = bigger race window

		for iteration in 0..<50 {
			// 1. Clear
			cache.reset()
			#expect(cache.isEmpty == true)
			#expect(cache.size == 0)

			// 2. Write all keys concurrently
			await withTaskGroup { group in
				for i in 0..<items {
					group.addTask {
						let data = Data(repeating: UInt8(i), count: Int(itemSize))
						cache.setData(data, key: .rawString("s_\(iteration)_\(i)"))
					}
				}

				await group.waitForAll()
			}

			// 3. Verify
			let expectedSize = UInt64(items) * itemSize
			#expect(
				cache.count == items,
				"Iter \(iteration): count wanted \(items) got \(cache.count)")
			#expect(
				cache.size == expectedSize,
				"Iter \(iteration): size wanted \(expectedSize) got \(cache.size)")
		}
	}

	private func generateDiskCache(
		forTest testName: String = #function
	) -> (cache: DefaultNetworkDiskCache, done: () -> Void) {
		let logger = Logger(label: "\(testName) - Disk Test")
		let cache = DefaultNetworkDiskCache(cacheName: "\(testName)-DiskCache", logger: logger)

		cache.reset()
		return (cache, cache.reset)
	}
}
