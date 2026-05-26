import Foundation
import SwiftPizzaSnips

extension MultipartForm {
	public var stream: Stream {
		Stream(form: self)
	}

	final public class Stream: InputStream {
		public let form: MultipartForm

		nonisolated(unsafe)
		private weak var _delegate: StreamDelegate?
		public override var delegate: StreamDelegate? {
			get { lock.withLock { _delegate } }
			set { lock.withLock { _delegate = newValue } }
		}

		nonisolated(unsafe)
		private var _currentOffset = 0
		public var currentOffset: Int {
			lock.withLock { _currentOffset }
		}

		nonisolated(unsafe)
		private var _streamStatus: Stream.Status = .notOpen
		public override var streamStatus: Stream.Status { lock.withLock { _streamStatus } }

		nonisolated(unsafe)
		private var _streamError: Error?
		public override var streamError: (any Error)? { lock.withLock { _streamError } }

		private let lock = MutexLock()

		private var _hasBytesAvailable: Bool {
			_currentOffset < form.count
		}
		public override var hasBytesAvailable: Bool {
			lock.withLock { _hasBytesAvailable }
		}

		init(form: MultipartForm) {
			self.form = form

			super.init(data: Data())
		}

		public override func open() {
			lock.withLock { _streamStatus = .open }
		}

		public override func close() {
			lock.withLock { _streamStatus = .closed }
		}

		public override func getBuffer(
			_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
			length len: UnsafeMutablePointer<Int>
		) -> Bool { false }

		public override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
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

		public override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}
		public override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}
		#if canImport(FoundationNetworking)
		public override func property(forKey key: Stream.PropertyKey) -> AnyObject? { nil }
		public override func setProperty(_ property: AnyObject?, forKey key: Stream.PropertyKey) -> Bool { false }
		#else
		public override func property(forKey key: Stream.PropertyKey) -> Any? { nil }
		public override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool { false }
		#endif
	}
}
