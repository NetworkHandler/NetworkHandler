import Foundation
@preconcurrency import Embassy
import HTTPTypes
import NetworkHandler
import NHMacros
import SwiftPizzaSnips

public class MockingServer {
	private let runLoop: SelectorEventLoop
	private let runLoopTask: Task<Void, Never>
	public var server: HTTPServer!

	public let port: Int

	public typealias Method = HTTPTypes.HTTPRequest.Method
	public typealias Path = [String]
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

		init(responseCode: Int, responseHeader: HTTPFields? = nil) {
			self.responseCode = responseCode
			self.responseHeader = responseHeader ?? .init()
		}
	}

	public enum ResponseStreamChunk: Sendable {
		case header(OutboundResponseHeader)
		case data(Data)
		case complete
	}
	public typealias ResponseStream = @Sendable (ResponseStreamChunk) -> Void

	public typealias Endpoint = @Sendable (_ request: IncomingRequest, _ stream: ResponseStream) async throws -> Void

	private struct EndpointPath: Hashable {
		let path: Path
		let method: Method
	}

	private var endpoints: [EndpointPath: Endpoint] = [:]
	private let endpointsLock = MutexLock()

	public init(port: Int? = nil) throws {
		let port = port ?? Int(UInt16.random(in: 10_000..<(.max)))
		self.port = port
		print("Port \(port)")
		let selector = try KqueueSelector()
		let runLoop = try SelectorEventLoop(selector: selector)
		self.runLoop = runLoop
		self.runLoopTask = Task.detached { [runLoop] in
			runLoop.runForever()
		}

		self.server = DefaultHTTPServer(eventLoop: runLoop, port: port) { [weak runLoop, weak self] (env: [String: Any], startResponse: @escaping ((String, [(String, String)]) -> Void), sendBody: @escaping ((Data) -> Void)) in
			guard let runLoop, let self else {
				startResponse("500 Internal Server Error", [])
				return sendBody(Data())
			}

			let startResponseWrapper = Sendify(startResponse)
			let sendBodyWrapper = Sendify(sendBody)

			self.runServerLogic(
				env: env,
				runLoop: runLoop,
				responseStream: { chunk in
					switch chunk {
					case .header(let header):
						let responseCodePhrase = Self.reasonPhrases[header.responseCode] ?? "OK"
						let headersArray = header.responseHeader.map { ($0.name.rawName, $0.value) }

						runLoop.call {
							startResponseWrapper.value("\(header.responseCode) \(responseCodePhrase)", headersArray)
						}
					case .data(let data):
						guard data.isOccupied else { return }
						runLoop.call { sendBodyWrapper.value(data) }
					case .complete:
						runLoop.call { sendBodyWrapper.value(Data()) }
					}

				})
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
		responseStream: @escaping ResponseStream
	) {
		guard
			let pathStr = env["PATH_INFO"] as? String,
			case let path = pathStr.split(separator: "/").map(String.init),
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
			let tracker = Sendify((header: false, body: false, finish: false))
			do {
				try await endpoint(incomingRequest) { chunk in
					switch chunk {
					case .header:
						tracker.header = true
					case .data:
						tracker.body = true
					case .complete:
						tracker.finish = true
					}
					responseStream(chunk)
				}
			} catch {
				guard tracker.finish == false else { return }
				if tracker.header == false {
					responseStream(
						.header(
							OutboundResponseHeader(
								responseCode: 500,
								responseHeader: [#HTTPFieldName("Error"): "\(error)"])))
					tracker.header = true
				}
				responseStream(.complete)
				tracker.finish = true
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
		addMock(for: path, method: method) { _, stream in
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
				try await Task.sleep(for: .seconds(delay))
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
	static func createServer() throws -> MockingServer {
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
}

extension SelectorEventLoop: @unchecked @retroactive Sendable {}
