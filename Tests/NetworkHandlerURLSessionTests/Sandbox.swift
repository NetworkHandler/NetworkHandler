import Foundation
import NetworkHandler
import NetworkHandlerURLSessionEngine
import Testing
import TestSupport

struct Sandbox {
	@Test func server() async throws {
		let server = try MockingServer(port: 15_151)

		server.addMock(
			for: "asdf/foo/bar",
			method: .get,
			responseData: Data(#"{"foo": "bar"}"#.utf8),
			responseCode: 200)

		let engine = URLSession.asEngine()

		let handler = NetworkHandler(name: "Mock test", engine: engine)

		let request = try #require(URL(string: "http://localhost:15151/asdf/foo/bar")?.generalRequest)
			.with {
				$0.expectedResponseCodes = .init(range: 0..<1000)
			}
		let asdf = try await handler.downloadMahDatas(for: request)

		print(asdf, server)
	}
}
