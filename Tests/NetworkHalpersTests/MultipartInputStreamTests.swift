import NetworkHalpers
import TestSupport
import XCTest

class MultipartInputStreamTests: XCTestCase {
	func testMultipartGeneration() throws {
		let boundary = "alskdglkasdjfglkajsdf"
		var multipart = MultipartForm(boundary: boundary)

		// given known multipart form input
		let arbText = "Odd input stream"
		let arbitraryData = try XCTUnwrap(arbText.data(using: .utf8))
		let testedText = "tested"
		let (fileURL, _) = try createTestFile()

		// when constructing a multipart form
		multipart.append(testedText, named: "Text")
		multipart.append(arbitraryData, named: "File1", filename: "text.txt")
		multipart.append(fileURL, named: "File2", contentType: "text/html")

		let finalData = try multipart.render()

		// then it consistently renders the same, well-formed output
		let expected = """
		--Boundary-alskdglkasdjfglkajsdf\r\nContent-Disposition: form-data; name=\"Text\"\r\n\r\ntested\r\n--Boundary-\
		alskdglkasdjfglkajsdf\r\nContent-Disposition: form-data; name=\"File1\"; filename=\"text.txt\"\r\nContent-Type: \
		application/octet-stream\r\n\r\nOdd input stream\r\n--Boundary-alskdglkasdjfglkajsdf\r\nContent-Disposition: \
		form-data; name=\"File2\"; filename=\"tempfile\"\r\nContent-Type: text/html\r\n\r\n<html><body>this is a \
		body</body></html>\r\n--Boundary-alskdglkasdjfglkajsdf--\r\n
		"""

		let finalString = String(data: finalData, encoding: .utf8)
		XCTAssertEqual(expected, finalString)
	}

	func testStreamCopy() throws {
		let expected = """
		--Boundary-alskdglkasdjfglkajsdf\r\nContent-Disposition: form-data; name=\"Text\"\r\n\r\ntested\r\n--Boundary-\
		alskdglkasdjfglkajsdf\r\nContent-Disposition: form-data; name=\"File1\"; filename=\"text.txt\"\r\nContent-Type: \
		application/octet-stream\r\n\r\nOdd input stream\r\n--Boundary-alskdglkasdjfglkajsdf\r\nContent-Disposition: \
		form-data; name=\"File2\"; filename=\"tempfile\"\r\nContent-Type: text/html\r\n\r\n<html><body>this is a \
		body</body></html>\r\n--Boundary-alskdglkasdjfglkajsdf--\r\n
		"""

		// given a form with a known construction
		let boundary = "alskdglkasdjfglkajsdf"
		var multipart = MultipartForm(boundary: boundary)

		let arbText = "Odd input stream"
		let arbitraryData = try XCTUnwrap(arbText.data(using: .utf8))

		let testedText = "tested"
		multipart.append(testedText, named: "Text")
		multipart.append(arbitraryData, named: "File1", filename: "text.txt")
		let (fileURL, _) = try createTestFile()
		multipart.append(fileURL, named: "File2", contentType: "text/html")

		// when creating multiple copies as Stream
		let stream1 = multipart.stream
		let stream2 = multipart.stream

		// then each output is consistent and identical
		let stream1Data = streamToData(stream1)
		let copyString = String(data: stream1Data, encoding: .utf8)
		XCTAssertEqual(expected, copyString)

		let stream2Data = streamToData(stream2)
		let copyString2 = String(data: stream2Data, encoding: .utf8)
		XCTAssertEqual(expected, copyString2)

		let renderFromMultipart = try multipart.render()
		let copyString3 = String(data: renderFromMultipart, encoding: .utf8)
		XCTAssertEqual(expected, copyString3)
	}

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
	private func createTestFile() throws -> (URL, Data) {
		let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("tempfile")
		let testFileContents = Data("<html><body>this is a body</body></html>".utf8)
		try testFileContents.write(to: testFileURL)
		addTeardownBlock {
			try? FileManager.default.removeItem(at: testFileURL)
		}
		return (testFileURL, testFileContents)
	}
}
