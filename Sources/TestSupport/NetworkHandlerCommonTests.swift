import Crypto
import Foundation
import Logging
import NetworkHandler
import PizzaMacros
import SwiftPizzaSnips
import Testing
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// swiftlint:disable:next type_body_length
public struct NetworkHandlerCommonTests<Engine: NetworkEngine>: Sendable {
	#if canImport(AppKit)
	public typealias TestImage = NSImage
	#elseif canImport(UIKit)
	public typealias TestImage = UIImage
	#endif

	private let baseLocalURL = #URL("http://localhost")
	public func imageURL(port: UInt16) -> URL {
		baseLocalURL
			.withPort(port)
			.appending(path: "network-handler-tests/images/lighthouse.jpg")
	}
	public func demoModelURL(port: UInt16) -> URL {
		baseLocalURL
			.withPort(port)
			.appending(path: "network-handler-tests/coding/demoModel.json")
	}
	public func badDemoModelURL(port: UInt16) -> URL {
		baseLocalURL
			.withPort(port)
			.appending(path: "network-handler-tests/coding/badDemoModel.json")
	}
	public func demo404URL(port: UInt16) -> URL {
		baseLocalURL
			.withPort(port)
			.appending(path: "network-handler-tests/coding/akjsdhjklahgdjkahsfjkahskldf.json")
	}
	public func uploadURL(port: UInt16) -> URL {
		baseLocalURL
			.withPort(port)
			.appending(path: "network-handler-tests/uploader.bin")
	}
	public func randomDataURL(port: UInt16) -> URL {
		baseLocalURL
			.withPort(port)
			.appending(path: "network-handler-tests/randomData.bin")
	}
	public func chonkURL(port: UInt16) -> URL {
		baseLocalURL
			.withPort(port)
			.appending(path: "network-handler-tests/chonk.bin")
	}
	public let echoURL = #URL("https://echo.free.beeceptor.com/")

	public let logger: Logger

	public init(logger: Logger) {
		self.logger = logger
	}

