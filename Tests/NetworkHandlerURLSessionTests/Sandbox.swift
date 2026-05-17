import Foundation
import NetworkHandler
import NetworkHandlerURLSessionEngine
import Testing
import TestSupport

struct Sandbox {
	@available(macOS 15.0.0, *)
	@Test func server() async throws {
		let server = try MockingServer(serverName: "sandbox", port: 15_151)

		server.addMock(
			for: "asdf/foo/bar",
			method: .get,
			responseData: Data(#"{"foo": "bar"}"#.utf8),
			responseCode: 200)

		server.addMock(for: ["fdsa"], method: .put) { request, stream throws(MockingServer.HTTPError) in
			guard request.headers[.authorization] != nil else { throw .init(code: 403) }

			stream(.header(MockingServer.OutboundResponseHeader(responseCode: 201)))

			stream(.string("All good"))
		}

		let engine = URLSession.asEngine()

		let handler = NetworkHandler(name: "Mock test", engine: engine)

		let request = try #require(URL(string: "http://localhost:15151/fdsa")?.generalRequest)
			.with {
				$0.expectedResponseCodes = .init(range: 0..<1000)
				$0.method = .put
				$0.headers.setAuthorization("Foobar")
			}
		let asdf = try await handler.downloadMahDatas(for: request)

		print(asdf, server)
	}
}
