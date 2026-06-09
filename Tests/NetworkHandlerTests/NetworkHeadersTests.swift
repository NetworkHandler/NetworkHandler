import HTTPTypes
import NetworkHandler
import NHMacros
import Testing

struct NetworkHeadersTests {
	// swiftlint:disable identifier_name
	@Test func keys() async throws {
		let a = HTTPField.Name("Content-Type")
		let c: HTTPField.Name = .contentType
		let d = HTTPField.Name("content-type")

		#expect(a == c)
		#expect(a == d)
		#expect(a?.rawName != d?.rawName)
		#expect(c == d)
		#expect(c.rawName != d?.rawName)
		#expect(Set([a, c, d]).count == 1)

		#expect(HTTPField.Name("content-Type") == a)
		#expect(HTTPField.Name("Content-Type") == a)
		#expect(HTTPField.Name("content-Type") == d)
		#expect(HTTPField.Name("Content-Type") == d)
	}

	@Test func values() async throws {
		let a = HTTPField.Value(rawValue: "image/jpeg")
		let b: HTTPField.Value = "image/jpeg"
		let c: HTTPField.Value = .jpeg
		let d = HTTPField.Value(rawValue: "image/JPEG")

		#expect(a == b)
		#expect(a == c)
		#expect(a != d)
		#expect(b == c)
		#expect(b != d)
		#expect(c != d)
		#expect(Set([a, b, c, d]).count == 2)

		#expect("image/jpeg" == a)
		#expect("image/JPEG" != a)
		#expect("image/jpeg" != d)
		#expect("image/JPEG" == d)
	}

	// swiftlint:enable identifier_name
	@Test func multipartValue() async throws {
		let value = HTTPField.Value.multipart(boundary: "f0o")

		#expect("multipart/form-data; boundary=f0o" == value)
	}

