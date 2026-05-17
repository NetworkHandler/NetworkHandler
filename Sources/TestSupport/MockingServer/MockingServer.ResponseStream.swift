import Foundation
import HTTPTypes
import NHMacros
import SwiftPizzaSnips

@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	public enum ResponseStream {
		public enum Chunk: Sendable {
			case header(OutboundResponseHeader)
			case data(Data)
			case string(String)
			case complete
		}
		public typealias Block = @Sendable (Chunk) -> Void

		/// Created on the server on each request. The server passes the base server's chunk block to it, then
		/// executes the request from the endpoint. The tracker, as implied, tracks and enforces that the response
		/// is sent first, followed by data, if any, followed by completion.
		final class LifecycleTracker: @unchecked Sendable {
			private let lock = MutexLock()

			private struct State: Hashable, Sendable {
				var hasResponded = false
				var hasSentData = false
				var hasCompleted = false
			}

			nonisolated(unsafe)
			private var state = State()

			private let streamBlock: Block

			init(_ streamBlock: @escaping Block) {
				self.streamBlock = streamBlock
			}

			deinit {
				lock.withLock {
					if state.hasResponded == false {
						_stream(.header(.init(responseCode: 500)))
					}
					if state.hasCompleted == false {
						_stream(.complete)
					}
				}
			}

			private func _stream(_ chunk: Chunk) {
				guard state.hasCompleted == false else { return }

				switch chunk {
				case .header:
					guard state.hasResponded == false else { return }
					state.hasResponded = true
				case .data, .string:
					if state.hasResponded == false {
						streamBlock(
							.header(
								.init(responseCode: 500, responseHeader: [#HTTPFieldName("Error"): "Did not send response before data"])))
					}
					state.hasSentData = true
				case .complete:
					if state.hasResponded == false {
						streamBlock(
							.header(
								.init(responseCode: 500, responseHeader: [#HTTPFieldName("Error"): "Did not send response before completion"])))
					}
					state.hasCompleted = true
				}

				streamBlock(chunk)
			}

			func stream(_ chunk: Chunk) {
				lock.withLock { _stream(chunk) }
			}

			func callAsFunction(_ chunk: Chunk) {
				stream(chunk)
			}
		}
	}
}
