import Foundation
import Logging
@testable import NetworkHandler
import PizzaMacros
import Testing
import TestSupport

struct DefaultNetworkCacheTests {
	/// Verifies the cache respects configurable count limits.
	@Test func cacheCountLimit() {
		// Given a fresh cache with its default count limit.
		let cache = makeTestableCache()

		// When the count limit is changed to 5.
		let initialLimit = cache.countLimit
		cache.countLimit = 5

		// Then the count limit reflects the new value.
		#expect(5 == cache.countLimit)

		// And when it is restored to the original value.
		cache.countLimit = initialLimit

		// Then the count limit reverts.
		#expect(initialLimit == cache.countLimit)
	}

	/// Verifies the cache respects configurable total cost limits.
	@Test func cacheTotalCostLimit() {
		// Given a fresh cache with its default total cost limit.
		let cache = makeTestableCache()

		// When the total cost limit is changed to 5.
		let initialLimit = cache.totalCostLimit
		cache.totalCostLimit = 5

		// Then the total cost limit reflects the new value.
		#expect(5 == cache.totalCostLimit)

		// And when it is restored to the original value.
		cache.totalCostLimit = initialLimit

		// Then the total cost limit reverts.
		#expect(initialLimit == cache.totalCostLimit)
	}

	/// I've determined that NSCache's version of thread safety is that it doesn't block, so there are times that you
	/// might set a value, checking that it exists immediately afterwards only to find it's not there... But it will show
	/// up eventually. This, natually, messes with tests and causes this test to be unreliable. I'm working on
	/// finding a workaround to test, but in the meantime, this test failing isn't considered a real fail.
	///
	/// see idea in DefaultNetworkCache class
	@Test func cacheAddRemove() {
		// Given two distinct data payloads and their corresponding cached items.
		let data1 = Data([1, 2, 3, 4, 5])
		let data2 = Data(data1.reversed())

		let response1 = EngineResponseHeader(
			status: 200,
			url: #URL("https://redeggproductions.com"),
			headers: [
				.contentLength: "\(1024)"
			])
		let response2 = EngineResponseHeader(
			status: 200,
			url: #URL("https://github.com"),
			headers: [
				.contentLength: "\(2048)"
			])

		let cachedItem1 = NetworkCacheStore(response: response1, data: data1)
		let cachedItem2 = NetworkCacheStore(response: response2, data: data2)

		let cache = makeTestableCache()

		let key1: NetworkCacheKey = .urlMethod(URL(fileURLWithPath: "/"), .get)
		let key2: NetworkCacheKey = .urlMethod(URL(fileURLWithPath: "/etc"), .get)
		let key3: NetworkCacheKey = .urlMethod(URL(fileURLWithPath: "/usr"), .get)

		// When key1 is populated with item 1 and then overwritten with item 2.
		cache[key1] = cachedItem1
		#expect(cachedItem1.data == cache[key1]?.data)
		cache[key1] = cachedItem2
		#expect(cachedItem2.data == cache[key1]?.data)

		// When key2 is populated with item 1 alongside key1 holding item 2.
		cache[key2] = cachedItem1
		#expect(cachedItem1.data == cache[key2]?.data)
		#expect(cachedItem2.data == cache[key1]?.data)

		// When key3 is also populated with item 1, then cleared.
		cache[key3] = cachedItem1
		#expect(cachedItem1.data == cache[key3]?.data)
		cache[key3] = nil
		#expect(cache[key3] == nil)
		#expect(cachedItem1.data == cache[key2]?.data)
		#expect(cachedItem2.data == cache[key1]?.data)

		// When key3 is repopulated and explicitly removed.
		cache[key3] = cachedItem1
		#expect(cachedItem1.data == cache[key3]?.data)
		let removed = cache.remove(objectFor: key3)
		#expect(cache[key3] == nil)
		#expect(cachedItem1.data == removed?.data)

		// When the entire cache is reset.
		cache.reset()
		
		// Then all keys return nil.
		#expect(cache[key1] == nil)
		#expect(cache[key2] == nil)
		#expect(cache[key3] == nil)
	}

	// add test(s) where in memory is a miss, but on disk isn't - use mocked disk cache

	// MARK: - Helpers

	private func makeTestableCache() -> DefaultNetworkCache {
		DefaultNetworkCache(
			name: "Testable Cache",
			logger: Logger(label: "Testing cache"),
			diskCache: NetworkCacheMock(
				name: "Fake Disk Cache",
				logger: Logger(label: "Fake Disk Cache")))
	}
}
