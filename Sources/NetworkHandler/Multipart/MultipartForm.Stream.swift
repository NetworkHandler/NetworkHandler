import Foundation
import SwiftPizzaSnips

extension MultipartForm {
	/// An `InputStream`-compatible stream that yields the multipart form's data sequentially.
	///
	/// This class wraps a ``MultipartForm`` and provides an offset-tracking stream interface.
	/// Use ``open`` to begin reading and ``read(_:maxLength:)`` to consume data.
	final public class Stream: InputStream {
		/// The owning multipart form whose backing data this stream yields.
		public let form: MultipartForm

		nonisolated(unsafe)
		private weak var _delegate: StreamDelegate?
		/// The stream's delegate. Thread-safe.
		public override var delegate: StreamDelegate? {
			get { lock.withLock { _delegate } }
			set { lock.withLock { _delegate = newValue } }
		}

		nonisolated(unsafe)
		private var _currentOffset = 0
		/// The current byte offset (i.e. number of bytes consumed so far). Thread-safe.
		public var currentOffset: Int {
			lock.withLock { _currentOffset }
		}

		nonisolated(unsafe)
		private var _streamStatus: Stream.Status = .notOpen
		/// The stream's current status (e.g. ``Status/notOpen``, ``Status/open``, ``Status/reading``, ``Status/atEnd``, ``Status/error``).
		///
		/// ``Status/reading`` is only set briefly during ``read(_:maxLength:)`` and reverts to ``Status/open`` or
		/// ``Status/atEnd`` / ``Status/error`` before returning. Thread safe.
		public override var streamStatus: Stream.Status { lock.withLock { _streamStatus } }

		nonisolated(unsafe)
		private var _streamError: Error?
		/// The last error encountered, if any. Non-nil when ``streamStatus`` is ``Status/error``. Thread safe.
		public override var streamError: (any Error)? { lock.withLock { _streamError } }

		private let lock = MutexLock()

		private var _hasBytesAvailable: Bool { _currentOffset < form.count }
		/// Whether there is more data remaining to be read. Thread safe.
		public override var hasBytesAvailable: Bool { lock.withLock { _hasBytesAvailable } }

		package init(form: MultipartForm) {
			self.form = form
			super.init(data: Data())
		}

		/// Opens the stream, setting ``streamStatus`` to ``Status/open``. Thread safe.
		public override func open() {
			lock.withLock { _streamStatus = .open }
		}

		/// Closes the stream, setting ``streamStatus`` to ``Status/closed``. Thread safe.
		public override func close() {
			lock.withLock { _streamStatus = .closed }
		}

		/// Returns `false`.
		///
		/// This method not implemented.
		public override func getBuffer(
			_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
			length len: UnsafeMutablePointer<Int>
		) -> Bool { false }

		/// Reads up to `maxLength` bytes from the form's backing data starting at the current offset.
		///
		/// Copies decoded parts into `buffer` and advances the offset. Returns the number of bytes
		/// copied, or zero on error or when all data is exhausted. Updates ``streamStatus`` to
		/// ``Status/atEnd`` when the full stream is consumed, or ``Status/error`` on failure.
		///
		/// Locked for thread safety, but there should be no reason to execute on any more than a single thread.
		public override func read(
			_ buffer: UnsafeMutablePointer<UInt8>,
			maxLength len: Int
		) -> Int {
			lock.lock()
			defer { lock.unlock() }
			_streamStatus = .reading
			var statusOnExit: Stream.Status = .open
			defer { _streamStatus = statusOnExit }

			do {
				let chunk = try form.data(at: _currentOffset, count: len)
				chunk.copyBytes(to: buffer, count: chunk.count)
				_currentOffset += chunk.count
				if _hasBytesAvailable == false {
					statusOnExit = .atEnd
				}
				return chunk.count
			} catch {
				statusOnExit = .error
				self._streamError = error
				return 0
			}
		}

		/// No-op — this stream is not intended for run-loop scheduling.
		public override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}

		/// No-op — this stream is not intended for run-loop scheduling.
		public override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}

		#if canImport(FoundationNetworking)
		/// Returns `nil` — no properties are supported on this stream.
		public override func property(forKey key: Stream.PropertyKey) -> AnyObject? { nil }

		/// Returns `false` — no properties can be set on this stream.
		public override func setProperty(_ property: AnyObject?, forKey key: Stream.PropertyKey) -> Bool { false }
		#else
		/// Returns `nil` — no properties are supported on this stream.
		public override func property(forKey key: Stream.PropertyKey) -> Any? { nil }

		/// Returns `false` — no properties can be set on this stream.
		public override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool { false }
		#endif
	}
}
