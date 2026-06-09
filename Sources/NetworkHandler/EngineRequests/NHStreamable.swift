import Foundation
import SwiftPizzaSnips

/// A protocol for types that can provide an `InputStream`.
///
/// Conforming types represent a source of streamable data that can be consumed
/// by HTTP request bodies or other streaming APIs. The `isRetryable` property
/// indicates whether the stream can be safely recreated for retries.
public protocol NHStreamable: Sendable, Hashable {
	/// Whether the stream can be safely recreated for retry attempts.
	var isRetryable: Bool { get }

	/// the number of total bytes in the stream, if known ahead of time
	var streamCount: Int? { get }

	/// Creates and returns a new `InputStream` for the data source.
	func createStream() throws -> InputStream
}

/// Provides `NHStreamable` conformance for `URL`.
extension URL: NHStreamable {
	public var isRetryable: Bool { true }

	public var streamCount: Int? { nil }

	public func createStream() throws -> InputStream {
		try InputStream(url: self).unwrap("Invalid URL for InputStream")
	}
}

/// Provides `NHStreamable` conformance for `Data`.
///
/// Wraps the data in an `InputStream`. Always retryable since the data
/// is already fully in memory.
extension Data: NHStreamable {
	public var isRetryable: Bool { true }

	public var streamCount: Int? { nil }

	public func createStream() throws -> InputStream {
		InputStream(data: self)
	}
}

/// Provides `NHStreamable` conformance for `String`.
///
/// Encodes as UTF-8 and wraps in an `InputStream`. Always retryable.
extension String: NHStreamable {
	public var isRetryable: Bool { true }

	public var streamCount: Int? { count }

	public func createStream() throws -> InputStream {
		InputStream(data: Data(self.utf8))
	}
}

/// Provides `NHStreamable` conformance for `MultipartForm`.
///
/// Creates a `MultipartForm.Stream` which reads parts lazily. Always retryable.
extension MultipartForm: NHStreamable {
	public var isRetryable: Bool { true }

	public var streamCount: Int? { count }

	public func createStream() throws -> InputStream {
		MultipartForm.Stream(form: self)
	}
}

/// A closure-backed `NHStreamable` that defers stream creation. Useful for arbitrary stream
/// creation without having to conform your custom type to `NHStreamable`
///
/// Create with a synchronous, `Sendable` closure that produces an
/// `InputStream`. Call `createStream()` to invoke the closure and
/// receive a fresh stream each time — suitable for retryable sources.
///
/// **Note:** Equality and hashing are by identity (`===` / pointer address).
/// Closures can't be value-compared, so two `NHStreamCreator` instances
/// are never equal even if they wrap identical closures.
public final class NHStreamCreator: Sendable, Hashable, NHStreamable {
	private let block: @Sendable () throws -> InputStream

	public let isRetryable: Bool

	public let streamCount: Int?

	/// Creates a new NHStreamCreator
	/// - Parameters:
	///   - isRetryable: whether the stream can be restarted and retried
	///   - streamCount: the number of total bytes in the stream, if known ahead of time
	///   - block: a block that creates and returns a new InputStream that outputs the stream data
	public init(isRetryable: Bool, streamCount: Int? = nil, block: @Sendable @escaping () throws -> InputStream) {
		self.isRetryable = isRetryable
		self.streamCount = streamCount
		self.block = block
	}

	public func createStream() throws -> InputStream {
		try block()
	}

	public static func == (lhs: NHStreamCreator, rhs: NHStreamCreator) -> Bool {
		lhs === rhs
	}

	public func hash(into hasher: inout Hasher) {
		let address = Unmanaged.passUnretained(self).toOpaque()
		hasher.combine(address)
	}
}
