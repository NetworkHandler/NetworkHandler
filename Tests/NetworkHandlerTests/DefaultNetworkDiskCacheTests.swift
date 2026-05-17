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

	@Test func cacheAddRemove() async {
		let (cache, done) = generateDiskCache()
		defer { done() }

		let (file1, file2, file3, file4, file5) = Self.fileAssortment()

		async let file1Load: Void = cache.setData(file1.data, key: file1.key)
		async let file2Load: Void = cache.setData(file2.data, key: file2.key)
		async let file3Load: Void = cache.setData(file3.data, key: file3.key)
		async let file4Load: Void = cache.setData(file4.data, key: file4.key)

		await file1Load
		await file2Load
		await file3Load
		await file4Load

		#expect(cache.getData(for: file1.key) == file1.data)
		#expect(cache.getData(for: file2.key) == file2.data)
		#expect(cache.getData(for: file3.key) == file3.data)
		#expect(cache.getData(for: file4.key) == file4.data)
		#expect(cache.getData(for: file5.key) == nil)

		cache.remove(objectFor: file1.key)
		#expect(cache.getData(for: file1.key) == nil)
		#expect(cache.getData(for: file2.key) == file2.data)
		#expect(cache.getData(for: file3.key) == file3.data)
		#expect(cache.getData(for: file4.key) == file4.data)
		#expect(cache.getData(for: file5.key) == nil)

		cache.remove(objectFor: file3.key)
		#expect(cache.getData(for: file1.key) == nil)
		#expect(cache.getData(for: file2.key) == file2.data)
		#expect(cache.getData(for: file3.key) == nil)
		#expect(cache.getData(for: file4.key) == file4.data)
		#expect(cache.getData(for: file5.key) == nil)
	}

	@Test func reset() async {
		let (cache, done) = generateDiskCache()
		defer { done() }

		let file1 = Self.fileAssortment().file1

		async let file1Load: Void = cache.setData(file1.data, key: file1.key)

		await file1Load

		#expect(1024 == cache.size)
		#expect(1 == cache.count)

		cache.resetCache()

		#expect(0 == cache.size)
		#expect(0 == cache.count) // swiftlint:disable:this empty_count
	}

	@Test func cacheCapacity() {
		let (cache, done) = generateDiskCache()
		defer { done() }
		cache.capacity = 1024 * 2

		let (file1, file2, file3, file4, file5) = Self.fileAssortment()

		cache.setData(file1.data, key: file1.key)
		#expect(file1.data == cache.getData(for: file1.key))

		cache.setData(file2.data, key: file2.key)
		#expect(cache.getData(for: file1.key) == nil)
		#expect(file2.data == cache.getData(for: file2.key))

		cache.setData(file3.data, key: file3.key)
		#expect(cache.getData(for: file1.key) == nil)
		#expect(cache.getData(for: file2.key) == nil)
		#expect(cache.getData(for: file3.key) == nil)

		cache.setData(file4.data, key: file4.key)
		#expect(cache.getData(for: file1.key) == nil)
		#expect(cache.getData(for: file2.key) == nil)
		#expect(cache.getData(for: file3.key) == nil)
		#expect(file4.data == cache.getData(for: file4.key))

		cache.setData(file5.data, key: file5.key)
		#expect(cache.getData(for: file1.key) == nil)
		#expect(cache.getData(for: file2.key) == nil)
		#expect(cache.getData(for: file3.key) == nil)
		#expect(file4.data == cache.getData(for: file4.key))
		#expect(file5.data == cache.getData(for: file5.key))
	}

	private func generateDiskCache(
		forTest testName: String = #function
	) -> (cache: DefaultNetworkDiskCache, done: () -> Void) {
		let logger = Logger(label: "\(testName) - Disk Test")
		let cache = DefaultNetworkDiskCache(cacheName: "\(testName)-DiskCache", logger: logger)

		cache.resetCache()
		return (cache, cache.resetCache)
	}
}
