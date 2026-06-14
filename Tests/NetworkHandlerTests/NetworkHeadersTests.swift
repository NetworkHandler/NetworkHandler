import HTTPTypes
import NetworkHandler
import NHMacros
import Testing

struct NetworkHeadersTests {
	// swiftlint:disable identifier_name
	@Test func keys() async throws {
		// Given three HTTPField.Name values that represent the same logical header:
		// - 'a' created via init with capital casing,
		// - 'c' created via the .contentType semantic property,
		// - 'd' created via init with lowercase casing.
		let a = HTTPField.Name("Content-Type")
		let c: HTTPField.Name = .contentType
		let d = HTTPField.Name("content-type")

		// Then they should all compare equal as values.
		#expect(a == c)
		#expect(a == d)

		// But their raw names should differ when casing differs.
		#expect(a?.rawName != d?.rawName)
		#expect(c == d)
		#expect(c.rawName != d?.rawName)

		// And all three should be deduplicated to a single unique element in a Set.
		#expect(Set([a, c, d]).count == 1)

		// When comparing against differently-cased constructor calls,
		// they should all resolve to the same name.
		#expect(HTTPField.Name("content-Type") == a)
		#expect(HTTPField.Name("Content-Type") == a)
		#expect(HTTPField.Name("content-Type") == d)
		#expect(HTTPField.Name("Content-Type") == d)
	}

	@Test func values() async throws {
		// Given four HTTPField.Value values representing image/jpeg content:
		// - 'a' created via rawValue with lowercase jpeg,
		// - 'b' created via string literal with lowercase jpeg,
		// - 'c' created via the .jpeg semantic property,
		// - 'd' created via rawValue with uppercase JPEG.
		let a = HTTPField.Value(rawValue: "image/jpeg")
		let b: HTTPField.Value = "image/jpeg"
		let c: HTTPField.Value = .jpeg
		let d = HTTPField.Value(rawValue: "image/JPEG")

		// Then a, b, and c should all compare equal.
		#expect(a == b)
		#expect(a == c)
		#expect(b == c)

		// And d, despite sharing the same MediaType, should differ from a, b, c.
		#expect(a != d)
		#expect(b != d)
		#expect(c != d)

		// And the Set should contain exactly two unique values (jpeg vs JPEG).
		#expect(Set([a, b, c, d]).count == 2)

		// When comparing string literals directly against the values,
		// same-case strings should match and different-case strings should not.
		#expect("image/jpeg" == a)
		#expect("image/jpeg" != d)

		#expect("image/JPEG" != a)
		#expect("image/JPEG" == d)
	}

	// swiftlint:enable identifier_name
	@Test func multipartValue() async throws {
		// Given an HTTPField.Value created as multipart with a boundary of "f0o".
		let value = HTTPField.Value.multipart(boundary: "f0o")

		// Then its string representation should be "multipart/form-data; boundary=f0o".
		#expect("multipart/form-data; boundary=f0o" == value)
	}

