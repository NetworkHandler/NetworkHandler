@preconcurrency import Embassy
import Foundation
import HTTPTypes
@preconcurrency import Logging
import NetworkHandler
import NHMacros
import SwiftPizzaSnips

/// Running a mocking server completely occupies an entire thread on the host machine. That means it's limited
/// to threadcount - 1 instances at most on a machine (at least one thread is needed for async await coop in addition
/// to each instance). The `MockingServer` type prevents more than `ProcessInfo.processInfo.processorCount - 1`
/// instances at a time, through its async init. While this is automatic, be aware that this could cause bottlenecks.
@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
public final class MockingServer: Sendable {
	private let runLoop: SelectorEventLoop
	private let runLoopTask: Task<Void, Never>

	private static let instanceTracker = MockingServerInstanceTracker()

	nonisolated(unsafe)
	public private(set) var server: HTTPServer!

	public let port: UInt16

	public typealias Method = HTTPTypes.HTTPRequest.Method

	nonisolated(unsafe)
	private var endpoints: [EndpointPath: Endpoint] = [:]
	private let endpointsLock = MutexLock()

	private let logger: Logging.Logger
	private let name: String

	public init(serverName: String, port: UInt16? = nil, logger: Logging.Logger? = nil) async throws {
		self.name = serverName
		let port = port ?? UInt16.random(in: 10_000..<(.max))
		self.port = port
		let logger = logger ?? Logger(label: "\(serverName):(port \(port))")
		logger.debug("Port \(port)")
		self.logger = logger
		await Self.instanceTracker.registerAdditionalInstance()
		let selector = try KqueueSelector()
		let runLoop = try SelectorEventLoop(selector: selector)
		self.runLoop = runLoop
		self.runLoopTask = Task.detached { [runLoop] in
			logger.info("Server starting runloop")
			await withTaskCancellationHandler(
				operation: {
					runLoop.runForever()
				},
				onCancel: {
					runLoop.stop()
				})
			logger.info("runloop finished")
		}

		self.server = DefaultHTTPServer(eventLoop: runLoop, port: Int(port)) {
			// this is the header of a closure that's just stupidly long and therefore broken to multiple lines
			[weak runLoop, weak self] (
				env: [String: Any],
				startResponse: @escaping ((String, [(String, String)]) -> Void),
				sendBody: @escaping ((Data) -> Void)
			) in

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
		logger.info("Server started")
	}

	deinit {
		server.stop()
		runLoopTask.cancel()
		logger.info("Server with port \(port) shutdown")
		Task { await Self.instanceTracker.deregisterInstance() }
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
			let requestMethod = Method(rawValue: reqMethodStr)
		else {
			responseStream(.header(.serverError(errorDescription: "Assumed env not found")))
			responseStream(.complete)
			return
		}
		let loggingPath = String(path.rawValue.joined(by: "/"))
		logger.info("Received request", metadata: ["Path": "\(loggingPath)", "Method": "\(requestMethod.rawValue)"])
		guard
			let endpoint = self.endpointsLock.withLock({ self.endpoints[.init(path: path, method: requestMethod)] })
		else {
			responseStream(.header(.init(responseCode: 404)))
			responseStream(.complete)
			logger.info("Path/method not handled", metadata: ["Path": "\(loggingPath)", "Method": "\(requestMethod.rawValue)"])
			return
		}

		let headers = env.reduce(into: [String: String]()) {
			guard $1.key.starts(with: "HTTP_") else { return }
			let name = $1.key.dropFirst(5)
			$0[String(name)] = $1.value as? String
		}

		guard let input = env["swsgi.input"] as? SWSGIInput else {
			responseStream(.header(.serverError(errorDescription: "Base input stream not found")))
			responseStream(.complete)
			return
		}

		func finishRequest(incomingPayload: Data?) {
			let incomingRequest = IncomingRequest(
				path: path,
				method: requestMethod,
				headers: .init(headers),
				payload: incomingPayload)

			logger.info("Responding")

			Task {
				logger.info("Test log")
			}

			Task { [logger] in
				defer {
					logger.info(
						"Finished processing request",
						metadata: ["Path": "\(loggingPath)", "Method": "\(requestMethod.rawValue)"])
				}
				logger.info("Responding Task started")
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

		let hasBody = headers["CONTENT_LENGTH"] != nil || headers["TRANSFER_ENCODING"] == "chunked"
		if hasBody {
			logger.info("Processing request data", metadata: ["Path": "\(loggingPath)", "Method": "\(requestMethod.rawValue)"])
			let expectedLength = headers["CONTENT_LENGTH"]
			var payload = Data()
			input { [logger] in
				payload.append($0)
				logger.info(
					"Got bytes",
					metadata: ["ExpectedTotal": "\(expectedLength, default: "unknown")", "TotalReceived": "\(payload.count)"])
				guard $0.isEmpty else { return }
				logger.info(
					"Finished request upload",
					metadata: ["TotalReceived": "\(payload.count)"])

				finishRequest(incomingPayload: payload)
			}
		} else {
			logger.info("No request data", metadata: ["Path": "\(loggingPath)", "Method": "\(requestMethod.rawValue)"])
			finishRequest(incomingPayload: nil)
		}
	}

	public func addMock(
		for path: Path,
		method: Method = .get,
		responseData: Data?,
		responseCode: Int = 200,
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
	/// solution to this is to not run thousands of simultaneous servers. Edit: Turns out you cannot run more servers
	/// than you have threads. See ``MockingServer``
	/// - Returns: a MockingServer listening to localhost:[randomPort]
	public static func createServer(name: String?) async throws -> MockingServer {
		var creationError: Embassy.OSError?

		repeat {
			do {
				return try await MockingServer(serverName: name ?? "Mocking Server")
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

@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	private actor MockingServerInstanceTracker {
		let maxCount: Int

		private(set) var instanceCounter = 0

		private var continuations: [CheckedContinuation<Void, Never>] = []

		init() {
			self.maxCount = ProcessInfo.processInfo.processorCount - 1
		}

		func registerAdditionalInstance() async {
			let _: Void = await withCheckedContinuation { continuation in
				if instanceCounter >= maxCount {
					continuations.append(continuation)
				} else {
					continuation.resume()
				}
			}
			instanceCounter += 1
		}

		func deregisterInstance() {
			instanceCounter -= 1
			continuations.popFirst()?.resume()
		}

	}
}
