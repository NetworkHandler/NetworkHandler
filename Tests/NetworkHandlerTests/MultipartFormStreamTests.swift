import Foundation
import NetworkHandler
import SwiftPizzaSnips
import Testing
import TestSupport

/// Tests for `MultipartForm` streaming behavior, including stream generation,
/// multipart rendering, and stream copy consistency.
@Suite
class MultipartFormStreamTests {
	private var teardownBlocks: [() -> Void] = []

	/// Teardown: execute all registered cleanup blocks on deallocation.
	deinit {
		for block in teardownBlocks {
			block()
		}
	}

	/// Validates that `MultipartForm.createStream()` produces bytes identical
	/// to `render()`, verifying stream integrity for a multi-part form.
	@Test
	func streamData() async throws {
		// Given a form with a known composition
		let boundary = "alsdkfajklsghdkjashdf"
		var form = MultipartForm(boundary: boundary)

		// A file part constructed via `randomLoremIpsum` and written to disk
		var rng: any RandomNumberGenerator = SeedableRNG(seed: 498_567)
		let loremIpsum = Data(String.randomLoremIpsum(wordCount: 6, using: &rng).utf8)

		let file = URL.temporaryDirectory.appending(component: "lorem-\(Int.random(in: 1000..<9999)).txt")
		defer { try? FileManager.default.removeItem(at: file) }
		try loremIpsum.write(to: file)
		form.append(file, named: "lorem", filename: "lorem.txt")

		// A data part (JSON-encoded sample object)
		let jsonSample = MultipartFormTests.Sample(value: 5, label: "asdf", sub: nil)
		let jsonData = try JSONEncoder()
			.with { $0.outputFormatting = [.sortedKeys, .withoutEscapingSlashes] }
			.encode(jsonSample)
		form.append(jsonData, named: "metadata")

		// A plain-string part
		let randomString = "bloo bar baz\n\ntrue fuzz"
		form.append(randomString, named: "randomized")

		let totalFormOutput = try form.render()
		let initialRenderHash = totalFormOutput.persistentHashValue().toHexString()
		#expect(initialRenderHash == "5c37579f467b73a33a99ba13b596a10f")

		// When the form is rendered as a stream
		let stream = try form.createStream()

		// Then the stream bytes match the rendered data
		var finalData = Data()

		let bufferSize = 128
		let testPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
		defer { testPointer.deallocate() }

		stream.open()
		defer { stream.close() }
		while stream.hasBytesAvailable {
			let readCount = stream.read(testPointer, maxLength: bufferSize)

			let data = Data(bytes: testPointer, count: readCount)
			finalData += data
		}

		let totalStreamHash = finalData.persistentHashValue().toHexString()

		#expect(totalStreamHash == initialRenderHash)
		#expect(finalData == totalFormOutput)
	}

	/// Validates that known input renders to a deterministic, expected
	/// multipart HTTP body.
	@Test
	func testMultipartGeneration() throws {
		// Given a boundary and a known set of parts
		let boundary = "alskdglkasdjfglkajsdf"
		var multipart = MultipartForm(boundary: boundary)

		// given known multipart form input
		let arbText = "Odd input stream"
		let arbitraryData = try #require(arbText.data(using: .utf8))
		let testedText = "tested"
		let (fileURL, _) = try createTestFile()

		// When text, data, and file parts are appended
		multipart.append(testedText, named: "Text")
		multipart.append(arbitraryData, named: "File1", filename: "text.txt")
		multipart.append(fileURL, named: "File2", contentType: "text/html")

		let finalData = try multipart.render()

		// Then the rendered output matches the expected multipart body
		let expected = """
		--Boundary-alskdglkasdjfglkajsdf\r\nContent-Disposition: form-data; name=\"Text\"\r\n\r\ntested\r\n--Boundary-\
		alskdglkasdjfglkajsdf\r\nContent-Disposition: form-data; name=\"File1\"; filename=\"text.txt\"\r\nContent-Type: \
		application/octet-stream\r\n\r\nOdd input stream\r\n--Boundary-alskdglkasdjfglkajsdf\r\nContent-Disposition: \
		form-data; name=\"File2\"; filename=\"tempfile\"\r\nContent-Type: text/html\r\n\r\n<html><body>this is a \
		body</body></html>\r\n--Boundary-alskdglkasdjfglkajsdf--\r\n
		"""

		let finalString = String(data: finalData, encoding: .utf8)
		#expect(expected == finalString)
	}

