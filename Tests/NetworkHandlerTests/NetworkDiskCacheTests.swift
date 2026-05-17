import Logging
@testable import NetworkHandler
import NetworkHandlerMockingEngine
import XCTest

class NetworkDiskCacheTests: XCTestCase {
	nonisolated(unsafe)
	static var dummy1KFile = Data(repeating: 0, count: 1024)
	nonisolated(unsafe)
	static var dummy2KFile = Data(repeating: 0, count: 1024 * 2)
	nonisolated(unsafe)
	static var dummy5KFile = Data(repeating: 0, count: 1024 * 5)

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

	override func tearDown() {
		let cache = generateDiskCache()
		cache.resetCache()
	}

	func testCacheAddRemove() async {
		let logger = Logger(label: #function)
		let cache = DefaultNetworkDiskCache(logger: logger)
		cache.resetCache()

		let (file1, file2, file3, file4, file5) = Self.fileAssortment()

		async let file1Load: Void = cache.setData(file1.data, key: file1.key)
		async let file2Load: Void = cache.setData(file2.data, key: file2.key)
		async let file3Load: Void = cache.setData(file3.data, key: file3.key)
		async let file4Load: Void = cache.setData(file4.data, key: file4.key)

		await file1Load
		await file2Load
		await file3Load
		await file4Load

		XCTAssertEqual(cache.getData(for: file1.key), file1.data)
		XCTAssertEqual(cache.getData(for: file2.key), file2.data)
		XCTAssertEqual(cache.getData(for: file3.key), file3.data)
		XCTAssertEqual(cache.getData(for: file4.key), file4.data)
		XCTAssertNil(cache.getData(for: file5.key))

		cache.remove(objectFor: file1.key)
		XCTAssertNil(cache.getData(for: file1.key))
		XCTAssertEqual(cache.getData(for: file2.key), file2.data)
		XCTAssertEqual(cache.getData(for: file3.key), file3.data)
		XCTAssertEqual(cache.getData(for: file4.key), file4.data)
		XCTAssertNil(cache.getData(for: file5.key))

		cache.remove(objectFor: file3.key)
		XCTAssertNil(cache.getData(for: file1.key))
		XCTAssertEqual(cache.getData(for: file2.key), file2.data)
		XCTAssertNil(cache.getData(for: file3.key))
		XCTAssertEqual(cache.getData(for: file4.key), file4.data)
		XCTAssertNil(cache.getData(for: file5.key))
	}

	func testReset() async {
		let cache = generateDiskCache()

		let file1 = Self.fileAssortment().file1

		async let file1Load: Void = cache.setData(file1.data, key: file1.key)

		await file1Load

		XCTAssertEqual(1024, cache.size)
		XCTAssertEqual(1, cache.count)

		cache.resetCache()

		XCTAssertEqual(0, cache.size)
		XCTAssertEqual(0, cache.count)
	}

	func testCacheCapacity() {
		let cache = generateDiskCache()
		cache.capacity = 1024 * 2

		let (file1, file2, file3, file4, file5) = Self.fileAssortment()

		cache.setData(file1.data, key: file1.key)
		XCTAssertEqual(file1.data, cache.getData(for: file1.key))

		cache.setData(file2.data, key: file2.key)
		XCTAssertNil(cache.getData(for: file1.key))
		XCTAssertEqual(file2.data, cache.getData(for: file2.key))

		cache.setData(file3.data, key: file3.key)
		XCTAssertNil(cache.getData(for: file1.key))
		XCTAssertNil(cache.getData(for: file2.key))
		XCTAssertNil(cache.getData(for: file3.key))

		cache.setData(file4.data, key: file4.key)
		XCTAssertNil(cache.getData(for: file1.key))
		XCTAssertNil(cache.getData(for: file2.key))
		XCTAssertNil(cache.getData(for: file3.key))
		XCTAssertEqual(file4.data, cache.getData(for: file4.key))

		cache.setData(file5.data, key: file5.key)
		XCTAssertNil(cache.getData(for: file1.key))
		XCTAssertNil(cache.getData(for: file2.key))
		XCTAssertNil(cache.getData(for: file3.key))
		XCTAssertEqual(file4.data, cache.getData(for: file4.key))
		XCTAssertEqual(file5.data, cache.getData(for: file5.key))
	}

	private func generateDiskCache(named name: String? = nil) -> DefaultNetworkDiskCache {
		let logger = Logger(label: "Disk Test")
		let cache = DefaultNetworkDiskCache(cacheName: name, logger: logger)

		cache.resetCache()
		return cache
	}
}
