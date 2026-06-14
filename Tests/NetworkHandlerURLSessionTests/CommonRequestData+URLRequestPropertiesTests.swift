import Foundation
import NetworkHandler
import NetworkHandlerURLSessionEngine
import PizzaMacros
import Testing
import TestSupport

struct CommonRequestData_URLRequestProperties {
	let testURL = #URL("https://s3.wasabisys.com/network-handler-tests/images/lighthouse.jpg")

	@Test func cachePolicy() async throws {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.cachePolicy == plainURLRequest.cachePolicy)

		request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
		#expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
		#expect(request.urlRequest(forUpload: false).cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
		#expect(request.urlRequest(forUpload: true).cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
		#expect(request.cachePolicy != plainURLRequest.cachePolicy)
	}

	@Test func mainDocumentURL() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.mainDocumentURL == plainURLRequest.mainDocumentURL)

		let fooURL = testURL.appending(component: "floooblarrr")
		request.mainDocumentURL = fooURL
		#expect(request.mainDocumentURL == fooURL)
		#expect(request.mainDocumentURL != plainURLRequest.mainDocumentURL)
		#expect(request.urlRequest(forUpload: true).mainDocumentURL == fooURL)
		#expect(request.urlRequest(forUpload: false).mainDocumentURL == fooURL)
	}

	@Test func httpShouldHandleCookies() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.httpShouldHandleCookies == plainURLRequest.httpShouldHandleCookies)

		request.httpShouldHandleCookies = false
		#expect(request.httpShouldHandleCookies == false)
		#expect(request.urlRequest(forUpload: false).httpShouldHandleCookies == false)
		#expect(request.urlRequest(forUpload: true).httpShouldHandleCookies == false)
		#expect(request.httpShouldHandleCookies != plainURLRequest.httpShouldHandleCookies)
	}

	@Test func httpShouldUsePipelining() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.httpShouldUsePipelining == plainURLRequest.httpShouldUsePipelining)

		request.httpShouldUsePipelining = true
		#expect(request.httpShouldUsePipelining == true)
		#expect(request.urlRequest(forUpload: false).httpShouldUsePipelining == true)
		#expect(request.urlRequest(forUpload: true).httpShouldUsePipelining == true)
		#expect(request.httpShouldUsePipelining != plainURLRequest.httpShouldUsePipelining)
	}

	@Test func allowsCellularAccess() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.allowsCellularAccess == plainURLRequest.allowsCellularAccess)

		request.allowsCellularAccess = false
		#expect(request.allowsCellularAccess == false)
		#expect(request.urlRequest(forUpload: false).allowsCellularAccess == false)
		#expect(request.urlRequest(forUpload: true).allowsCellularAccess == false)
		#expect(request.allowsCellularAccess != plainURLRequest.allowsCellularAccess)
	}

	@Test func allowsConstrainedNetworkAccess() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.allowsConstrainedNetworkAccess == plainURLRequest.allowsConstrainedNetworkAccess)

		request.allowsConstrainedNetworkAccess = false
		#expect(request.allowsConstrainedNetworkAccess == false)
		#expect(request.urlRequest(forUpload: false).allowsConstrainedNetworkAccess == false)
		#expect(request.urlRequest(forUpload: true).allowsConstrainedNetworkAccess == false)
		#expect(request.allowsConstrainedNetworkAccess != plainURLRequest.allowsConstrainedNetworkAccess)
	}

	@Test func allowsExpensiveNetworkAccess() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.allowsExpensiveNetworkAccess == plainURLRequest.allowsExpensiveNetworkAccess)

		request.allowsExpensiveNetworkAccess = false
		#expect(request.allowsExpensiveNetworkAccess == false)
		#expect(request.urlRequest(forUpload: false).allowsExpensiveNetworkAccess == false)
		#expect(request.urlRequest(forUpload: true).allowsExpensiveNetworkAccess == false)
		#expect(request.allowsExpensiveNetworkAccess != plainURLRequest.allowsExpensiveNetworkAccess)
	}

	@Test func networkServiceType() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.networkServiceType == plainURLRequest.networkServiceType)

		request.networkServiceType = .video
		#expect(request.networkServiceType == .video)
		#expect(request.urlRequest(forUpload: false).networkServiceType == .video)
		#expect(request.urlRequest(forUpload: true).networkServiceType == .video)
		#expect(request.networkServiceType != plainURLRequest.networkServiceType)
	}

	@Test func attribution() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.attribution == plainURLRequest.attribution)

		request.attribution = .user
		#expect(request.attribution == .user)
		#expect(request.urlRequest(forUpload: false).attribution == .user)
		#expect(request.urlRequest(forUpload: true).attribution == .user)
		#expect(request.attribution != plainURLRequest.attribution)
	}

	@available(iOS 18.0, macOS 15.0, *)
	@Test func allowsPersistentDNS() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.allowsPersistentDNS == plainURLRequest.allowsPersistentDNS)

		request.allowsPersistentDNS = true
		#expect(request.allowsPersistentDNS == true)
		#expect(request.urlRequest(forUpload: false).allowsPersistentDNS == true)
		#expect(request.urlRequest(forUpload: true).allowsPersistentDNS == true)
		#expect(request.allowsPersistentDNS != plainURLRequest.allowsPersistentDNS)
	}

	@Test func assumesHTTP3Capable() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.assumesHTTP3Capable == plainURLRequest.assumesHTTP3Capable)

		request.assumesHTTP3Capable = true
		#expect(request.assumesHTTP3Capable == true)
		#expect(request.urlRequest(forUpload: false).assumesHTTP3Capable == true)
		#expect(request.urlRequest(forUpload: true).assumesHTTP3Capable == true)
		#expect(request.assumesHTTP3Capable != plainURLRequest.assumesHTTP3Capable)
	}

	@available(iOS 16.1, *)
	@Test func requiresDNSSECValidation() {
		let url = testURL
		var request = url.generalRequest

		let plainURLRequest = URLRequest(url: url)
		#expect(request.requiresDNSSECValidation == plainURLRequest.requiresDNSSECValidation)

		request.requiresDNSSECValidation = true
		#expect(request.requiresDNSSECValidation == true)
		#expect(request.urlRequest(forUpload: false).requiresDNSSECValidation == true)
		#expect(request.urlRequest(forUpload: true).requiresDNSSECValidation == true)
		#expect(request.requiresDNSSECValidation != plainURLRequest.requiresDNSSECValidation)
	}
}
