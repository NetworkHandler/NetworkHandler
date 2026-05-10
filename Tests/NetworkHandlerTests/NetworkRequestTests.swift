import Foundation
import HTTPTypes
import NetworkHandler
import NHMacros
import PizzaMacros
import Testing
import TestSupport

struct NetworkRequestTests {
	@Test func genericEncoding() async throws {
		let testDummy = DummyType(id: 23, value: "Woop woop woop!", other: 25.3)

		let dummyURL = #URL("https://redeggproductions.com")
		let request = try dummyURL.generalRequest.with {
			try $0.encodeData(testDummy)
		}

		let data = try #require(request.payload)

		let decoded = try StandardRequest.defaultDecoder.decode(DummyType.self, from: data)
		#expect(decoded == testDummy)
	}

	/// Tests adding, setting, and getting header values
	@Test func requestHeaders() {
		let dummyURL = #URL("https://redeggproductions.com")
		let origRequest = dummyURL.generalRequest.with {
			$0.requestID = nil
		}
		var request = NetworkRequest.standard(origRequest)

		request.headers.addValue(.json, for: .contentType)
		#expect("application/json" == request.headers[.contentType])
		request.headers.setValue(.xml, for: .contentType)
		#expect("application/xml" == request.headers[.contentType])
		request.headers.setValue("Bearer 12345", for: .authorization)
		#expect(
			[
				#HTTPFieldName("Content-Type"): "application/xml",
				#HTTPFieldName("Authorization"): "Bearer 12345",
			] == request.headers)

		request.headers.setValue(nil, for: .authorization)
		#expect([#HTTPFieldName("Content-Type"): "application/xml"] == request.headers)
		#expect(request.headers[.authorization] == nil)

		request.headers.setValue("Arbitrary Value", for: #HTTPFieldName("Arbitrary-Key"))
		#expect(
			[
				#HTTPFieldName("Content-Type"): "application/xml",
				#HTTPFieldName("arbitrary-key"): "Arbitrary Value",
			] == request.headers)

		let allFields: HTTPFields = [
			#HTTPFieldName("Content-Type"): "application/xml",
			#HTTPFieldName("Authorization"): "Bearer: 12345",
			#HTTPFieldName("Arbitrary-Key"): "Arbitrary Value",
		]
		request.headers = allFields
		#expect(allFields == request.headers)

		var request2 = dummyURL.generalRequest.with {
			$0.requestID = nil
		}
		request2.headers.setValue(.audioMp4, for: .contentType)
		#expect("audio/mp4" == request2.headers[.contentType])

		request2.headers.setContentType(.bmp)
		#expect("image/bmp" == request2.headers[.contentType])

		request2.headers.setAuthorization("Bearer asdlkqf")
		#expect("Bearer asdlkqf" == request2.headers[.authorization])
	}

	@Test func requestHeadersWithDuplicates() async throws {
		let dummyURL = #URL("https://redeggproductions.com")
		var requestWithNoDup = dummyURL.generalRequest.with {
			$0.requestID = nil
		}
		requestWithNoDup.headers.addValue("sessionId=abc123", for: .cookie)

		var requestWithDup = requestWithNoDup
		requestWithDup.headers.addValue("foo=bar", for: .cookie)

		#expect(requestWithDup != requestWithNoDup)
		#expect(requestWithDup.headers.count == 2)
		#expect(requestWithNoDup.headers.count == 1)
	}

	@Test func requestHeadersWithDuplicatesAddedInDifferentOrder() async throws {
		let dummyURL = #URL("https://redeggproductions.com")
		var request1 = dummyURL.generalRequest.with {
			$0.requestID = nil
		}
		var request2 = request1

		request1.headers.addValue("sessionId=abc123", for: .cookie)
		request1.headers.addValue("foo=bar", for: .cookie)
		request2.headers.addValue("foo=bar", for: .cookie)
		request2.headers.addValue("sessionId=abc123", for: .cookie)

		#expect(request1 != request2)
		#expect(request1.headers.count == 2)
		#expect(request2.headers.count == 2)
	}

	@Test func headerKeysAndValuesEquatableWithString() {
		let contentKey = HTTPField.Name.contentType

		let nilString: String? = nil

		#expect("Content-Type" == contentKey)
		#expect(contentKey == "Content-Type")
		#expect("Content-Typo" != contentKey)
		#expect(contentKey != "Content-Typo")
		#expect(contentKey != nilString)

		let gif = HTTPField.Value.gif

		#expect("image/gif" == gif)
		#expect(gif == "image/gif")
		#expect("image/jif" != gif)
		#expect(gif != "image/jif")
		#expect(gif != nilString)
	}

	@Test func requestID() throws {
		let dummyURL = #URL("https://redeggproductions.com")

		let downRequest = dummyURL.generalRequest
		#expect(downRequest.requestID != nil)
	}
}
