import Logging
import NetworkHandler
import SwiftPizzaSnips

public final class NetworkCacheMock: NetworkCachable {
	public let name: String

	public var countLimit: Int {
		get { 0 }
		set { }
	}
	public var totalCostLimit: Int {
		get { 0 }
		set { }
	}

	public let logger: Logger

	private let lock = MutexLock()
	nonisolated(unsafe)
	private var store: [NetworkCacheKey: NetworkCacheStore] = [:]

	init(
		name: String,
		logger: Logger
	) {
		self.name = name
		self.logger = logger
	}

	public func cachedItem(for key: NetworkCacheKey) -> NetworkCacheStore? {
		lock.withLock { store[key] }
	}

	public func setCachedItem(_ newValue: NetworkCacheStore?, for key: NetworkCacheKey) {
		lock.withLock { store[key] = newValue }
	}

	public func reset() {
		lock.withLock { store = [:] }
	}
}
