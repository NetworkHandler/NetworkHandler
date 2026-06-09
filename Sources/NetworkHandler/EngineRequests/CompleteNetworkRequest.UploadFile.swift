import Foundation
import SwiftPizzaSnips

extension CompleteNetworkRequest {
	/// Represents different ways to supply upload data:
	/// - `.localFile(URL)`: A file located on disk, referenced by a URL.
	/// - `.data(Data)`: In-memory data to upload.
	/// - `.inputStream(InputStream)`: A stream for uploading data incrementally.
	///
	/// Used in conjunction with `UploadRequest` to define upload sources dynamically.
	public enum UploadFile: Hashable, Sendable, Withable {
		case localFile(URL)
		case data(Data)
		case inputStream(any NHStreamable)
	}
}

extension CompleteNetworkRequest.UploadFile {
	static public func == (lhs: CompleteNetworkRequest.UploadFile, rhs: CompleteNetworkRequest.UploadFile) -> Bool {
		switch (lhs, rhs) {
		case (.localFile(let lFile), .localFile(let rFile)):
			return lFile == rFile
		case (.data(let lData), .data(let rData)):
			return lData == rData
		case (.inputStream(let lStream), .inputStream(let rStream)):
			guard type(of: lStream) == type(of: rStream) else { return false }
			return lStream.hashValue == rStream.hashValue
		default:
			return false
		}
	}

	public func hash(into hasher: inout Hasher) {
		switch self {
		case .localFile(let url):
			hasher.combine(url)
		case .data(let data):
			hasher.combine(data)
		case .inputStream(let stream):
			hasher.combine("\(type(of: stream))")
			hasher.combine(stream.hashValue)
		}
	}
}
