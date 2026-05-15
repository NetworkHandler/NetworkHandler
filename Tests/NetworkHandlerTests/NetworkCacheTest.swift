import Logging
@testable import NetworkHandler
import NetworkHandlerMockingEngine
import TestSupport
import XCTest

class NetworkCacheTest: NetworkHandlerBaseTest<MockingEngine> {
	func waitForCacheToFinishActivity(_ cache: DefaultNetworkDiskCache, timeout: TimeInterval = 10) {
		let isActive = expectation(
			for: .init(
				block: { anyCache, _ in
					guard let cache = anyCache as? DefaultNetworkDiskCache else { return false }
					return !cache.isActive
				}),
			evaluatedWith: cache,
			handler: nil)

		wait(for: [isActive], timeout: timeout)
	}

	func generateDiskCache(named name: String? = nil) -> DefaultNetworkDiskCache {
		let logger = Logger(label: "Disk Test")
		let cache = DefaultNetworkDiskCache(cacheName: name, logger: logger)

		let reset = expectation(
			for: .init(
				block: { anyCache, _ in
					guard let cache = anyCache as? DefaultNetworkDiskCache else { return false }
					return !cache.isActive
				}),
			evaluatedWith: cache,
			handler: nil)

		wait(for: [reset], timeout: 10)

		cache.resetCache()
		return cache
	}
}
