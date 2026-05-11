import Testing
import TestSupport

struct Sandbox {
	@Test func server() async throws {
		let server = try MockingServer(port: 15151)

		try await Task.sleep(for: .seconds(500))
	}
}
