import SwiftPizzaSnips

@dynamicMemberLookup
final package class Sendify<NonSendable>: @unchecked Sendable {
	public var value: NonSendable {
		get { lock.withLock { _value } }
		set { lock.withLock { _value = newValue } }
	}

	private var _value: NonSendable

	private let lock = MutexLock()

	public init(_ value: NonSendable) {
		lock.lock()
		defer { lock.unlock() }
		self._value = value
	}

	package subscript<T>(dynamicMember member: WritableKeyPath<NonSendable, T>) -> T {
		get { value[keyPath: member] }
		set { value[keyPath: member] = newValue }
	}

	package subscript<T>(dynamicMember member: KeyPath<NonSendable, T>) -> T {
		value[keyPath: member]
	}
}

extension Sendify: Equatable where NonSendable: Equatable {
	package static func == (lhs: Sendify<NonSendable>, rhs: Sendify<NonSendable>) -> Bool {
		lhs.value == rhs.value
	}
}
extension Sendify: Hashable where NonSendable: Hashable {
	package func hash(into hasher: inout Hasher) {
		hasher.combine(value)
	}
}
