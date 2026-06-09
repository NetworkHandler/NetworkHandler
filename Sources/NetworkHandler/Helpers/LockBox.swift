import SwiftPizzaSnips

/// A lock-protected container for sharing values across concurrency boundaries.
///
/// Provides thread-safe access to a stored value through a mutex lock. For reference types,
/// the lock protects the pointer/reference itself, not the internals of the referenced object.
///
/// **API availability depends on `Wrapped`'s `Sendable` conformance:**
///
/// When `Wrapped` is not `Sendable`:
/// - Read individual `Sendable` properties via `@dynamicMemberLookup`
/// - Use `withLock { }` for full access or mutations
/// - Cannot be escaped; mutations require `withLock { }`
///
/// When `Wrapped` is `Sendable`:
/// - All of the above, plus `.value` property, writable key path access,
///   and the box itself conforms to `Sendable`
///
/// Use `withLock { }` for compound operations or when an operation on a referenced
/// object must be atomic with the pointer read:
///
/// ```swift
/// // Atomic: pointer read and action are a single unit
/// box.withLock { value in value?.doThing() }
/// ```
///
/// Note: `box.value.doThing()` reads the value under the lock but executes `doThing()`
/// outside it. For operations that must be atomic with the lock, use `withLock { }`.
@dynamicMemberLookup
final package class LockBox<Wrapped> {
	private let isolationLock = MutexLock()

	/// The stored value.
	private var _value: Wrapped

	/// Returns the value at the given key path when `Wrapped` conforms to `Sendable`.
	///
	/// Thread safe.
	package subscript<T: Sendable>(dynamicMember member: KeyPath<Wrapped, T>) -> T {
		withLock {
			$0[keyPath: member]
		}
	}

	/// Creates a new lock box containing `value`.
	///
	/// Thread safe.
	package init(_ value: Wrapped) {
		isolationLock.lock()
		defer { isolationLock.unlock() }
		self._value = value
	}

	/// Executes `block` with exclusive, thread safe access to the wrapped value.
	///
	/// Use for compound operations (read + modify) or when an operation on a referenced
	/// object must be atomic with the pointer read.
	package func withLock<Success, Failure: Error>(
		_ block: (inout Wrapped) throws(Failure) -> sending Success
	) throws(Failure) -> sending Success {
		isolationLock.lock()
		defer { isolationLock.unlock() }
		do throws(Failure) {
			return try block(&_value)
		} catch {
			throw error
		}
	}
}

extension LockBox: ExpressibleByNilLiteral where Wrapped: ExpressibleByNilLiteral {
	/// Creates a lock box initialized with a `nil` value.
	///
	/// The wrapped type must conform to `ExpressibleByNilLiteral`.
	convenience package init(nilLiteral: ()) {
		self.init(nil)
	}
}

extension LockBox: ExpressibleByBooleanLiteral where Wrapped: ExpressibleByBooleanLiteral {
	/// Creates a lock box initialized with a boolean literal value.
	///
	/// The wrapped type must conform to `ExpressibleByBooleanLiteral`.
	convenience package init(booleanLiteral value: Wrapped.BooleanLiteralType) {
		self.init(Wrapped(booleanLiteral: value))
	}
}

extension LockBox: @unchecked Sendable where Wrapped: Sendable {
	/// Returns or replaces the wrapped value.
	///
	/// Thread safe. This property is only available when `Wrapped` conforms to `Sendable`.
	package var value: Wrapped {
		get { isolationLock.withLock { _value } }
		set { isolationLock.withLock { _value = newValue } }
	}

	/// Returns or replaces the value at the given writable key path.
	///
	/// Thread safe. This property is only available when `Wrapped` conforms to `Sendable`.
	package subscript<T>(dynamicMember member: WritableKeyPath<Wrapped, T>) -> T {
		get { value[keyPath: member] }
		set { value[keyPath: member] = newValue }
	}

	/// Returns the value at the given key path.
	///
	/// Thread safe. This property is only available when `Wrapped` conforms to `Sendable`.
	package subscript<T>(dynamicMember member: KeyPath<Wrapped, T>) -> T {
		value[keyPath: member]
	}
}

extension LockBox: Equatable {
	/// Returns whether `lhs` and `rhs` refer to the same `LockBox` instance.
	///
	/// Equality is determined by reference identity (pointer comparison).
	package static func == (lhs: LockBox<Wrapped>, rhs: LockBox<Wrapped>) -> Bool {
		lhs === rhs
	}
}

extension LockBox: Hashable {
	/// Hashes the lock box's memory address into `hasher`.
	///
	/// Hashing is based on pointer identity, consistent with the `Equatable` conformance
	/// that uses `===` (reference equality).
	package func hash(into hasher: inout Hasher) {
		let address = Unmanaged.passUnretained(self).toOpaque()
		hasher.combine(address)
	}
}
