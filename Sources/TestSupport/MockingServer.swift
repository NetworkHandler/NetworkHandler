@preconcurrency import Embassy
import Foundation
import HTTPTypes
import NetworkHandler
import NHMacros
import SwiftPizzaSnips

@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
public class MockingServer {
	private let runLoop: SelectorEventLoop
	private let runLoopTask: Task<Void, Never>
	public var server: HTTPServer!

	public let port: UInt16

	public typealias Method = HTTPTypes.HTTPRequest.Method
	public struct Path:
		RawRepresentable,
		Sendable,
		Hashable,
		ExpressibleByArrayLiteral,
		ExpressibleByStringLiteral,
		ExpressibleByStringInterpolation {

		public var rawValue: [String]

		public init(rawValue: [String]) {
			self.rawValue = rawValue
		}

		public init(arrayLiteral elements: String...) {
			self.init(rawValue: elements)
		}

		public init(stringLiteral value: String) {
			let path = value.split(separator: "/").map(String.init)
			self.init(rawValue: path)
		}
	}

	public struct IncomingRequest: Sendable {
		public let path: Path
		public let method: Method

		public let headers: HTTPFields

		public let payload: Data?

		public init(path: Path, method: Method, headers: HTTPFields, payload: Data?) {
			self.path = path
			self.method = method
			self.headers = headers
			self.payload = payload
		}
	}

	public struct OutboundResponseHeader: Sendable {
		public let responseCode: Int
		public let responseHeader: HTTPFields

		public init(responseCode: Int, responseHeader: HTTPFields? = nil) {
			self.responseCode = responseCode
			self.responseHeader = responseHeader ?? .init()
		}
	}

	public typealias Endpoint = @Sendable (
		_ request: IncomingRequest,
		_ stream: ResponseStream.Block
	) async throws(HTTPError) -> Void

	public struct HTTPError: Error {
		public let code: Int
		public let errorDescription: String?

		public init(code: Int = 500, errorDescription: String? = nil) {
			self.code = code
			self.errorDescription = errorDescription
		}

		public static func capture<T>(_ throwing: () async throws -> T) async throws(HTTPError) -> T {
			do {
				return try await throwing()
			} catch {
				return try capture { throw error }
			}
		}

		public static func capture<T>(_ throwing: () throws -> T) throws(HTTPError) -> T {
			do {
				return try throwing()
			} catch {
				if error.isTimeout() {
					throw HTTPError(errorDescription: "Server timeout")
				}
				if error.isCancellation() {
					throw HTTPError(errorDescription: "Server cancellation")
				}

				throw HTTPError(errorDescription: "Unexpected error: \(error)")
			}
		}
	}

	private struct EndpointPath: Hashable {
		let path: Path
		let method: Method
	}

	private var endpoints: [EndpointPath: Endpoint] = [:]
	private let endpointsLock = MutexLock()

	public init(port: UInt16? = nil) throws {
		let port = port ?? UInt16.random(in: 10_000..<(.max))
		self.port = port
		print("Port \(port)")
		let selector = try KqueueSelector()
		let runLoop = try SelectorEventLoop(selector: selector)
		self.runLoop = runLoop
		self.runLoopTask = Task.detached { [runLoop] in
			runLoop.runForever()
		}

		self.server = DefaultHTTPServer(eventLoop: runLoop, port: Int(port)) { [weak runLoop, weak self] (env: [String: Any], startResponse: @escaping ((String, [(String, String)]) -> Void), sendBody: @escaping ((Data) -> Void)) in
			guard let runLoop, let self else {
				startResponse("500 Internal Server Error", [("Error", "Invalid server state")])
				return sendBody(Data())
			}

			let startResponseWrapper = Sendify(startResponse)
			let sendBodyWrapper = Sendify(sendBody)

			let tracker = ResponseStream.LifecycleTracker { chunk in
				switch chunk {
				case .header(let header):
					let responseCodePhrase = Self.reasonPhrases[header.responseCode] ?? "OK"
					let headersArray = header.responseHeader.map { ($0.name.rawName, $0.value) }

					runLoop.call {
						startResponseWrapper.value("\(header.responseCode) \(responseCodePhrase)", headersArray)
					}
				case .string(let string):
					let data = Data(string.utf8)
					guard data.isOccupied else { return }
					runLoop.call { sendBodyWrapper.value(data) }
				case .data(let data):
					guard data.isOccupied else { return }
					runLoop.call { sendBodyWrapper.value(data) }
				case .complete:
					runLoop.call { sendBodyWrapper.value(Data()) }
				}
			}

			self.runServerLogic(
				env: env,
				runLoop: runLoop,
				responseStream: tracker)
		}

		try server.start()
	}

