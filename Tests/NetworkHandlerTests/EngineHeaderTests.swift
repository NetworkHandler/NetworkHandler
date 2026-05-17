import Foundation
import HTTPTypes
import NetworkHandler
import PizzaMacros
import Testing

struct EngineHeaderTests {
	/// Verifies EngineResponseHeader.description includes status, URL,
	/// content-length, MIME type, and suggested filename when present.
	@Test func responseDescription() {
		let url = #URL("https://redeggproductions.com")
		let response = EngineResponseHeader(
			status: 200,
			url: url,
			headers: [
				.contentLength: "\(1024)",
				.contentDisposition: "attachment; filename=\"asdf qwerty.jpg\"",
				.contentType: .json,
			])

		// When the description string is generated.
		let description = "\(response)"

		print(description)

		// Then all expected fields appear in the formatted output.
		#expect(description.contains("Status - 200"))
		#expect(description.contains("URL - https://redeggproductions.com"))
		#expect(description.contains("Expected length - 1024"))
		#expect(description.contains("MIME Type - application/json"))
		#expect(description.contains("Suggested Filename - asdf qwerty.jpg"))
	}

	/// Verifies EngineResponseHeader.description omits optional fields
	/// (like suggested filename) when their headers are absent.
	@Test func responseDescriptionNoOptionalFields() {
		let url = #URL("https://redeggproductions.com")
		// Given a response without content-disposition.
		let response = EngineResponseHeader(
			status: 200,
			url: url,
			headers: [
				.contentLength: "\(1024)",
				.contentType: .json,
			])

		// When the description string is generated.
		let description2 = "\(response)"

		// Then "Suggested Filename" should not appear.
		#expect(description2.contains("Suggested Filename") == false)
	}
}
