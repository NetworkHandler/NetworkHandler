import SwiftPizzaSnips

/// A lock-protected container for sharing values across concurrency boundaries with unchecked Sendable.
///
/// Like `LockBox` but always accepts any `Wrapped`. For internal use where the caller
/// guarantees safety beyond what the type system can enforce.
final package class UncheckedLockBox<Wrapped>: @unchecked Sendable {
	private let isolationLock = MutexLock()

	private var _value: Wrapped

	package subscript<T: Sendable>(dynamicMember member: KeyPath<Wrapped, T>) -> T {
		withLock {
			$0[keyPath: member]
		}
	}

	package init(_ value: Wrapped) {
		isolationLock.lock()
		defer { isolationLock.unlock() }
		self._value = value
	}

	/// Executes `block` with exclusive access to the wrapped value.
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
