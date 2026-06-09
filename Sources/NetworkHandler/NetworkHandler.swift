import Foundation
import HTTPTypes
import Logging
import SwiftPizzaSnips

/// The bread and butter of this package!
///
/// `NetworkHandler` is the central location housing the high level logic for how to handle networking.
///
/// All of the transfer methods are foundationally built off of `streamMahDatas()`, implementing the specific behavior
/// required for each individual method.
public class NetworkHandler<Engine: NetworkEngine>: @unchecked Sendable, Withable {
	// MARK: - Properties
	/// The logger instance used for this `NetworkHandler` instance.
	public let logger: Logger

	/// An instance of Network Cache to speed up subsequent requests. Usage is
	/// optional, but automatic when making requests using the `usingCache` flag.
	let cache: NetworkCachable

	/// Used to label this instance of `NetworkHandler` for things like logging or debugging. Also useful
	/// if you desire anthropomorphizing `NetworkHandler` instances as they are created ephemerally in
	/// memory only to be ruthlessly destroyed once their usefulness has expired. I call this instance "Jimi".
	public let name: String

	/// Underlying engine running network transactions
	public let engine: Engine

	// MARK: - Lifecycle
	/// Initialize a new NetworkHandler instance.
	public init(
		name: String,
		engine: Engine,
		logger: Logger = Logger(label: "Network Handler"),
		cache: NetworkCachable? = nil
	) {
		self.name = name
		self.cache = cache ?? DefaultNetworkCache(name: "\(name)-Cache", logger: Logger(label: "Network Handler Cache"))
		self.logger = logger

		self.engine = engine

		NetworkError.registerTimeoutErrorHandling(Engine.isTimeoutError, forEngine: "\(Engine.self)")
		NetworkError.registerCancellationErrorHandling(Engine.isTimeoutError, forEngine: "\(Engine.self)")
	}

	deinit {
		engine.shutdown()
	}

	/// Clears the contents of the cache either in memory, on disk, or both.
	///
	/// - Parameters:
	///   - memory: A Boolean value indicating whether to clear the in-memory cache. Defaults to `true`.
	///   - disk: A Boolean value indicating whether to clear the disk cache. Defaults to `true`.
	///
	/// Use this method to completely wipe the cache, ensuring that no stale or outdated data remains.
	/// Logs these operations for visibility.
	public func resetCache(memory: Bool = true, disk: Bool = true) {
		if let cache = cache as? DefaultNetworkCache {
			cache.reset(memory: memory, disk: disk)
		} else {
			cache.reset()
		}
	}

	// MARK: - Network Handling
	/// Represents the continuation decision a poll loop must make after evaluating the
	/// result of a request via the `until` closure.
	///
	/// Return `.finish` to end the polling loop, or `.continue` to repeat the request
	/// after the specified `TimeInterval`.
	public enum PollContinuation<T: Sendable>: Sendable {
		/// End the polling loop using the provided poll result.
		case finish(PollResult<T>)
		/// Continue polling. The associated `CompleteNetworkRequest` is the next request to
		/// execute, and the `TimeInterval` is the delay before sending it.
		case `continue`(CompleteNetworkRequest, TimeInterval)
	}

