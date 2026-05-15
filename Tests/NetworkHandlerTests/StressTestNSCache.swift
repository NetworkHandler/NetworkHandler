import Foundation
import Testing
import NetworkHandler

/// I've had past experience where NSCache stored asynchronously. As in an immediate retrieval of a set value returned
/// nil, but a delayed retrieval got the value. This stress test is designed to validate if that's still the case.
/// as of this writing (5/15/26), it appears to be resolved, but if I encounter again, I will update this test to
/// target the scenario.
struct StressTestNSCache {
	@Test func basic() async throws {
		let cache = NSCache<Box<String>, Box<Data>>()

		cache.setObject(.init(Data([1])), forKey: .init("foo"))
		#expect(cache.object(forKey: .init("foo"))?.value == Data([1]))
		cache.setObject(.init(Data([1, 2])), forKey: .init("bar"))
		#expect(cache.object(forKey: .init("foo"))?.value == Data([1]))
		#expect(cache.object(forKey: .init("bar"))?.value == Data([1, 2]))
		cache.setObject(.init(Data([1, 2, 3])), forKey: .init("foo"))
		#expect(cache.object(forKey: .init("foo"))?.value == Data([1, 2, 3]))
		#expect(cache.object(forKey: .init("bar"))?.value == Data([1, 2]))
	}

	@Test func cacheSync() async throws {
		let cache = NSCache<Box<String>, Box<Int>>()

		for i in 0...9999 {
			cache.setObject(Box(i), forKey: Box("key"))
			#expect(cache.object(forKey: Box("key"))?.value == i)
		}
	}

	@Test func cacheSyncAndAsync() async throws {
		let cache = NSCache<Box<String>, Box<Int>>()

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

@dynamicMemberLookup
private final class Box<Wrapped> {
	var value: Wrapped

	init(_ value: Wrapped) {
		self.value = value
	}

	subscript<T>(dynamicMember member: WritableKeyPath<Wrapped, T>) -> T {
		get { value[keyPath: member] }
		set { value[keyPath: member] = newValue }
	}

	subscript<T>(dynamicMember member: KeyPath<Wrapped, T>) -> T {
		value[keyPath: member]
	}
}

extension Box: Equatable where Wrapped: Equatable {
	static func == (lhs: Box<Wrapped>, rhs: Box<Wrapped>) -> Bool {
		lhs.value == rhs.value
	}
}

extension Box: Hashable where Wrapped: Hashable {
	func hash(into hasher: inout Hasher) {
		hasher.combine(value)
	}
}

extension Box: @unchecked Sendable where Wrapped: Sendable {}

extension Box: CustomStringConvertible where Wrapped: CustomStringConvertible {
	var description: String { value.description }
}

extension Box: CustomDebugStringConvertible where Wrapped: CustomDebugStringConvertible {
	var debugDescription: String { value.debugDescription }
}

extension NSCache: @unchecked @retroactive Sendable {}