	/// Tests downloading, caching the download, and subsequently loading the file from cache.
	/// performs a `GET` request to `imageURL`
	public func downloadAndCacheImages(
		engine: Engine,
		mockServerPort: UInt16,
		imageExpectationData: Data,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		column: Int = #column,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let rawStart = Date()
		let image1Result = try await nh.downloadMahDatas(
			for: imageURL(port: mockServerPort).generalRequest,
			usingCache: .key("kitten"),
			requestLogger: logger)
		let rawFinish = Date()

		let cacheStart = Date()
		let image2Result = try await nh.downloadMahDatas(
			for: imageURL(port: mockServerPort).generalRequest,
			usingCache: .key("kitten"),
			requestLogger: logger)
		let cacheFinish = Date()

		// calculate cache speed improvement, just for funsies
		let rawDuration = rawFinish.timeIntervalSince(rawStart)
		let cacheDuration = cacheFinish.timeIntervalSince(cacheStart)
		let cacheRatio = cacheDuration / rawDuration

		let formatter = NumberFormatter()
		formatter.maximumFractionDigits = 6
		let netDurationStr = formatter.string(from: rawDuration as NSNumber) ?? "nan"
		let cacheDurationStr = formatter.string(from: cacheDuration as NSNumber) ?? "nan"
		let cacheRatioStr = formatter.string(from: cacheRatio as NSNumber) ?? "nan"
		logger
			.info("netDuration: \(netDurationStr)\ncacheDuration: \(cacheDurationStr)\ncache took \(cacheRatioStr)x as long")
		#expect(
			cacheDuration < (rawDuration * 0.5),
			"The cache lookup wasn't even twice as fast as the original lookup. It's possible the cache isn't working",
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column))

		let imageOneData = image1Result.data
		let imageTwoData = image2Result.data
		#expect(
			imageOneData == imageTwoData,
			"hashes: \(imageOneData.hashValue) and \(imageTwoData.hashValue)",
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column))
		#expect(
			imageOneData == imageExpectationData,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column))

		#if canImport(AppKit) || canImport(UIKit)
		_ = try #require(
			imageOneData.flatMap { TestImage(data: $0) },
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column))
		#endif
	}

	public func downloadAndDecodeData<D: Decodable & Sendable & Equatable>(
		engine: Engine,
		modelURL: URL,
		expectedModel: D,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		column: Int = #column,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let resultModel: D = try await nh.downloadMahCodableDatas(
			for: modelURL.generalRequest,
			delegate: nil,
			requestLogger: logger).decoded

		#expect(
			expectedModel == resultModel,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column))
	}

	/// performs a `GET` request to `demo404URL`
	public func handle404Error(
		engine: Engine,
		mockingPort: UInt16,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		column: Int = #column,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let url = demo404URL(port: mockingPort)

		let error = await #expect(
			throws: NetworkError.self,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column)
		) {
			let _: String = try await nh.downloadMahCodableDatas(
				for: url.generalRequest,
				delegate: nil,
				requestLogger: logger).decoded
		}

		guard
			case .httpUnexpectedStatusCode(code: let code, originalRequest: _, data: _) = error
		else {
			Issue.record(
				"Incorrect error",
				sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column)
			)
			return
		}

		#expect(code == 404, sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column))
	}

	/// performs a `GET` request to `demoModelURL`
	public func expect200OnlyGet200(
		engine: Engine,
		mockingPort: UInt16,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		column: Int = #column,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let url = demoModelURL(port: mockingPort)
		let request = url.generalRequest.with {
			$0.expectedResponseCodes = 200
		}

		await #expect(
			throws: Never.self,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column)
		) {
			_ = try await nh.transferMahDatas(
				for: .standard(request),
				requestLogger: logger,
				onError: { _, _, _  in .throw })
		}
	}

	/// performs a `POST` request to `demoModelURL`
	public func expect201OnlyGet200(
		engine: Engine,
		mockingPort: UInt16,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		column: Int = #column,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let payloadData = Data("""
			{"id":"59747267-D47D-47CD-9E54-F79FA3C1F99B","imageURL":\
			"https://s3.wasabisys.com/network-handler-tests/images/lighthouse.jpg"\
			,"subtitle":"BarSub","title":"FooTitle"}
			""".utf8)
		let url = demoModelURL(port: mockingPort)
		let request = url.generalRequest.with {
			$0.expectedResponseCodes = 201
			$0.method = .put
			$0.payload = payloadData
		}

		let error = await #expect(
			throws: NetworkError.self,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column)
		) {
			_ = try await nh.transferMahDatas(
				for: .standard(request),
				requestLogger: logger,
				onError: { _, _, _  in .throw })
		}

		guard
			case .httpUnexpectedStatusCode(code: let code, originalRequest: _, data: _) = error
		else {
			Issue.record(
				"Incorrect error type",
				sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column))
			return
		}
		#expect(code == 200, sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column))
	}

	/// performs a `PUT` request to `randomDataURL`. Provided must be corrupted in some way.
	public func uploadData(
		engine: Engine,
		mockingPort: UInt16,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		column: Int = #column,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let url = randomDataURL(port: mockingPort)
		let request = url.generalRequest.with {
			$0.method = .put
			$0.headers.setAuthorization(.bearerToken("foobar"))
			$0.expectedResponseCodes = 201
		}

		let sizeOfUploadMB: UInt8 = 5
		let fileSize = Int(sizeOfUploadMB) * 1024 * 1024

		var rng: any RandomNumberGenerator = SeedableRNG(seed: 349_687)
		let randomData = Data.random(count: fileSize, using: &rng)

		let dataHash = SHA256.hash(data: randomData)
		print(dataHash)

		let atomicRequest = AtomicValue(value: CompleteNetworkRequest.upload(request, payload: .data(randomData)))
		let delegate = await Delegate(onRequestModified: { _, _, new in
			atomicRequest.value = new
		})

		_ = try await nh.uploadMahDatas(for: request, payload: .data(randomData), delegate: delegate)
		#expect(
			atomicRequest.value.expectedContentLength != nil,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column))

		let dlRequest = url.generalRequest

		let dlResult = try await #require(nh.downloadMahDatas(for: dlRequest).data)
		#expect(
			SHA256.hash(data: dlResult) == dataHash,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column))
	}

	/// performs a `PUT` request to `uploadURL`
	public func uploadFileURL(
		engine: Engine,
		mockingPort: UInt16,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		column: Int = #column,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let url = uploadURL(port: mockingPort)
		let upRequest = url.generalRequest.with {
			$0.method = .put
			$0.expectedResponseCodes = 201
			$0.headers.setAuthorization(.bearerToken("foobar"))
		}

		let testFileURL = URL.temporaryDirectory.appending(component: UUID().uuidString).appendingPathExtension("bin")
		let (actualTestFile, done) = try createDummyFile(at: testFileURL, megabytes: 5)
		defer { try? done() }

		let hash = try fileHash(actualTestFile)

		let atomicRequest = AtomicValue(value: CompleteNetworkRequest.upload(upRequest, payload: .localFile(actualTestFile)))
		let delegate = await Delegate(onRequestModified: { _, _, new in
			atomicRequest.value = new
		})
		_ = try await nh.uploadMahDatas(for: upRequest, payload: .localFile(actualTestFile), delegate: delegate)
		#expect(
			atomicRequest.value.expectedContentLength != nil,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column))

		let dlRequest = url.generalRequest

		let dlResult = try await #require(nh.transferMahDatas(for: .standard(dlRequest)).data)
		#expect(
			SHA256.hash(data: dlResult) == hash,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column))
	}

	/// performs a `PUT` request to `uploadURL`
	public func uploadMultipartFile(
		engine: Engine,
		mockingPort: UInt16,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		column: Int = #column,
		function: String = #function
	) async throws {
		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let uploadURL = uploadURL(port: mockingPort)

		let upRequest = uploadURL.generalRequest.with {
			$0.method = .put
			$0.expectedResponseCodes = 201
			$0.headers.setAuthorization(.bearerToken("foobar"))
		}

		let testFileURL = URL.temporaryDirectory.appending(component: UUID().uuidString).appendingPathExtension("bin")
		let (actualTestFile, done) = try createDummyFile(at: testFileURL, megabytes: 5)
		defer { try? done() }

		let boundary = "akjlsdghkajshdg"
		let multipart = MultipartFormInputTempFile(boundary: boundary)
		multipart.addPart(named: "file", fileURL: actualTestFile, contentType: "application/octet-stream")

		let multipartFile = try await multipart.renderToFile()
		defer { try? FileManager.default.removeItem(at: multipartFile )}

		let multipartHash = try fileHash(multipartFile)

		let atomicRequest = AtomicValue(value: CompleteNetworkRequest.upload(upRequest, payload: .localFile(multipartFile)))
		let delegate = await Delegate(onRequestModified: { _, _, new in
			atomicRequest.value = new
		})
		_ = try await nh.uploadMahDatas(for: upRequest, payload: .localFile(multipartFile), delegate: delegate)
		#expect(
			atomicRequest.value.expectedContentLength != nil,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column))

		let dlRequest = uploadURL.generalRequest

		let dlResult = try await #require(nh.transferMahDatas(for: .standard(dlRequest)).data)
		#expect(
			SHA256.hash(data: dlResult) == multipartHash,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column))
	}


	/// performs a `GET` request to `randomDataURL`. Provided must be corrupted in some way.
	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	public func cancellationViaToken(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		column: Int = #column,
		function: String = #function
	) async throws {
		let server = try MockingServer.createServer()

		let accumulatedThreshold = 40_960

		let url = randomDataURL(port: server.port)
		server.addMock(for: url.mockingPath, method: .get) { _, stream throws(MockingServer.HTTPError) in
			stream(.header(.init(responseCode: 200)))

			var gen: any RandomNumberGenerator = SeedableRNG(seed: 6_549_879)
			var count = 0
			while count < (accumulatedThreshold * 10) {
				stream(.data(Data.random(count: 256, using: &gen)))
				try await MockingServer.HTTPError.capture {
					try await Task.sleep(for: .microseconds(100))
				}
				count += 256
				print(count)
			}
			stream(.complete)
		}

		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let request = url.generalRequest

		let cancelToken = NetworkCancellationToken()
		let forCancel = Task {
			let accumulated = AtomicValue(value: 0)
			let delegate = await Delegate(onResponseBodyProgress: { [accumulated] _, _, bodyData in
				accumulated.value += bodyData.count

				guard accumulated.value > accumulatedThreshold else { return }
				cancelToken.cancel()
			})

			return try await nh.transferMahDatas(for: .standard(request), delegate: delegate, cancellationToken: cancelToken)
		}

		await #expect(throws: NetworkError.requestCancelled, performing: {
			_ = try await forCancel.value
		})
	}

	/// performs a `GET` request to `randomDataURL`. Provided must be corrupted in some way.
	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	public func cancellationViaStream(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		column: Int = #column,
		function: String = #function
	) async throws {
		let server = try MockingServer.createServer()

		let accumulatedThreshold = 40_960

		let url = randomDataURL(port: server.port)
		server.addMock(for: url.mockingPath, method: .get) { _, stream throws(MockingServer.HTTPError) in
			stream(.header(.init(responseCode: 200)))

			var gen: any RandomNumberGenerator = SeedableRNG(seed: 6_549_879)
			var count = 0
			while count < (accumulatedThreshold * 10) {
				stream(.data(Data.random(count: 256, using: &gen)))
				try await MockingServer.HTTPError.capture {
					try await Task.sleep(for: .microseconds(100))
				}
				count += 256
				print(count)
			}
			stream(.complete)
		}

		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let request = url.generalRequest

		let stream = try await nh.streamMahDatas(for: .standard(request)).stream

		let forCancel = Task {
			var accumulated = Data()
			for try await chunk in stream {
				accumulated.append(contentsOf: chunk)
				guard accumulated.count > accumulatedThreshold else { continue }
				stream.cancel()
			}
		}

		await #expect(throws: NetworkError.requestCancelled, performing: {
			_ = try await forCancel.value
		})
	}

	/// performs a `PUT` request to `badDemoModelURL`. Provided must be corrupted in some way.
	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	public func uploadCancellationViaToken(
		engine: Engine,
		file: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		column: Int = #column,
		function: String = #function
	) async throws {
		let server = try MockingServer.createServer()

		let url = uploadURL(port: server.port)
		server.addMock(for: url.mockingPath, method: .put, responseData: nil)

		let nh = getNetworkHandler(with: engine)
		defer { nh.resetCache() }

		let request = url.generalRequest.with {
			$0.method = .put
		}

		var rng: RandomNumberGenerator = SeedableRNG(seed: 9_345_867)
		let randomData = Data.random(count: 1024 * 1024 * 10, using: &rng)

		let token = NetworkCancellationToken()

		let task = Task {
			let delegate = await Delegate(onSendData: { _, _, bytesSent, _ in
				guard bytesSent > (1024 * 1024 * 2) else { return }
				token.cancel()
			})

			return try await nh.uploadMahDatas(
				for: request,
				payload: .data(randomData),
				delegate: delegate,
				cancellationToken: token)
		}

		await #expect(
			throws: NetworkError.requestCancelled,
			sourceLocation: SourceLocation(fileID: file, filePath: filePath, line: line, column: column),
			performing: {
				_ = try await task.value
			})
	}

	public struct BeeEchoModel: Codable, Sendable {
		public let path: String

		public var pathValue: Int? {
			let num = path.drop(while: { $0.isNumber == false })
			return Int(num)
		}

		public init(path: String) {
			self.path = path
		}
	}

	// MARK: - Utilities
	private func getNetworkHandler(with engine: Engine, function: String = #function) -> NetworkHandler<Engine> {
		let nh = NetworkHandler(name: "\(#fileID) - \(Engine.self) (\(function))", engine: engine)
		nh.resetCache()
		return nh
	}

	private func createDummyFile(
		at url: URL,
		megabytes: Int,
		using rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
	) throws -> (file: URL, done: () throws -> Void) {
		let outFile = {
			var current = url
			while current.checkResourceIsAccessible() {
				let fileName = current.deletingPathExtension().lastPathComponent
				let newFilename = fileName + "_copy"
				current = current.deletingLastPathComponent().appending(component: newFilename).appendingPathExtension("bin")
			}
			return current
		}()
		guard
			let outputStream = OutputStream(url: outFile, append: false)
		else { throw SimpleTestError(message: "no output stream") }
		outputStream.open()
		defer { outputStream.close() }
		let length = 1024 * 1024
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
		defer { buffer.deallocate() }
		let raw = UnsafeMutableRawPointer(buffer)
		let quicker = raw.bindMemory(to: UInt64.self, capacity: length / 8)

		var rng = rng
		(0..<megabytes).forEach { _ in
			for index in 0..<(length / 8) {
				quicker[index] = UInt64.random(in: 0...UInt64.max, using: &rng)
			}

			_ = outputStream.write(buffer, maxLength: length)
		}

		let done = {
			try FileManager.default.removeItem(at: outFile)
		}
		return (outFile, done)
	}

	private func fileHash(_ url: URL) throws -> SHA256Digest {
		guard let input = InputStream(url: url) else { throw NSError(domain: "Error loading file for hashing", code: -1) }

		return try streamHash(input)
	}

	private func streamHash(_ input: InputStream) throws -> SHA256Digest {
		var hasher = SHA256()

		let bufferSize = 1024 // KB
		* 1024 // MB
		* 10 // MB count
		let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: bufferSize)
		guard let pointer = buffer.baseAddress else { throw NSError(domain: "Error allocating buffer", code: -2) }
		input.open()
		while input.hasBytesAvailable {
			let bytesRead = input.read(pointer, maxLength: bufferSize)
			let bufferrr = UnsafeRawBufferPointer(start: pointer, count: bytesRead)
			hasher.update(bufferPointer: bufferrr)
		}
		input.close()

		return hasher.finalize()
	}
}

extension NetworkHandlerCommonTests {
	class Delegate: NetworkHandlerTaskDelegate {
		let onRequestModified: @Sendable (
			_ delegate: Delegate,
			_ original: CompleteNetworkRequest,
			_ modified: CompleteNetworkRequest
		) -> Void
		let onStart: @Sendable (_ delegate: Delegate, CompleteNetworkRequest) -> Void
		let onSendData: @Sendable (
			_ delegate: Delegate,
			_ request: CompleteNetworkRequest,
			_ totalByteCountSent: Int,
			_ totalExpected: Int?
		) -> Void
		let onSendingFinish: @Sendable (_ delegate: Delegate, CompleteNetworkRequest) -> Void
		let onResponseHeader: @Sendable (
			_ delegate: Delegate,
			_ request: CompleteNetworkRequest,
			_ header: EngineResponseHeader
		) -> Void
		let onResponseBodyProgress: @Sendable (_ delegate: Delegate, _ request: CompleteNetworkRequest, _ bytes: Data) -> Void
		let onResponseBodyProgressCount: @Sendable (
			_ delegate: Delegate,
			_ request: CompleteNetworkRequest,
			_ byteCount: Int,
			_ expectedTotal: Int?
		) -> Void
		let onRequestFinished: @Sendable (_ delegate: Delegate, Error?) -> Void

		init(
			onRequestModified: @escaping @Sendable (
				_ delegate: Delegate,
				_ original: CompleteNetworkRequest,
				_ modified: CompleteNetworkRequest
			) -> Void = { _, _, _ in },
			onStart: @escaping @Sendable (_ delegate: Delegate, CompleteNetworkRequest) -> Void = { _, _ in },
			onSendData: @escaping @Sendable (
				_ delegate: Delegate,
				_: CompleteNetworkRequest,
				_: Int,
				_: Int?
			) -> Void = { _, _, _, _ in },
			onSendingFinish: @escaping @Sendable (_ delegate: Delegate, CompleteNetworkRequest) -> Void = { _, _ in },
			onResponseHeader: @escaping @Sendable (
				_ delegate: Delegate,
				_: CompleteNetworkRequest,
				_: EngineResponseHeader
			) -> Void = { _, _, _ in },
			onResponseBodyProgress: @escaping @Sendable (
				_ delegate: Delegate,
				_: CompleteNetworkRequest,
				_: Data
			) -> Void = { _, _, _ in },
			onResponseBodyProgressCount: @escaping @Sendable (
				_ delegate: Delegate,
				_ request: CompleteNetworkRequest,
				_ byteCount: Int,
				_ expectedTotal: Int?
			) -> Void = { _, _, _, _ in },
			onRequestFinished: @escaping @Sendable (_ delegate: Delegate, Error?) -> Void = { _, _ in }
		) {
			self.onRequestModified = onRequestModified
			self.onStart = onStart
			self.onSendData = onSendData
			self.onSendingFinish = onSendingFinish
			self.onResponseHeader = onResponseHeader
			self.onResponseBodyProgress = onResponseBodyProgress
			self.onResponseBodyProgressCount = onResponseBodyProgressCount
			self.onRequestFinished = onRequestFinished
		}

		func requestModified(from oldVersion: CompleteNetworkRequest, to newVersion: CompleteNetworkRequest) {
			onRequestModified(self, oldVersion, newVersion)
		}

		func transferDidStart(for request: CompleteNetworkRequest) {
			onStart(self, request)
		}

		func sentData(for request: CompleteNetworkRequest, totalByteCountSent: Int, totalExpectedToSend: Int?) {
			onSendData(self, request, totalByteCountSent, totalExpectedToSend)
		}

		func sendingDataDidFinish(for request: CompleteNetworkRequest) {
			onSendingFinish(self, request)
		}

		func responseHeaderRetrieved(for request: CompleteNetworkRequest, header: EngineResponseHeader) {
			onResponseHeader(self, request, header)
		}

		func responseBodyReceived(for request: CompleteNetworkRequest, bytes: Data) {
			onResponseBodyProgress(self, request, bytes)
		}

		func responseBodyReceived(for request: CompleteNetworkRequest, byteCount: Int, totalExpectedToReceive: Int?) {
			onResponseBodyProgressCount(self, request, byteCount, totalExpectedToReceive)
		}

		func requestFinished(withError error: (any Error)?) {
			onRequestFinished(self, error)
		}
	}
} // swiftlint:disable:this file_length