	deinit {
		server.stop()
		runLoopTask.cancel()
	}

	private func runServerLogic(
		env: [String: Any],
		runLoop: EventLoop,
		responseStream: ResponseStream.LifecycleTracker
	) {
		guard
			let pathStr = env["PATH_INFO"] as? String,
			case let path: Path = "\(pathStr)",
			let reqMethodStr = env["REQUEST_METHOD"] as? String,
			let requestMethod = Method(rawValue: reqMethodStr),
			let endpoint = self.endpointsLock.withLock({ self.endpoints[.init(path: path, method: requestMethod)] })
		else {
			responseStream(.header(.init(responseCode: 500)))
			responseStream(.complete)
			return
		}

		let headers = env.reduce(into: [String: String]()) {
			guard $1.key.starts(with: "HTTP_") else { return }
			let name = $1.key.dropFirst(5)
			$0[String(name)] = $1.value as? String
		}

		var incomingPayload: Data?
		if let input = env["swsgi.input"] as? SWSGIInput {
			input {
				incomingPayload = $0
			}
		}

		let incomingRequest = IncomingRequest(
			path: path,
			method: requestMethod,
			headers: .init(headers),
			payload: incomingPayload)

		Task {
			do throws(HTTPError) {
				try await endpoint(incomingRequest) { chunk in
					responseStream(chunk)
				}
			} catch {
				let errorInfo = error.errorDescription ?? "No error description"
				responseStream(
					.header(
						.init(responseCode: error.code, responseHeader: [#HTTPFieldName("Error"): errorInfo])))
				responseStream(.complete)
			}
		}
	}

	public func addMock(
		for path: Path,
		method: Method,
		responseData: Data?,
		responseCode: Int,
		delay: TimeInterval = 0
	) {
		addMock(for: path, method: method) { _, stream throws(HTTPError) in
			let headers: HTTPFields
			if let responseData {
				headers = [.contentLength: "\(responseData.count)"]
			} else {
				headers = .init()
			}
			let header = OutboundResponseHeader(
				responseCode: responseCode,
				responseHeader: headers)

			if delay > 0 {
				try await HTTPError.capture {
					try await Task.sleep(for: .seconds(delay))
				}
			}
			stream(.header(header))

			if let responseData {
				stream(.data(responseData))
			}

			stream(.complete)
		}
	}

	public func addMock(
		for path: Path,
		method: Method,
		smartBlock: @escaping Endpoint
	) {
		let key = EndpointPath(path: path, method: method)
		endpointsLock.withLock {
			endpoints[key] = smartBlock
		}
	}

	/// Creates a server on a random port. You can get the port from the returned server object.
	///
	/// This is disctinct from the default initializer in that it retries any time it creates a server on a port
	/// that's already in use. Viable ports are `10000..<(UInt16.max)`. Ultimately, this means that if you have
	/// thousands of simultaneous servers, you could end up in a situation where the available space for remaining
	/// servers diminishes, eventually potentially causing an infinite loop when the entire space is occupied. The
	/// solution to this is to not run thousands of simultaneous servers.
	/// - Returns: a MockingServer listening to localhost:[randomPort]
	public static func createServer() throws -> MockingServer {
		var creationError: Embassy.OSError?

		repeat {
			do {
				return try MockingServer()
			} catch let error as Embassy.OSError {
				guard case .ioError(let number, _) = error else {
					throw error
				}
				guard
					number == 48 // port not available (address in use)
				else { throw error }
				creationError = error
			}
		} while creationError != nil
		throw creationError ?? .ioError(number: -1, message: "Unknown error")
	}

	private static let reasonPhrases: [Int: String] = [
		200: "OK",
		201: "Created",
		202: "Accepted",
		204: "No Content",
		301: "Moved Permanently",
		302: "Found",
		304: "Not Modified",
		400: "Bad Request",
		401: "Unauthorized",
		403: "Forbidden",
		404: "Not Found",
		405: "Method Not Allowed",
		408: "Request Timeout",
		409: "Conflict",
		410: "Gone",
		413: "Payload Too Large",
		414: "URI Too Long",
		422: "Unprocessable Content",
		429: "Too Many Requests",
		500: "Internal Server Error",
		501: "Not Implemented",
		502: "Bad Gateway",
		503: "Service Unavailable",
		504: "Gateway Timeout",
	]

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

extension SelectorEventLoop: @unchecked @retroactive Sendable {}