	/// The result type passed to the `until` closure during polling. It yields either the
	/// response header and decoded result, or an error encountered during the request.
	public typealias PollResult<T: Sendable> = Result<(EngineResponseHeader, T), Error>
	/// Immediately sends a request, then repeatedly polls by evaluating the result via the
	/// `until` closure, which decides whether to `.finish` the loop or `.continue` polling.
	///
	/// Use cases:
	/// - Long-running queries (e.g. WebSocket fallback, long-polling APIs)
	/// - Async operations that return a status and need repeated checks
	/// - Backoff strategies with configurable delays
	///
	/// - Parameters:
	///     - `request`: The initial `CompleteNetworkRequest` to send.
	///     - `delegate`: Optional delegate for transfer lifecycle callbacks.
	///     - cacheOption: Indicates whether to use cache and with what override key.
	///       **Default**: `.dontUseCache`
	///     - `decoder`: The `NHDecoder` used for decoding response data.
	///       **Default**: `NetworkRequest.defaultDecoder`
	///     - `requestLogger`: Optional logger for request-level diagnostics.
	///     - `cancellationToken`: Optional token for cancelling the request.
	///     - `until`: A closure evaluated after each poll result. Must return a
	///       `PollContinuation` deciding `.finish` or `.continue` with a new request
	///       and delay.
	/// - Returns: The response header and decoded result from the final successful poll.
	///
	/// - Note: This API is still in beta and the interface is liable to change.
	@NHActor
	@discardableResult
	public func poll<T: Decodable>(
		request: CompleteNetworkRequest,
		delegate: NetworkHandlerTaskDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		decoder: NHDecoder = NetworkRequest.defaultDecoder,
		requestLogger: Logger? = nil,
		cancellationToken: NetworkCancellationToken? = nil,
		until: @escaping @NHActor (CompleteNetworkRequest, PollResult<T>) async throws(NetworkError) -> PollContinuation<T>
	) async throws -> (responseHeader: EngineResponseHeader, result: T) {
		func doPoll(request: CompleteNetworkRequest) async -> PollResult<T> {
			let polledResult: PollResult<T>
			do throws(NetworkError) {
				let (header, data) = try await transferMahDatas(
					for: request,
					delegate: delegate,
					usingCache: cacheOption,
					requestLogger: requestLogger,
					cancellationToken: cancellationToken)
				guard let data else { throw .noData }
				let decoded: T = try decodeData(data: data, using: decoder)
				polledResult = .success((header, decoded))
			} catch {
				polledResult = .failure(error)
			}
			return polledResult
		}

		let firstResult = await doPoll(request: request)

		var instruction = try await until(request, firstResult)

		while case .continue(let networkRequest, let timeInterval) = instruction {
			if #available(macOS 13.0, iOS 16.0, tvOS 16.0, *) {
				try await Task.sleep(for: .seconds(timeInterval))
			} else {
				try await Task.sleep(nanoseconds: UInt64(timeInterval * 1_000_000_000))
			}
			let thisResult = await doPoll(request: networkRequest)
			instruction = try await until(networkRequest, thisResult)
		}

		guard case .finish(let result) = instruction else {
			throw NetworkError.unspecifiedError(reason: "Invalid State")
		}

		let finalResult = try result.get()

