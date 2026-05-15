import Foundation
import HTTPTypes
import NetworkHandler
import PizzaMacros
import Testing

struct NetworkCachableTests {
	@Test func cacheKeyRoundtrip() async throws {
		let base = NetworkCacheKey.urlMethod(#URL("https://foo.bar"), .get)

		let raw = base.rawValue

		let recontructed = NetworkCacheKey(rawValue: raw)

		#expect(recontructed == base)
	}
}
