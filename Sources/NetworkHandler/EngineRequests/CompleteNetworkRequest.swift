import Foundation
import SwiftPizzaSnips

/// A complete HTTP request that wraps ``NetworkRequest`` and optionally includes
/// an upload payload.
///
/// Use `.standard` for typical HTTP interactions (fetching JSON, sending POST/PUT body
/// data) and `.upload` when you need to upload files or large payloads.
///
/// - Note: Use the ``NetworkRequest`` initializer directly from ``NetworkHandler`` for
///   requests that don't require case-level disambiguation; ``NetworkRequest`` is a
///   low-stakes common denominator that carries the core HTTP method, headers, and URL.
@dynamicMemberLookup
public enum CompleteNetworkRequest: Sendable {
	/// A standard HTTP request with no file upload.
	///
	/// Suitable for fetching resources, sending JSON payloads, or performing basic CRUD
	/// operations via the engine.
	case standard(NetworkRequest)

	/// An HTTP request for large file uploads, streaming, or progressive data transfer.
	///
	/// Use this case when you need upload progress tracking, file disk uploads, or streamed
	/// payloads rather than pre-encoded data.
	///
	/// - Parameters:
	///   - request: The underlying ``NetworkRequest`` carrying HTTP method, headers, and URL.
	///   - payload: The file or data to upload via the engine.
	case upload(NetworkRequest, payload: UploadFile)

	private var commonData: NetworkRequest {
		get {
			switch self {
			case .upload(let uploadEngineRequest, _):
				uploadEngineRequest
			case .standard(let standardRequest):
				standardRequest
			}
		}

		set {
			switch self {
			case .upload(var uploadEngineRequest, let payload):
				uploadEngineRequest = newValue
				self = .upload(uploadEngineRequest, payload: payload)
			case .standard(var standardRequest):
				standardRequest = newValue
				self = .standard(standardRequest)
			}
		}
	}

	public subscript<T>(dynamicMember member: WritableKeyPath<NetworkRequest, T>) -> T {
		get { commonData[keyPath: member] }
		set { commonData[keyPath: member] = newValue }
	}

	public subscript<T>(dynamicMember member: KeyPath<NetworkRequest, T>) -> T {
		commonData[keyPath: member]
	}
}

extension CompleteNetworkRequest: Hashable, Withable {}
