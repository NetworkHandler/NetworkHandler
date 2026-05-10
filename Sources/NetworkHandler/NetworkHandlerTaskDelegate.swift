import Foundation

@NHActor
public protocol NetworkHandlerTaskDelegate: AnyObject, Sendable {
	/// Called when the engine modifies the request in some way. This can happen, for example, on
	/// an upload when the `ContentLength` header gets set.
	func requestModified(from oldVersion: CompleteNetworkRequest, to newVersion: CompleteNetworkRequest)
	/// Only called on uploads
	func transferDidStart(for request: CompleteNetworkRequest)
	/// Only called on uploads
	func sentData(for request: CompleteNetworkRequest, totalByteCountSent: Int, totalExpectedToSend: Int?)
	/// Only called on uploads
	func sendingDataDidFinish(for request: CompleteNetworkRequest)
	func responseHeaderRetrieved(for request: CompleteNetworkRequest, header: EngineResponseHeader)
	/// Only called on downloads
	func responseBodyReceived(for request: CompleteNetworkRequest, bytes: Data)
	/// Only called on downloads
	func responseBodyReceived(for request: CompleteNetworkRequest, byteCount: Int, totalExpectedToReceive: Int?)
	func requestFinished(withError error: Error?)
}
