import Foundation
import NetworkHandler
import Testing

/// I've had past experience where NSCache stored asynchronously. As in an immediate retrieval of a set value returned
/// nil, but a delayed retrieval got the value. This stress test is designed to validate if that's still the case.
/// as of this writing (5/15/26), it appears to be resolved, but if I encounter again, I will update this test to
/// target the scenario.
struct StressTestNSCache {
	typealias Box = DefaultNetworkCache.Box

	/// Verifies basic set/overwrite/reads work as expected.
	///
	/// Tests that NSCache returns correct values after each individual operation.
	@Test func basic() async throws {
		// Given a fresh NSCache.
		let cache = NSCache<Box<String>, Box<Data>>()

		// When a single value is stored.
		cache.setObject(.init(Data([1])), forKey: .init("foo"))

		// Then it is immediately retrievable.
		#expect(cache.object(forKey: .init("foo"))?.value == Data([1]))

		// When a second value overwrites the first.
		cache.setObject(.init(Data([1, 2])), forKey: .init("bar"))

		// Then the new key returns its value (and foo persists).
		#expect(cache.object(forKey: .init("foo"))?.value == Data([1]))
		#expect(cache.object(forKey: .init("bar"))?.value == Data([1, 2]))

		// When the first key is overwritten.
		cache.setObject(.init(Data([1, 2, 3])), forKey: .init("foo"))

		// Then both keys reflect the latest state.
		#expect(cache.object(forKey: .init("foo"))?.value == Data([1, 2, 3]))
		#expect(cache.object(forKey: .init("bar"))?.value == Data([1, 2]))
	}

	/// Stress test: 10,000 sequential writes to the same key.
	///
	/// Ensures every value written at index i is immediately readable.
	@Test func cacheSync() async throws {
		// Given a single-key cache.
		let cache = NSCache<Box<String>, Box<Int>>()

		// When 10,000 sequential writes occur.
		for i in 0...9999 {
			cache.setObject(Box(i), forKey: Box("key"))

			// Then every written value is immediately retrievable.
			#expect(cache.object(forKey: Box("key"))?.value == i)
		}
	}

	/// Stress test: 10,000 concurrent writes across task group tasks.
	///
	/// Validates that concurrent access does not corrupt stored values.
	@Test func cacheSyncAndAsync() async throws {
		// Given a shared cache.
		let cache = NSCache<Box<String>, Box<Int>>()

		// When 10,000 tasks each write-and-read concurrently.
		await withTaskGroup { group in
			for i in 0...9999 {
				group.addTask {
					cache.setObject(Box(i), forKey: Box("key-\(i)"))
					#expect(cache.object(forKey: Box("key-\(i)"))?.value == i)
				}
			}
		}
	}
}

extension NSCache: @unchecked @retroactive Sendable {}
