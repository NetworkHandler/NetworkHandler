import Foundation
import HTTPTypes
import NetworkHandler
import NHMacros
import PizzaMacros
import Testing
import TestSupport

struct NetworkRequestTests {
	/// Verifies custom payloads are encoded, decoded, and round-trip
	/// without data loss.
	@Test func genericEncoding() async throws {
		// Given a known data object.
		let testDummy = DummyType(id: 23, value: "Woop woop woop!", other: 25.3)

		let dummyURL = #URL("https://redeggproductions.com")

		// When the payload is encoded into a request.
		let request = try dummyURL.networkRequest.with {
			try $0.encodeData(testDummy)
		}

		// Then the payload data exists and decodes back to the same object.
		let data = try #require(request.payload)

		let decoded = try NetworkRequest.defaultDecoder.decode(DummyType.self, from: data)
		#expect(decoded == testDummy)
	}

	/// Verifies header value add, set, get, and assignment behaviors.
	///
	/// Tests adding, setting, and getting header values.
	@Test func requestHeaders() {
		// Given a fresh request.
		let dummyURL = #URL("https://redeggproductions.com")
		let origRequest = dummyURL.networkRequest.with {
			$0.requestID = nil
		}
		var request = CompleteNetworkRequest.standard(origRequest)

		// When a value is first added then replaced.
		request.headers.addValue(.json, for: .contentType)

		// Then the header value is readable.
		#expect("application/json" == request.headers[.contentType])
		request.headers.setValue(.xml, for: .contentType)

		// And the new value replaces the old.
		#expect("application/xml" == request.headers[.contentType])

		// When another header value is set.
		request.headers.setValue("Bearer 12345", for: .authorization)

		// Then both headers are present with correct values.
		#expect(
			[
				#HTTPFieldName("Content-Type"): "application/xml",
				#HTTPFieldName("Authorization"): "Bearer 12345",
			] == request.headers)

		// When the authorization value is set to nil.
		request.headers.setValue(nil, for: .authorization)

		// Then it disappears from the headers collection.
		#expect([#HTTPFieldName("Content-Type"): "application/xml"] == request.headers)
		#expect(request.headers[.authorization] == nil)

		// When an arbitrary header is set.
		request.headers.setValue("Arbitrary Value", for: #HTTPFieldName("Arbitrary-Key"))

		// Then it appears in the headers.
		#expect(
			[
				#HTTPFieldName("Content-Type"): "application/xml",
				#HTTPFieldName("arbitrary-key"): "Arbitrary Value",
			] == request.headers)

		// When the entire headers are replaced with an allFields collection.
		let allFields: HTTPFields = [
			#HTTPFieldName("Content-Type"): "application/xml",
			#HTTPFieldName("Authorization"): "Bearer: 12345",
			#HTTPFieldName("Arbitrary-Key"): "Arbitrary Value",
		]
		request.headers = allFields

		// Then headers equal the assigned collection.
		#expect(allFields == request.headers)

		// When a completely new request has its contentType configured
		// and then authorization set.
		var request2 = dummyURL.networkRequest.with {
			$0.requestID = nil
		}
		request2.headers.setValue(.audioMp4, for: .contentType)

		// Then the audio/mp4 type is set.
		#expect("audio/mp4" == request2.headers[.contentType])

		request2.headers.setContentType(.bmp)

		// And the image/bmp type is set.
		#expect("image/bmp" == request2.headers[.contentType])

		request2.headers.setAuthorization("Bearer asdlkqf")

		// And the authorization is set.
		#expect("Bearer asdlkqf" == request2.headers[.authorization])
	}

	/// Verifies that adding cookies with different values produces
	/// distinct header counts, and that the resulting request differs
	/// from one with fewer cookies.
	@Test func requestHeadersWithDuplicates() async throws {
		// Given a request with one cookie.
		let dummyURL = #URL("https://redeggproductions.com")
		var requestWithNoDup = dummyURL.networkRequest.with {
			$0.requestID = nil
		}
		requestWithNoDup.headers.addValue("sessionId=abc123", for: .cookie)

		// And a duplicate request with an additional cookie.
		var requestWithDup = requestWithNoDup
		requestWithDup.headers.addValue("foo=bar", for: .cookie)

		// When both requests are compared and their header counts checked.
		// Then they are unequal and the duplicate has two cookies.
		#expect(requestWithDup != requestWithNoDup)
		#expect(requestWithDup.headers.count == 2)
		#expect(requestWithNoDup.headers.count == 1)
	}

	/// Verifies that cookie order matters — two requests with the
	/// same cookies in different order are unequal.
	@Test func requestHeadersWithDuplicatesAddedInDifferentOrder() async throws {
		// Given two identical start requests.
		let dummyURL = #URL("https://redeggproductions.com")
		var request1 = dummyURL.networkRequest.with {
			$0.requestID = nil
		}
		var request2 = request1

		// When cookies are added in order 1 then 2.
		request1.headers.addValue("sessionId=abc123", for: .cookie)
		request1.headers.addValue("foo=bar", for: .cookie)

		// And in order 2 then 1.
		request2.headers.addValue("foo=bar", for: .cookie)
		request2.headers.addValue("sessionId=abc123", for: .cookie)

		// Then both have two cookies but are unequal.
		#expect(request1 != request2)
		#expect(request1.headers.count == 2)
		#expect(request2.headers.count == 2)
	}

	/// Verifies that HTTPField.Name and HTTPField.Value enums are
	/// equatable with String types.
	@Test func headerKeysAndValuesEquatableWithString() {
		// Given a header field name and value.
		let contentKey = HTTPField.Name.contentType

		let nilString: String? = nil

		// When string comparisons and inequality checks are performed.
		// Then duplicate names compare equal and different ones do not.
		#expect("Content-Type" == contentKey)
		#expect(contentKey == "Content-Type")
		#expect("Content-Typo" != contentKey)
		#expect(contentKey != "Content-Typo")
		#expect(contentKey != nilString)

		let gif = HTTPField.Value.gif

		// When the value is compared against string literals.
		// Then the comparisons match or not match as expected.
		#expect("image/gif" == gif)
		#expect(gif == "image/gif")
		#expect("image/jif" != gif)
		#expect(gif != "image/jif")
		#expect(gif != nilString)
	}

	/// Verifies that a request created directly from a URL has a
	/// non-nil request ID.
	@Test func requestID() throws {
		let dummyURL = #URL("https://redeggproductions.com")

		// Given a URL-derived request.
		let downRequest = dummyURL.networkRequest

		// Then it has a request ID.
		#expect(downRequest.requestID != nil)
	}
}
