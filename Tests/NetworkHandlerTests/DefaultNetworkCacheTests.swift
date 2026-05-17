import Foundation
import Logging
@testable import NetworkHandler
import PizzaMacros
import Testing
import TestSupport

struct DefaultNetworkCacheTests {
	/// I've determined that NSCache's version of thread safety is that it doesn't block, so there are times that you
	/// might set a value, checking that it exists immediately afterwards only to find it's not there... But it will show
	/// up eventually. This, naturally, messes with tests and causes this test to be unreliable.
	/// Note: Due to NSCache's async storage, these tests may flakily fail.
	///
	///
	/// see idea in NetworkHandler/DefaultNetworkCache.swift

	/// Sets a key and verifies the latest value is returned.
	///
	/// Given an empty cache, when a key is set, then nil should be returned initially
	/// and the stored data should be retrievable afterward.
	@Test func cacheSet() {
		// Given a cache.
		let cache = makeTestableCache()
		let key = makeCacheKeys().first
		let store = makeCacheStores().first

		// When nothing is stored yet.
		#expect(cache[key] == nil)

		// When the key is set.
		cache[key] = store

		// Then the stored data is retrievable.
		#expect(store?.data == cache[key]?.data)
	}

	/// Overwrites a key and verifies the latest value is returned.
	///
	/// Given a cache with one value, when that key is overwritten, then the new value
	/// should replace the old one.
	@Test func cacheOverwrite() {
		let cache = makeTestableCache()
		let key = makeCacheKeys().first
		let stores = makeCacheStores()

		// When the key is set with the first store.
		cache[key] = stores.first

		// Then that value is retrievable.
		#expect(stores.first?.data == cache[key]?.data)

		// When the same key is overwritten with the second store.
		cache[key] = stores.second

		// Then the new value replaces the old.
		#expect(stores.second?.data == cache[key]?.data)
	}

	/// Verifies each key stores and retrieves independently.
	///
	/// Given a cache with multiple keys set, when each key is accessed, then
	/// the correct value is returned for each.
	@Test func cacheRetrievalWithMultipleKeys() {
		let cache = makeTestableCache()
		let keys = makeCacheKeys()
		let stores = makeCacheStores()

		// When both keys are set.
		cache[keys.first] = stores.first
		cache[keys.second] = stores.second

		// Then each key independently resolves to its store.
		#expect(stores.first?.data == cache[keys.first]?.data)
		#expect(stores.second?.data == cache[keys.second]?.data)
	}

	/// Setting a key to nil removes it, and other keys remain intact.
	///
	/// Given a cache with two keys set, when one is cleared by assigning nil, then
	/// it returns nil and the other key remains.
	@Test func cacheRemoveValueBySettingNil() {
		let cache = makeTestableCache()
		let keys = makeCacheKeys()
		let stores = makeCacheStores()

		// Given two keys are set.
		cache[keys.second] = stores.first
		cache[keys.third] = stores.first

		// When one key is cleared by assignment.
		cache[keys.third] = nil

		// Then that key returns nil and the other stays intact.
		#expect(cache[keys.third] == nil)
		#expect(stores.first?.data == cache[keys.second]?.data)
	}

	/// Removing via `remove(objectFor:)` clears the key and returns the value.
	///
	/// Given a cache with one key set, when `remove(objectFor:)` is called, then
	/// the key should return nil and the removal returns the original value.
	@Test func cacheRemoveObject() {
		let cache = makeTestableCache()
		let keys = makeCacheKeys()
		let stores = makeCacheStores()

		// Given a key is set.
		cache[keys.first] = stores.first

		// When the key is removed via method.
		let removed = cache.remove(objectFor: keys.first)

		// Then the key returns nil and removal returns the correct value.
		#expect(cache[keys.first] == nil)
		#expect(stores.first?.data == removed?.data)
	}

	/// Verifies that reset clears all keys.
	///
	/// Given a cache with multiple keys set, when `reset()` is called, then
	/// all keys should return nil.
	@Test func cacheReset() {
		let cache = makeTestableCache()
		let keys = makeCacheKeys()
		let stores = makeCacheStores()

		// When multiple keys are set.
		cache[keys.first] = stores.first
		cache[keys.second] = stores.first
		cache[keys.third] = stores.first
		#expect(cache[keys.first] != nil)
		#expect(cache[keys.second] != nil)
		#expect(cache[keys.third] != nil)

		// When reset is called.
		cache.reset()

		// Then all keys return nil.
		#expect(cache[keys.first] == nil)
		#expect(cache[keys.second] == nil)
		#expect(cache[keys.third] == nil)
	}

	// MARK: - Helpers

	private func makeTestableCache() -> DefaultNetworkCache {
		DefaultNetworkCache(
			name: "Testable Cache",
			logger: Logger(label: "Testing cache"),
			diskCache: NetworkCacheMock(
				name: "Fake Disk Cache",
				logger: Logger(label: "Fake Disk Cache")))
	}

	private func makeCacheStores() -> (first: NetworkCacheStore?, second: NetworkCacheStore?) {
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

		return (
			first: NetworkCacheStore(response: response1, data: data1),
			second: NetworkCacheStore(response: response2, data: data2)
		)
	}

	// swiftlint:disable:next large_tuple
	private func makeCacheKeys() -> (first: NetworkCacheKey, second: NetworkCacheKey, third: NetworkCacheKey) {
		return (
			first: .urlMethod(URL(fileURLWithPath: "/"), .get),
			second: .urlMethod(URL(fileURLWithPath: "/etc"), .get),
			third: .urlMethod(URL(fileURLWithPath: "/usr"), .get)
		)
	}
}
