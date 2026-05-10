import Foundation
import SwiftPizzaSnips

@dynamicMemberLookup
public enum CompleteNetworkRequest: Sendable {
	case upload(StandardRequest, payload: UploadFile)
	case standard(StandardRequest)

	private var commonData: CommonRequestData {
		get {
			switch self {
			case .upload(let uploadEngineRequest, _):
				uploadEngineRequest.commonData
			case .standard(let standardRequest):
				standardRequest.commonData
			}
		}

		set {
			switch self {
			case .upload(var uploadEngineRequest, let payload):
				uploadEngineRequest.commonData = newValue
				self = .upload(uploadEngineRequest, payload: payload)
			case .standard(var standardRequest):
				standardRequest.commonData = newValue
				self = .standard(standardRequest)
			}
		}
	}

	public subscript<T>(dynamicMember member: WritableKeyPath<CommonRequestData, T>) -> T {
		get { commonData[keyPath: member] }
		set { commonData[keyPath: member] = newValue }
	}

	public subscript<T>(dynamicMember member: KeyPath<CommonRequestData, T>) -> T {
		commonData[keyPath: member]
	}
}

extension CompleteNetworkRequest: Hashable, Withable {}