		return finalResult
	}

	/// Automatically decodes the data retrieved from the request to the generic `DecodableType`.
	///
	/// - Parameters:
	///		- `request`: The `NetworkRequest` to send.
	///		- `delegate`: Provides transfer lifecycle information.
	///		- cacheOption: Indicates whether to use cache and with what override key.
	///		  **Default**: `.dontUseCache`
	///		- `decoder`: The `NHDecoder` used for decoding the response.
	///		  **Default**: `NetworkRequest.defaultDecoder`
	///		- `requestLogger`: Logger to use for this request.
	///		- `cancellationToken`: Optional token for cancelling the request before it completes.
	///		- `onError`: Error and retry handling. **Default**: `.throw`
	/// - Returns: The response header from the server and the decoded response body.
	@NHActor
	@discardableResult
	public func downloadMahCodableDatas<DecodableType: Decodable>(
		for request: NetworkRequest,
		delegate: NetworkHandlerTaskDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		decoder: NHDecoder = NetworkRequest.defaultDecoder,
		requestLogger: Logger? = nil,
		cancellationToken: NetworkCancellationToken? = nil,
		onError: @escaping RetryOptionBlock = { _, _, _ in .throw }
	) async throws(NetworkError) -> (responseHeader: EngineResponseHeader, decoded: DecodableType) {
		let (header, rawData) = try await downloadMahDatas(
			for: request,
			delegate: delegate,
			usingCache: cacheOption,
			requestLogger: requestLogger,
			cancellationToken: cancellationToken,
			onError: onError)

		guard let rawData else { throw .noData }
		return try (header, decodeData(data: rawData, using: decoder))
	}

	/// Send a large blob to a server. If `request.payload` is non-nil, it will be ignored in favor of
	/// the `payload` parameter passed in.
	///
	/// - Parameters:
	///		- `request`: A `NetworkRequest` describing the upload.
	///		- `payload`: The file/data/stream you're uploading.
	///		- `delegate`: Provides transfer lifecycle information.
	///		- `requestLogger`: Logger to use for this request.
	///		- `cancellationToken`: Optional token for cancelling the request before it completes.
	///		- `onError`: Error and retry handling. **Default**: `.throw`
	/// - Returns: The response header and the optional body data.
	@NHActor
	@discardableResult
	public func uploadMahDatas(
		for request: NetworkRequest,
		payload: CompleteNetworkRequest.UploadFile,
		delegate: NetworkHandlerTaskDelegate? = nil,
		requestLogger: Logger? = nil,
		cancellationToken: NetworkCancellationToken? = nil,
		onError: @escaping RetryOptionBlock = { _, _, _ in .throw }
	) async throws -> (responseHeader: EngineResponseHeader, data: Data?) {
		try await transferMahDatas(
			for: .upload(request.with { $0.payload = nil }, payload: payload),
			delegate: delegate,
			usingCache: .dontUseCache,
			requestLogger: requestLogger,
			cancellationToken: cancellationToken,
			onError: onError)
	}

	/// Downloads remote data and saves it to a local file URL.
	///
	/// - Parameters:
	///		- `request`: The `NetworkRequest` describing the download.
	///		- `outFileURL`: The file URL to save the final data into (also used as the
	///		  temporary file if no explicit temporary URL is provided).
	///		- `tempoaryFileURL`: The file URL to save data into as it's accumulated before
	///		  the transfer completes.
	///		- `delegate`: Provides transfer lifecycle information.
	///		- cacheOption: Indicates whether to use cache and with what override key.
	///		  **Default**: `.dontUseCache`
	///		- `requestLogger`: Logger to use for this request.
	///		- `cancellationToken`: Optional token for cancelling the request before it completes.
	///		- `onError`: Error and retry handling. **Default**: `.throw`
	/// - Returns: The response header from the server.
	@NHActor
	@discardableResult
	public func downloadMahFile(
		for request: NetworkRequest,
		savingToLocalFileURL outFileURL: URL,
		withTemporaryFile tempoaryFileURL: URL? = nil,
		delegate: NetworkHandlerTaskDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		requestLogger: Logger? = nil,
		cancellationToken: NetworkCancellationToken? = nil,
		onError: @escaping RetryOptionBlock = { _, _, _ in .throw }
	) async throws(NetworkError) -> EngineResponseHeader {
		let tempFileURL = tempoaryFileURL ?? outFileURL

		guard
			tempFileURL.isFileURL,
			outFileURL.isFileURL
		else {
			throw NetworkError.unspecifiedError(reason: "Both the temporary url and output url must be local file URLs.")
		}

		if let cacheKey = cacheOption.cacheKey(url: request.url, method: request.method) {
			if let cachedData = cache.cachedItem(for: cacheKey) {
				try NetworkError.captureAndConvert {
					try cachedData.data.write(to: outFileURL)
				}
				return cachedData.response
			}
		}

		let (header, _) = try await retryHandler(
			originalRequest: .standard(request),
			transferTask: { transferRequest, _ in
				let (streamHeader, stream) = try await streamMahDatas(
					for: transferRequest,
					delegate: delegate,
					requestLogger: requestLogger,
					cancellationToken: cancellationToken)
				try? FileManager.default.removeItem(at: tempFileURL)

				try Data().write(to: tempFileURL)
				let fh = try FileHandle(forWritingTo: tempFileURL)

				for try await chunk in stream {
					try fh.write(contentsOf: chunk)
				}
				return (streamHeader, Data())
			},
			errorHandler: onError)
		if outFileURL.checkResourceIsAccessible() {
			var oldOut = outFileURL
			while oldOut.checkResourceIsAccessible() {
				let filename = oldOut.deletingPathExtension().lastPathComponent
				let newFilename = "\(filename).old"
				let ext = oldOut.pathExtension
				oldOut = oldOut
					.deletingLastPathComponent()
					.appending(component: newFilename)
					.appendingPathExtension(ext)
			}
			try NetworkError.captureAndConvert { try FileManager.default.moveItem(at: outFileURL, to: oldOut) }
		}
		try NetworkError.captureAndConvert { try FileManager.default.moveItem(at: tempFileURL, to: outFileURL) }

		if
			let cacheKey = cacheOption.cacheKey(url: request.url, method: request.method),
			let responseSize = header.expectedContentLength,
			responseSize < 1024 * 1024 * 100 {

			Task {
				let newlyCachedData = try Data(contentsOf: outFileURL)
				self.cache.setCachedItem(NetworkCacheStore(response: header, data: newlyCachedData), for: cacheKey)
			}
		}

		return header
	}

	/// Downloads data from a server, returning the raw response body. Also used to send smaller
	/// chunks of data, like REST requests.
	///
	/// - Parameters:
	///		- `request`: The `NetworkRequest` to send.
	///		- `delegate`: Provides transfer lifecycle information.
	///		- cacheOption: Indicates whether to use cache and with what override key.
	///		  **Default**: `.dontUseCache`
	///		- `requestLogger`: Logger to use for this request.
	///		- `cancellationToken`: Optional token for cancelling the request before it completes.
	///		- `onError`: Error and retry handling. **Default**: `.throw`
	/// - Returns: The response header from the server and the optional body data.
	@NHActor
	@discardableResult
	public func downloadMahDatas(
		for request: NetworkRequest,
		delegate: NetworkHandlerTaskDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		requestLogger: Logger? = nil,
		cancellationToken: NetworkCancellationToken? = nil,
		onError: @escaping RetryOptionBlock = { _, _, _ in .throw }
	) async throws(NetworkError) -> (responseHeader: EngineResponseHeader, data: Data?) {
		try await transferMahDatas(
			for: .standard(request),
			delegate: delegate,
			usingCache: cacheOption,
			requestLogger: requestLogger,
			cancellationToken: cancellationToken,
			onError: onError)
	}

	/// Downloads data from a server. Also used to send smaller chunks of data, like REST requests.
	///
	/// - Parameters:
	///		- `request`: The `NetworkRequest` to send.
	///		- `delegate`: Provides transfer lifecycle information.
	///		- cacheOption: Indicates whether to use cache and with what override key.
	///		  **Default**: `.dontUseCache`
	///		- `requestLogger`: Logger to use for this request.
	///		- `cancellationToken`: Optional token for cancelling the request before it completes.
	///		- `onError`: Error and retry handling. **Default**: `.throw`
	/// - Returns: The response header from the server and the optional body data.
	@NHActor
	@discardableResult
	public func transferMahDatas(
		for request: CompleteNetworkRequest,
		delegate: NetworkHandlerTaskDelegate? = nil,
		usingCache cacheOption: NetworkHandler.CacheKeyOption = .dontUseCache,
		requestLogger: Logger? = nil,
		cancellationToken: NetworkCancellationToken? = nil,
		onError: @escaping RetryOptionBlock = { _, _, _ in .throw }
	) async throws(NetworkError) -> (responseHeader: EngineResponseHeader, data: Data?) {
		if let cacheKey = cacheOption.cacheKey(url: request.url, method: request.method) {
			if let cachedData = cache.cachedItem(for: cacheKey) {
				return (cachedData.response, cachedData.data)
			}
		}

		let (header, data) = try await retryHandler(
			originalRequest: request,
			transferTask: { transferRequest, _ in
				let (streamHeader, stream) = try await streamMahDatas(
					for: transferRequest,
					delegate: delegate,
					requestLogger: requestLogger,
					cancellationToken: cancellationToken)

				var accumulator = Data()
				for try await chunk in stream {
					accumulator.append(contentsOf: chunk)
				}
				return (streamHeader, accumulator)
			},
			errorHandler: onError)

		if let cacheKey = cacheOption.cacheKey(url: request.url, method: request.method), let data {
			self.cache.setCachedItem(NetworkCacheStore(response: header, data: data), for: cacheKey)
		}

		return (header, data)
	}

	/// Streams data from a server. Powers the rest of NetworkHandler.
	/// - Parameters:
	///   - request: NetworkRequest
	///   - delegate: Provides transfer lifecycle information
	///   - requestLogger: Logger to use for this request
	///   - cancellationToken: Optional: Gives you the opportunity to create and hold a reference to a token
	///   allowing you to cancel the request before it completes.
	/// - Returns: The response header from the server and a data stream that provides data as it is received.
	@NHActor
	@discardableResult
	public func streamMahDatas( // swiftlint:disable:this cyclomatic_complexity
		for request: CompleteNetworkRequest,
		delegate: NetworkHandlerTaskDelegate? = nil,
		requestLogger: Logger? = nil,
		cancellationToken: NetworkCancellationToken? = nil
	) async throws(NetworkError) -> (responseHeader: EngineResponseHeader, stream: ResponseBodyStream) {
		let (httpResponse, bodyResponseStream): (EngineResponseHeader, ResponseBodyStream)
		do {
			switch request {
			case .upload(var uploadRequest, let payload):
				let inputReq = uploadRequest
				uploadRequest = uploadRequest.with {
					switch payload {
					case .data(let data):
						$0.expectedContentLength = data.count
					case .localFile(let fileURL):
						$0.expectedContentLength = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
					case .inputStream(let stream):
						$0.expectedContentLength = stream.streamCount
					}
				}
				if inputReq != uploadRequest {
					delegate?.requestModified(from: .upload(inputReq, payload: payload), to: .upload(uploadRequest, payload: payload))
				}

				let (sendProgressStream, sendProgressContinuation) = UploadProgressStream
					.makeStream(errorOnCancellation: NetworkError.requestCancelled)

				let uploadRequest = uploadRequest
				async let progressBlock: Void = { @NHActor [delegate] in
					var signaledStart = false
					for try await count in sendProgressStream {
						if signaledStart == false {
							signaledStart = true
							delegate?.transferDidStart(for: request)
						}
						try Task.checkCancellation()
						delegate?.sentData(
							for: request,
							totalByteCountSent: Int(count),
							totalExpectedToSend: uploadRequest.expectedContentLength)
					}
				}()

				cancellationToken?.onCancel = { sendProgressStream.cancel() }
				try cancellationToken?.checkIsCancelled()

				let (response, bodyStream) = try await engine.performNetworkTransfer(
					request: .upload(uploadRequest, payload: payload),
					uploadProgressContinuation: sendProgressContinuation,
					requestLogger: requestLogger)

				cancellationToken?.onCancel = { bodyStream.cancel() }
				try cancellationToken?.checkIsCancelled()
				bodyStream.onFinish { _ in
					Task { // placed in another task to avoid lock-deadlock
						cancellationToken?.onCancel = {}
					}
				}

				try await progressBlock
				httpResponse = response
				delegate?.responseHeaderRetrieved(for: request, header: httpResponse)
				bodyResponseStream = bodyStream
			case .standard(let generalRequest):
				try cancellationToken?.checkIsCancelled()
				let (header, bodyStream) = try await engine.performNetworkTransfer(
					request: .standard(generalRequest),
					uploadProgressContinuation: nil,
					requestLogger: requestLogger)
				cancellationToken?.onCancel = { bodyStream.cancel() }
				try cancellationToken?.checkIsCancelled()
				bodyStream.onFinish { _ in
					Task { // placed in another task to avoid lock-deadlock
						cancellationToken?.onCancel = {}
					}
				}

				delegate?.responseHeaderRetrieved(for: request, header: header)
				httpResponse = header
				let interceptedStream = ResponseBodyStream(errorOnCancellation: NetworkError.requestCancelled) { continuation in
					Task {
						var accumulatedBytes = 0
						do {
							for try await chunk in bodyStream {
								try continuation.yield(chunk)
								accumulatedBytes += chunk.count
								delegate?.responseBodyReceived(
									for: request,
									byteCount: accumulatedBytes,
									totalExpectedToReceive: header.expectedContentLength.map(Int.init))
								delegate?.responseBodyReceived(for: request, bytes: Data(chunk))
							}
							try continuation.finish()
							delegate?.requestFinished(withError: nil)
						} catch {
							try continuation.finish(throwing: error)
							delegate?.requestFinished(withError: error)
						}
					}
					continuation.onFinish { _ in bodyStream.cancel() }
				}
				bodyResponseStream = interceptedStream
			}
		} catch {
			throw NetworkError.convert(error)
		}

		guard request.expectedResponseCodes.rawValue.contains(httpResponse.status) else {
			logger.error("""
				Error: Server replied with unexpected status code: Got \(httpResponse.status) \
				expected \(request.expectedResponseCodes.rawValue)
				""")
			let data: Data? = await {
				var accumulator = Data()
				do {
					for try await bytes in bodyResponseStream {
						guard accumulator.count < 1024 * 1024 * 10 else { break }
						accumulator.append(contentsOf: bytes)
					}
				} catch {
					return accumulator.isOccupied ? accumulator : nil
				}
				return accumulator.isOccupied ? accumulator : nil
			}()
			throw NetworkError.httpUnexpectedStatusCode(code: httpResponse.status, originalRequest: request, data: data)
		}

		return (httpResponse, bodyResponseStream)
	}

	/// Internal retry loop. Evaluates conditions and output from `errorHandler` to determine what to try next.
	@NHActor
	private func retryHandler( // swiftlint:disable:this cyclomatic_complexity
		originalRequest: CompleteNetworkRequest,
		transferTask: @NHActor
			(_ request: CompleteNetworkRequest, _ attempt: Int) async throws -> (EngineResponseHeader, Data?),
		errorHandler: RetryOptionBlock
	) async throws(NetworkError) -> (EngineResponseHeader, Data?) {
		var retryOption = RetryOption.retry
		var theRequest = originalRequest
		var attempt = 1

		while case .retryWithConfiguration = retryOption {
			defer { attempt += 1 }

			let theError: NetworkError
			do {
				return try await NetworkError.captureAndConvert {
					try await transferTask(theRequest, attempt)
				}
			} catch {
				theError = error
			}

			retryOption = errorHandler(theRequest, attempt, theError)
			switch retryOption {
			case .retryWithConfiguration(config: let config):
				theRequest = config.updatedRequest ?? theRequest

				if case .upload(let uploadReq, payload: let payload) = theRequest {
					switch payload {
					case .inputStream(let streamable):
						guard streamable.isRetryable else {
							logger.error("This stream is not retryable")
							throw theError
						}
						theRequest = .upload(uploadReq, payload: .inputStream(streamable))
					default:
						break
					}
				}

				if config.delay > 0 {
					try await NetworkError.captureAndConvert {
						try await Task.sleep(nanoseconds: UInt64(TimeInterval(1_000_000_000) * config.delay))
					}
				}
			case .throw(updatedError: let updatedError):
				try NetworkError.captureAndConvert {
					throw updatedError ?? theError
				}
			case .defaultReturnValue(config: let returnConfig):
				let response: EngineResponseHeader
				switch returnConfig.response {
				case .full(let fullResponse):
					response = fullResponse
				case .code(let statusCode):
					response = EngineResponseHeader(status: statusCode, url: theRequest.url, headers: [:])
				}
				return (response, returnConfig.data)
			}
		}

		throw NetworkError.unspecifiedError(reason: "Escaped while loop")
	}

	private func decodeData<DecodableType: Decodable>(
		data: Data,
		using decoder: NHDecoder
	) throws(NetworkError) -> DecodableType {
		guard DecodableType.self != Data.self else {
			return data as! DecodableType // swiftlint:disable:this force_cast
		}

		do {
			let decodedValue = try decoder.decode(DecodableType.self, from: data)
			return decodedValue
		} catch {
			let codingError = NetworkError.dataCodingError(specifically: error, sourceData: data)
			logger.error(
				"Error: Couldn't decode \(DecodableType.self) from provided data",
				metadata: ["Error": "\(codingError)"])
			throw codingError
		}
	}

	/// Defines how cache lookup and storage should behave for a network request.
	///
	/// Supports boolean literal (`.true` / `.false`), string literal (for custom cache keys),
	/// and string-interpolation (`"\(string)"`).
	public enum CacheKeyOption:
		Equatable,
		ExpressibleByBooleanLiteral,
		ExpressibleByStringLiteral,
		ExpressibleByStringInterpolation,
		Sendable {

		/// Skip all cache operations.
		case dontUseCache
		/// Use the request's URL as the cache key.
		case useURL
		/// Use a custom string key for the cache.
		case key(String)

		/// Creates a `.useURL` cache key when `true`, otherwise `.dontUseCache`.
		public init(booleanLiteral value: BooleanLiteralType) {
			self = value ? .useURL : .dontUseCache
		}

		/// Creates a `.key` case from the string literal value.
		public init(stringLiteral value: StringLiteralType) {
			self = .key(value)
		}

		/// Determine the `NetworkCacheKey` for this option given a URL and HTTP method.
		///
		/// - Returns: A cache key if caching is applicable, or `nil` for `.dontUseCache`.
		func cacheKey(url: URL, method: HTTPRequest.Method) -> NetworkCacheKey? {
			switch self {
			case .dontUseCache:
				nil
			case .useURL:
				.urlMethod(url, method)
			case .key(let string):
				.rawString(string)
			}
		}
	}
}
