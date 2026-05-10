import Foundation
import NetworkHalpers
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
		case inputStream(InputStream)
	}
}