	@Test func headersStringDict() async throws {
		// Given a simple dictionary with three headers.
		let simpleSample = [
			"Content-Type": "application/json",
			"Authorization": "Bearer foobar",
			"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15", // swiftlint:disable:this line_length
		]

		// And a dictionary with duplicate Content-Type keys.
		let dupedSample = [
			"Content-Type": "application/json",
			"Authorization": "Bearer foobar",
			"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15", // swiftlint:disable:this line_length
			"content-type": "application/json",
		]

		// And the User-Agent value extracted from the simple sample.
		let userAgentValue = try HTTPField.Value(rawValue: #require(simpleSample["User-Agent"]))

		// When creating HTTPFields from the simple dictionary.
		let simpleHeaders = HTTPFields(simpleSample)

		// Then each header should have the correct single value.
		#expect(simpleHeaders[.contentType] == "application/json")
		#expect(simpleHeaders[.authorization] == "Bearer foobar")
		#expect(simpleHeaders[.userAgent] == userAgentValue)
		#expect(simpleHeaders.count == 3)
		#expect(simpleHeaders[values: .contentType].count == 1)

		// When creating HTTPFields from the duplicated dictionary.
		let dupedHeaders = HTTPFields(dupedSample)

		// Then duplicates should be combined into a comma-separated list.
		#expect(dupedHeaders[.contentType] == "application/json, application/json")
		#expect(dupedHeaders[.authorization] == "Bearer foobar")
		#expect(dupedHeaders[.userAgent] == userAgentValue)
		#expect(dupedHeaders.count == 4)
		#expect(dupedHeaders[values: .contentType].count == 2)
	}

	@Test func headersHeaderDict() async throws {
		// Given a dictionary using #HTTPFieldName keys with three headers.
		let simpleSample: [HTTPField.Name: HTTPField.Value] = [
			#HTTPFieldName("Content-Type"): "application/json",
			#HTTPFieldName("Authorization"): "Bearer foobar",
			#HTTPFieldName("User-Agent"): "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15", // swiftlint:disable:this line_length
		]

		// And the User-Agent value extracted from the sample.
		let userAgentValue = try #require(simpleSample[.userAgent])

		// When creating HTTPFields from the header dictionary.
		let simpleHeaders = HTTPFields(simpleSample)

		// Then each header should have the correct single value.
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
		// Given a HTTPFields collection created via dictionary literal with three headers.
		let simpleHeaders: HTTPFields = [
			#HTTPFieldName("Content-Type"): "application/json",
			#HTTPFieldName("Authorization"): "Bearer foobar",
			#HTTPFieldName("User-Agent"): "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15", // swiftlint:disable:this line_length
		]

		// And the User-Agent value extracted from the collection.
		let userAgentValue = try #require(simpleHeaders[.userAgent])

		// Then each header should have the correct single value.
		#expect(simpleHeaders[.contentType] == "application/json")
		#expect(simpleHeaders[.authorization] == "Bearer foobar")
		#expect(simpleHeaders[.userAgent] == userAgentValue)
		#expect(simpleHeaders.count == 3)
		#expect(simpleHeaders[values: .contentType].count == 1)
	}

	@Test func headersMutation() async throws {
		// Given a HTTPFields collection initialized with three headers.
		var simpleHeaders: HTTPFields = [
			#HTTPFieldName("Content-Type"): "application/json",
			#HTTPFieldName("Authorization"): "Bearer foobar",
			#HTTPFieldName("User-Agent"): "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15", // swiftlint:disable:this line_length
		]

		// Then it should start with 3 total entries and 1 Content-Type.
		#expect(simpleHeaders.count == 3)
		#expect(simpleHeaders[values: .contentType].count == 1)

		// When appending a duplicate Content-Type header.
		simpleHeaders.append(HTTPField(name: .contentType, value: .json))

		// Then count should increase to 4 and Content-Type values to 2.
		#expect(simpleHeaders.count == 4)
		#expect(simpleHeaders[values: .contentType].count == 2)

		// When removing all Content-Type entries.
		simpleHeaders.removeAll(where: { $0.name == .contentType })

		// Then count should decrease to 2 and Content-Type values should be empty.
		#expect(simpleHeaders.count == 2)
		#expect(simpleHeaders[values: .contentType].isEmpty)
	}

	@Test func headersSubscripts() async throws {
		// Given a mutable HTTPFields collection initialized with three headers.
		var simpleHeaders: HTTPFields = [
			#HTTPFieldName("Content-Type"): "application/json",
			#HTTPFieldName("Authorization"): "Bearer foobar",
			#HTTPFieldName("User-Agent"): "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15", // swiftlint:disable:this line_length
		]

		// Then it should start with 3 total entries, 1 Content-Type, and correct content.
		#expect(simpleHeaders.count == 3)
		#expect(simpleHeaders[values: .contentType].count == 1)
		#expect(simpleHeaders[.contentType] == "application/json")

		// When writing a new value to the Content-Type subscript.
		simpleHeaders[.contentType] = "application/json2"

		// Then the updated value should be retrievable.
		#expect(simpleHeaders[.contentType] == "application/json2")

		// When writing an XML value to the semantic .accept subscript.
		simpleHeaders[semantic: .accept] = .xml

		// Then the .accept value should be .xml.
		#expect(simpleHeaders[.accept] == .xml)

		// When setting the .accept subscript to nil.
		simpleHeaders[.accept] = nil

		// Then .accept should return nil.
		#expect(simpleHeaders[.accept] == nil)

		// When setting .accept to nil again (idempotent).
		simpleHeaders[.accept] = nil

		// Then .accept should still be nil.
		#expect(simpleHeaders[.accept] == nil)
	}

	@Test func headersIndicies() async throws {
		// Given an array of three HTTPField entries.
		let headerFields = [
			HTTPField(name: #HTTPFieldName("Content-Type"), value: "application/json"),
			HTTPField(name: #HTTPFieldName("Authorization"), value: "Bearer foobar"),
			HTTPField(name: #HTTPFieldName("User-Agent"), value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"), // swiftlint:disable:this line_length
		]
		// And a HTTPFields collection initialized from that array.
		var simpleHeaders: HTTPFields = .init(headerFields)

		// Then the first element should be Content-Type with application/json.
		#expect(simpleHeaders[0] == .init(name: .contentType, value: .json))

		// When replacing the first element with a new Content-Type header.
		simpleHeaders[0] = HTTPField(name: .contentType, value: "application/json2")

		// Then the first element should be the updated value.
		#expect(simpleHeaders[0] == HTTPField(name: .contentType, value: "application/json2"))

		// And the indices should be correct.
		#expect(simpleHeaders.index(after: 0) == 1)
		#expect(simpleHeaders.startIndex == 0)
		#expect(simpleHeaders.endIndex == 3)
	}
}
