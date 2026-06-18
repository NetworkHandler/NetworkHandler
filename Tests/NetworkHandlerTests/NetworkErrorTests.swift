import Foundation
import NetworkHandler
import PizzaMacros
import Testing
@testable import TestSupport

struct NetworkErrorTests {
	static let simpleURL = #URL("http://he@ho.hum")

	/// Verifies that NetworkError cases are equatable — duplicates match
	/// but rotations do not.
	///
	/// Tests Equatability on NetworkError cases.
	@Test func errorEquatable() {
		// Given identical copies of all error cases.
		let allErrors = NetworkError.allErrorCases()
		let dupErrors = NetworkError.allErrorCases()

		// And a rotated copy.
		var rotErrors = NetworkError.allErrorCases()
		let rot1 = rotErrors.remove(at: 0)
		rotErrors.append(rot1)

		// When each case is compared index-by-index.
		for (index, error) in allErrors.enumerated() {
			// Then duplicates match.
			#expect(error == dupErrors[index])

			// And the rotated version does not.
			#expect(error != rotErrors[index])
		}
	}

	/// Verifies that each NetworkError produces a meaningful
	/// debugDescription string based on its payload.
	@available(iOS 11.0, macOS 13.0, *)
	@Test func errorOutput() throws {
		// Given a test object and a JSON encoder with sorted keys.
		let testDummy = DummyType(id: 23, value: "Woop woop woop!", other: 25.3)
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		let testData = try encoder.encode(testDummy)

		// When an unspecified error has a reason.
		var error = NetworkError.unspecifiedError(reason: "Foo bar")
		let testString = try #require(String(data: testData, encoding: .utf8))
		let error1Str = "NetworkError: Unspecified Error: Foo bar"

		// Then the debugDescription formats the reason.
		#expect(error1Str == error.debugDescription)

		// When it becomes an HTTP unexpected status code.
		error = .httpUnexpectedStatusCode(
			code: 401,
			originalRequest: .standard(Self.simpleURL.networkRequest).with { $0.requestID = nil },
			data: testData)
		let error2Str = "NetworkError: Bad Response Code (401) for request: (GET): http://he@ho.hum with data: \(testString)"

		// Then the debugDescription includes the code, request, and data.
		#expect(error2Str == error.debugDescription)

		// When reason is nil.
		error = NetworkError.unspecifiedError(reason: nil)
		let error3Str = "NetworkError: Unspecified Error: nil value"

		// Then "nil value" appears as the reason.
		#expect(error3Str == error.debugDescription)
	}
}

extension NetworkError {
	/// Creates a collection of Network errors covering most of the spectrum.
	static func allErrorCases() -> [NetworkError] {
		let dummyError = NSError(domain: "com.redeggproductions.NetworkHandler", code: -1, userInfo: nil)
		let originalRequest = CompleteNetworkRequest.standard(NetworkErrorTests.simpleURL.networkRequest).with {
			$0.requestID = nil
		}
		let allErrorCases: [NetworkError] = [
			.dataCodingError(specifically: dummyError, sourceData: nil),
			.httpUnexpectedStatusCode(code: 404, originalRequest: originalRequest, data: nil),
			.unspecifiedError(reason: "Who knows what the error might be?!"),
			.unspecifiedError(reason: nil),
			.requestTimedOut,
			.otherError(error: dummyError),
			.requestCancelled,
			.noData,
		]
		return allErrorCases
	}
}
