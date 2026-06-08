import Foundation
import Logging
import NetworkHandler
import NetworkHandlerAHCEngine
import SwiftPizzaSnips
import Testing
import TestSupport

struct NetworkHandlerAHCTests: Sendable {
	let commonTests = NetworkHandlerCommonTests<HTTPClient>(logger: Logger(label: #fileID))

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func downloadAndCacheImages() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.downloadAndCacheImages(
			engine: mockingEngine)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func downloadAndDecodeData() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.downloadAndDecodeData(engine: mockingEngine)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func handle404() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.handle404Error(
			engine: mockingEngine)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func expect200OnlyGet200() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.expect200OnlyGet200(engine: mockingEngine)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func expect201OnlyGet200() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.expect201OnlyGet200(engine: mockingEngine)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func uploadData() async throws {
		let mockingEngine = generateEngine()
		try await commonTests.uploadData(engine: mockingEngine)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func uploadFileURL() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.uploadFileURL(engine: mockingEngine)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func uploadMultipartFile() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.uploadMultipartFile(engine: mockingEngine)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func uploadMultipartStream() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.uploadMultipartStream(engine: mockingEngine)
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

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func timeoutTriggersRetry() async throws {
		let mockingEngine = generateEngine()
		try await commonTests.timeoutTriggersRetry(engine: mockingEngine)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func downloadProgressTracking() async throws {
		let mockingEngine = generateEngine()
		try await commonTests.downloadProgressTracking(engine: mockingEngine)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func uploadProgressTracking() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.uploadProgressTracking(engine: mockingEngine)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func polling() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.polling(engine: mockingEngine)
	}

	@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
	@Test func downloadFile() async throws {
		let mockingEngine = generateEngine()

		try await commonTests.downloadFile(engine: mockingEngine)
	}

	private func generateEngine() -> HTTPClient {
		HTTPClient()
	}
}
