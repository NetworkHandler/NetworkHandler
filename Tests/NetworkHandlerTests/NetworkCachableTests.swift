import Foundation
import HTTPTypes
import NetworkHandler
import PizzaMacros
import Testing

struct NetworkCachableTests {
	/// Verifies a cache key serializes to its raw representation and
	/// can be reconstructed back into an equal key.
	@Test func cacheKeyRoundtrip() async throws {
		let base = NetworkCacheKey.urlMethod(#URL("https://foo.bar"), .get)

		// When the key is serialized.
		let raw = base.rawValue

		// And deserialized.
		let recontructed = NetworkCacheKey(rawValue: raw)

		// Then the original and reconstructed keys are equal.
		#expect(recontructed == base)
	}
}