	/// Validates that creating multiple independent streams from the same
	/// `MultipartForm` yields identical results, and that re-rendering also
	/// matches.
	@Test
	func testStreamCopy() throws {
		// Given the expected multipart body (shared with testMultipartGeneration)
		let expected = """
		--Boundary-alskdglkasdjfglkajsdf\r\nContent-Disposition: form-data; name=\"Text\"\r\n\r\ntested\r\n--Boundary-\
		alskdglkasdjfglkajsdf\r\nContent-Disposition: form-data; name=\"File1\"; filename=\"text.txt\"\r\nContent-Type: \
		application/octet-stream\r\n\r\nOdd input stream\r\n--Boundary-alskdglkasdjfglkajsdf\r\nContent-Disposition: \
		form-data; name=\"File2\"; filename=\"tempfile\"\r\nContent-Type: text/html\r\n\r\n<html><body>this is a \
		body</body></html>\r\n--Boundary-alskdglkasdjfglkajsdf--\r\n
		"""

		// Given a form with a known construction
		let boundary = "alskdglkasdjfglkajsdf"
		var multipart = MultipartForm(boundary: boundary)

		let arbText = "Odd input stream"
		let arbitraryData = try #require(arbText.data(using: .utf8))

		let testedText = "tested"
		multipart.append(testedText, named: "Text")
		multipart.append(arbitraryData, named: "File1", filename: "text.txt")
		let (fileURL, _) = try createTestFile()
		multipart.append(fileURL, named: "File2", contentType: "text/html")

		// When multiple streams are created from the same form
		let stream1 = try multipart.createStream()
		let stream2 = try multipart.createStream()

		// Then each stream produces the same expected output
		let stream1Data = streamToData(stream1)
		let copyString = String(data: stream1Data, encoding: .utf8)
		#expect(expected == copyString)

		let stream2Data = streamToData(stream2)
		let copyString2 = String(data: stream2Data, encoding: .utf8)
		#expect(expected == copyString2)

		// And re-rendering the original form also produces identical output
		let renderFromMultipart = try multipart.render()
		let copyString3 = String(data: renderFromMultipart, encoding: .utf8)
		#expect(expected == copyString3)
	}

	/// Reads all available bytes from an `InputStream` into a `Data` object.
	///
	/// Handles opening and closing the stream automatically. Ensures the
	/// returned data contains only the bytes actually read (truncating any
	/// oversized buffer).
	private func streamToData(_ stream: InputStream) -> Data {
		if stream.streamStatus == .notOpen {
			stream.open()
		}

		var readCount = 0
		var finalData = Data()
		while stream.hasBytesAvailable {
			let bufferSize = 20
			let testPoint = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
			let buffer = UnsafeMutableBufferPointer<UInt8>(start: testPoint, count: bufferSize)
			buffer.initialize(repeating: 0)

			readCount += stream.read(testPoint, maxLength: bufferSize)

			let data = Data(buffer: buffer)

			finalData += data
		}
		stream.close()

		finalData = finalData[0..<readCount]

		return finalData
	}

	// MARK: - common utilities

	/// Creates a temporary file with test HTML content and registers a
	/// teardown block to delete it after the test completes.
	///
	/// - Returns: A tuple containing the file URL and its contents as `Data`.
	///
	/// - Throws: Any file-system errors during creation.
	private func createTestFile() throws -> (URL, Data) {
		let testDirectory = URL.temporaryDirectory.appending(component: UUID().uuidString)
		try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
		let testFileURL = testDirectory.appendingPathComponent("tempfile")
		let testFileContents = Data("<html><body>this is a body</body></html>".utf8)
		try testFileContents.write(to: testFileURL)

		let teardownBlock: () -> Void = {
			try? FileManager.default.removeItem(at: testDirectory)
		}
		teardownBlocks.append(teardownBlock)
		return (testFileURL, testFileContents)
	}
}
