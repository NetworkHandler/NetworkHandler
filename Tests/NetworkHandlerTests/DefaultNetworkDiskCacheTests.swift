import Foundation
import Logging
@testable import NetworkHandler
import Testing

class DefaultNetworkDiskCacheTests {
	/// A 1 KB dummy data payload for caching tests.
	static let dummy1KFile = Data(repeating: 0, count: 1024)
	/// A 2 KB dummy data payload for caching tests.
	static let dummy2KFile = Data(repeating: 0, count: 1024 * 2)
	/// A 5 KB dummy data payload for caching tests.
	static let dummy5KFile = Data(repeating: 0, count: 1024 * 5)

	/// Creates five sample key/data pairs for cache test scenarios.
	///
	/// Returns keys `"file1"` through `"file5"` paired with 1 KB, 2 KB, 5 KB, 1 KB, and 1 KB payloads,
	/// producing an ascending/descending mix to exercise cache ordering and eviction.
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

	/// Tests that data can be added and retrieved, and removed from a disk cache.
	///
	/// - Given: four data writes dispatched concurrently via `setData`.
	/// - When: all writes complete, verify each key is retrievable and a fifth non-written key returns `nil`.
	/// - When: `file1.key` is removed, verify it is gone while `file2.key`–`file4.key` remain.
	/// - When: `file3.key` is also removed, verify only `file2.key` and `file4.key` remain.
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

	/// Tests that `reset()` clears all stored data and resets `size` and `count` to zero.
	///
	/// - Given: a single 1 KB data entry written to the cache.
	/// - When: `reset()` is called on the cache.
	/// - Then: `size` and `count` both drop to zero, and no data remains retrievable.
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

	/// Tests cache eviction when data exceeds the configured capacity.
	///
	/// Capacity is 2 KB (2048 bytes). Sequential writes exercise eviction:
	///
	/// - Given: `file1` (1 KB) is written and remains retrievable.
	/// - When: `file2` (2 KB) is written, evicting `file1` since it exceeds capacity.
	/// - When: `file3` (5 KB) is written, evicting `file2` (all entries exceed capacity).
	/// - When: `file4` (1 KB) is written, evicting `file3` since `file3` still exceeds capacity.
	/// - When: `file5` (1 KB) is written, both `file4` and `file5` persist (2 KB total fits capacity).
	///
	/// Verifies eviction preserves data within capacity while removing the oldest entries.
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

	// MARK: - Race Condition Regression
	/// Tests that concurrent `setData` calls do not corrupt `size` and `count` tracking.
	///
	/// - Given: an empty cache.
	/// - When: 128 keys are written concurrently (each 100 KB to widen the I/O race window).
	/// - Then: `size` and `count` are verified to be correct after each of 50 iterations.
	///
	/// NOTE: This test was created to reproduce a data race on `size` and `count`
	/// where concurrent `setData` calls across different keys triggered lost updates.
	///
	/// The test failed on the original implementation and now passes after the fix
	/// (locking size/count mutations under `globalLock`).
	///
	/// **However: passing does NOT prove the race is fully eliminated.** Race conditions
	/// are probabilistic — depending on task scheduling, the critical window may or may
	/// not be exposed in any given run. The locking fix is what guarantees correctness,
	/// not the test result. This test exists as a sanity check and early warning, not
	/// as a proof of correctness.
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

	/// Creates a `DefaultNetworkDiskCache` configured for isolated test execution.
	///
	/// The cache is reset before returning and provides a cleanup closure. Uses the
	/// calling test function name for logger and cache naming so each test produces
	/// isolated artifacts.
	private func generateDiskCache(
		forTest testName: String = #function
	) -> (cache: DefaultNetworkDiskCache, done: () -> Void) {
		let logger = Logger(label: "\(testName) - Disk Test")
		let cache = DefaultNetworkDiskCache(cacheName: "\(testName)-DiskCache", logger: logger)

		cache.reset()
		return (cache, cache.reset)
	}
}
