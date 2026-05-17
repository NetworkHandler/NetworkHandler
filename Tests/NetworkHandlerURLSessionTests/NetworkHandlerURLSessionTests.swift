import Foundation
import Logging
import NetworkHandler
import NetworkHandlerURLSessionEngine
import SwiftPizzaSnips
import Testing
import TestSupport

struct NetworkHandlerURLSessionTests: Sendable {
	let commonTests = NetworkHandlerCommonTests<URLSession>(logger: Logger(label: #fileID))

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func downloadAndCacheImages() async throws {
		let server = try await MockingServer.createServer(name: #function)

		let lighthouseURL = try #require(Bundle.testBundle.url(forResource: "lighthouse", withExtension: "jpg"))
		let lighthouseData = try Data(contentsOf: lighthouseURL)

		server.addMock(
			for: commonTests.imageURL(port: server.port).mockingPath,
			method: .get,
			responseData: lighthouseData,
			responseCode: 200,
			delay: 0.5)

		let mockingEngine = generateEngine()

		try await commonTests.downloadAndCacheImages(
			engine: mockingEngine,
			mockServerPort: server.port,
			imageExpectationData: lighthouseData)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func downloadAndDecodeData() async throws {
		let server = try await MockingServer.createServer(name: #function)
		let modelURL = commonTests.demoModelURL(port: server.port)

		let modelStr = """
			{"id":"59747267-D47D-47CD-9E54-F79FA3C1F99B","imageURL":\
			"\(commonTests.imageURL(port: server.port).absoluteString)",\
			"subtitle":"BarSub","title":"FooTitle"}
			"""
		let modelData = Data(modelStr.utf8)

		server.addMock(
			for: modelURL.mockingPath,
			responseData: modelData,
			responseCode: 200)

		let mockingEngine = generateEngine()
		let testModel = try DemoModel(
			id: #require(UUID(uuidString: "59747267-D47D-47CD-9E54-F79FA3C1F99B")),
			title: "FooTitle",
			subtitle: "BarSub",
			imageURL: commonTests.imageURL(port: server.port))

		try await commonTests.downloadAndDecodeData(engine: mockingEngine, modelURL: modelURL, expectedModel: testModel)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func handle404() async throws {
		let server = try await MockingServer.createServer(name: #function)
		let mockingEngine = generateEngine()

		try await commonTests.handle404Error(
			engine: mockingEngine,
			mockingPort: server.port)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func expect200OnlyGet200() async throws {
		let server = try await MockingServer.createServer(name: #function)
		let demoModelURL = commonTests.demoModelURL(port: server.port)

		server.addMock(for: demoModelURL.mockingPath, responseData: nil, responseCode: 200)

		let mockingEngine = generateEngine()

		try await commonTests.expect200OnlyGet200(engine: mockingEngine, mockingPort: server.port)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func expect201OnlyGet200() async throws {
		let server = try await MockingServer.createServer(name: #function)
		let demoModelURL = commonTests.demoModelURL(port: server.port)

		server.addMock(for: demoModelURL.mockingPath, method: .put, responseData: nil, responseCode: 200)

		let mockingEngine = generateEngine()

		try await commonTests.expect201OnlyGet200(engine: mockingEngine, mockingPort: server.port)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func uploadData() async throws {
		let server = try await MockingServer.createServer(name: #function)
		let url = commonTests.randomDataURL(port: server.port)

		server.addMock(for: url.mockingPath, method: .put) {
			[unowned server] inReq, respStream throws(MockingServer.HTTPError) in

			try commonPutToGet(
				mockingPath: url.mockingPath,
				server: server,
				inRequest: inReq,
				responseStream: respStream)
		}

		let mockingEngine = generateEngine()
		try await commonTests.uploadData(engine: mockingEngine, mockingPort: server.port)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func backgroundSessionUpload() async throws {
		let server = try await MockingServer.createServer(name: #function)
		let url = commonTests.uploadURL(port: server.port)

		server.addMock(for: url.mockingPath, method: .put) {
			[unowned server] inReq, respStream throws(MockingServer.HTTPError) in

			try commonPutToGet(
				mockingPath: url.mockingPath,
				server: server,
				inRequest: inReq,
				responseStream: respStream)
		}

		let config = URLSessionConfiguration.background(withIdentifier: "backgroundID").with {
			$0.requestCachePolicy = .reloadIgnoringLocalCacheData
			$0.urlCache = nil
		}

		let engine = URLSession.asEngine(withConfiguration: config)

		try await commonTests.uploadFileURL(engine: engine, mockingPort: server.port)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func uploadFileURL() async throws {
		let server = try await MockingServer.createServer(name: #function)
		let url = commonTests.uploadURL(port: server.port)

		server.addMock(for: url.mockingPath, method: .put) {
			[unowned server] inReq, respStream throws(MockingServer.HTTPError) in

			try commonPutToGet(
				mockingPath: url.mockingPath,
				server: server,
				inRequest: inReq,
				responseStream: respStream)
		}

		let mockingEngine = generateEngine()

		try await commonTests.uploadFileURL(engine: mockingEngine, mockingPort: server.port)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func uploadMultipartFile() async throws {
		let server = try await MockingServer.createServer(name: #function)
		let uploadURL = commonTests.uploadURL(port: server.port)

		server.addMock(for: uploadURL.mockingPath, method: .put) {
			[unowned server] inReq, respStream throws(MockingServer.HTTPError) in

			try commonPutToGet(
				mockingPath: uploadURL.mockingPath,
				server: server,
				inRequest: inReq,
				responseStream: respStream)
		}

		let mockingEngine = generateEngine()

		try await commonTests.uploadMultipartFile(engine: mockingEngine, mockingPort: server.port)
	}


	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func cancellationViaToken() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.cancellationViaToken(engine: mockingEngine)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func cancellationViaStream() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.cancellationViaStream(engine: mockingEngine)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func uploadCancellationViaToken() async throws {
		let mockingEngine = generateEngine()
		try await commonTests.uploadCancellationViaToken(engine: mockingEngine)
	}

	private func generateEngine() -> URLSession {
		URLSession.asEngine(withConfiguration: .networkHandlerDefault)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	private func commonPutToGet(
		mockingPath: MockingServer.Path,
		server: MockingServer,
		inRequest: MockingServer.IncomingRequest,
		responseStream: MockingServer.ResponseStream.Block
	) throws(MockingServer.HTTPError) {
		guard inRequest.headers[.authorization] == "Bearer foobar" else {
			throw .init(code: 401)
		}

		guard
			let uploadedData = inRequest.payload
		else {
			throw .init(code: 400, errorDescription: "No payload")
		}

		server.addMock(for: mockingPath, responseData: uploadedData)

		responseStream(.header(.init(responseCode: 201)))
		responseStream(.complete)
	}
}