	@Test func headersStringDict() async throws {
		let simpleSample = [
			"Content-Type": "application/json",
			"Authorization": "Bearer foobar",
			"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15", // swiftlint:disable:this line_length
		]

		let dupedSample = [
			"Content-Type": "application/json",
			"Authorization": "Bearer foobar",
			"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15", // swiftlint:disable:this line_length
			"content-type": "application/json",
		]

		let userAgentValue = try HTTPField.Value(rawValue: #require(simpleSample["User-Agent"]))

		let simpleHeaders = HTTPFields(simpleSample)
		#expect(simpleHeaders[.contentType] == "application/json")
		#expect(simpleHeaders[.authorization] == "Bearer foobar")
		#expect(simpleHeaders[.userAgent] == userAgentValue)
		#expect(simpleHeaders.count == 3)
		#expect(simpleHeaders[values: .contentType].count == 1)

		let dupedHeaders = HTTPFields(dupedSample)
		#expect(dupedHeaders[.contentType] == "application/json, application/json")
		#expect(dupedHeaders[.authorization] == "Bearer foobar")
		#expect(dupedHeaders[.userAgent] == userAgentValue)
		#expect(dupedHeaders.count == 4)
		#expect(dupedHeaders[values: .contentType].count == 2)
	}

	@Test func headersHeaderDict() async throws {
		let simpleSample: [HTTPField.Name: HTTPField.Value] = [
			#HTTPFieldName("Content-Type"): "application/json",
			#HTTPFieldName("Authorization"): "Bearer foobar",
			#HTTPFieldName("User-Agent"): "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15", // swiftlint:disable:this line_length
		]

		let userAgentValue = try #require(simpleSample[.userAgent])

		let simpleHeaders = HTTPFields(simpleSample)
		#expect(simpleHeaders[.contentType] == "application/json")
		#expect(simpleHeaders[.authorization] == "Bearer foobar")
		#expect(simpleHeaders[.userAgent] == userAgentValue)
		#expect(simpleHeaders.count == 3)
		#expect(simpleHeaders[values: .contentType].count == 1)
	}

//	@Test func headersArrayLiteral() async throws {
//		let simpleHeaders: HTTPFields = [
//			HTTPField(key: "Content-Type", value: "application/json"),
//			HTTPField(key: "Authorization", value: "Bearer foobar"),
//			HTTPField(key: "User-Agent", value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"), // swiftlint:disable:this line_length
//		]
//
//		let userAgentValue = simpleHeaders["User-Agent"]!
//
//		#expect(simpleHeaders[.contentType] == "application/json")
//		#expect(simpleHeaders[.authorization] == "Bearer foobar")
//		#expect(simpleHeaders[.userAgent] == userAgentValue)
//		#expect(simpleHeaders.count == 3)
//		#expect(simpleHeaders[values: .contentType].count == 1)
//	}

	@Test func headersDictLiteral() async throws {
		let simpleHeaders: HTTPFields = [
			#HTTPFieldName("Content-Type"): "application/json",
			#HTTPFieldName("Authorization"): "Bearer foobar",
			#HTTPFieldName("User-Agent"): "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15", // swiftlint:disable:this line_length
		]

		let userAgentValue = try #require(simpleHeaders[.userAgent])

		#expect(simpleHeaders[.contentType] == "application/json")
		#expect(simpleHeaders[.authorization] == "Bearer foobar")
		#expect(simpleHeaders[.userAgent] == userAgentValue)
		#expect(simpleHeaders.count == 3)
		#expect(simpleHeaders[values: .contentType].count == 1)
	}

	@Test func headersMutation() async throws {
		var simpleHeaders: HTTPFields = [
			#HTTPFieldName("Content-Type"): "application/json",
			#HTTPFieldName("Authorization"): "Bearer foobar",
			#HTTPFieldName("User-Agent"): "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15", // swiftlint:disable:this line_length
		]

		#expect(simpleHeaders.count == 3)
		#expect(simpleHeaders[values: .contentType].count == 1)

		simpleHeaders.append(HTTPField(name: .contentType, value: .json))
		#expect(simpleHeaders.count == 4)
		#expect(simpleHeaders[values: .contentType].count == 2)
		simpleHeaders.removeAll(where: { $0.name == .contentType })
		#expect(simpleHeaders.count == 2)
		#expect(simpleHeaders[values: .contentType].isEmpty)
	}

	@Test func headersSubscripts() async throws {
		var simpleHeaders: HTTPFields = [
			#HTTPFieldName("Content-Type"): "application/json",
			#HTTPFieldName("Authorization"): "Bearer foobar",
			#HTTPFieldName("User-Agent"): "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15", // swiftlint:disable:this line_length
		]

		#expect(simpleHeaders.count == 3)
		#expect(simpleHeaders[values: .contentType].count == 1)
		#expect(simpleHeaders[.contentType] == "application/json")

		simpleHeaders[.contentType] = "application/json2"
		#expect(simpleHeaders[.contentType] == "application/json2")

		simpleHeaders[semantic: .accept] = .xml
		#expect(simpleHeaders[.accept] == .xml)

		simpleHeaders[.accept] = nil
		#expect(simpleHeaders[.accept] == nil)

		simpleHeaders[.accept] = nil
		#expect(simpleHeaders[.accept] == nil)
	}

	@Test func headersIndicies() async throws {
		let headerFields = [
			HTTPField(name: #HTTPFieldName("Content-Type"), value: "application/json"),
			HTTPField(name: #HTTPFieldName("Authorization"), value: "Bearer foobar"),
			HTTPField(name: #HTTPFieldName("User-Agent"), value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"), // swiftlint:disable:this line_length
		]
		var simpleHeaders: HTTPFields = .init(headerFields)

		#expect(simpleHeaders[0] == .init(name: .contentType, value: .json))

		simpleHeaders[0] = HTTPField(name: .contentType, value: "application/json2")
		#expect(simpleHeaders[0] == HTTPField(name: .contentType, value: "application/json2"))

		#expect(simpleHeaders.index(after: 0) == 1)
		#expect(simpleHeaders.startIndex == 0)
		#expect(simpleHeaders.endIndex == 3)
	}
}
