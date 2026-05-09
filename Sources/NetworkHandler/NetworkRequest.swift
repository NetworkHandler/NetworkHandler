import Foundation
import SwiftPizzaSnips

@dynamicMemberLookup
public enum NetworkRequest: Sendable {
	case upload(UploadRequest, payload: UploadFile)
	case general(StandardRequest)

	private var commonData: EngineRequestCommonData {
		get {
			switch self {
			case .upload(let uploadEngineRequest, _):
				uploadEngineRequest.commonData
			case .general(let standardRequest):
				standardRequest.commonData
			}
		}

		set {
			switch self {
			case .upload(var uploadEngineRequest, let payload):
				uploadEngineRequest.commonData = newValue
				self = .upload(uploadEngineRequest, payload: payload)
			case .general(var standardRequest):
				standardRequest.commonData = newValue
				self = .general(standardRequest)
			}
		}
	}

	public subscript<T>(dynamicMember member: WritableKeyPath<EngineRequestCommonData, T>) -> T {
		get { commonData[keyPath: member] }
		set { commonData[keyPath: member] = newValue }
	}

	public subscript<T>(dynamicMember member: KeyPath<EngineRequestCommonData, T>) -> T {
		commonData[keyPath: member]
	}
}

extension NetworkRequest: Hashable, Withable {}
