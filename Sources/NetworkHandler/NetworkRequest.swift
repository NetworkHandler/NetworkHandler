import Foundation
import SwiftPizzaSnips

@dynamicMemberLookup
public enum NetworkRequest: Sendable {
	case upload(UploadEngineRequest, payload: UploadFile)
	case general(GeneralEngineRequest)

	private var commonData: EngineRequestCommonData {
		get {
			switch self {
			case .upload(let uploadEngineRequest, _):
				uploadEngineRequest.commonData
			case .general(let generalEngineRequest):
				generalEngineRequest.commonData
			}
		}

		set {
			switch self {
			case .upload(var uploadEngineRequest, let payload):
				uploadEngineRequest.commonData = newValue
				self = .upload(uploadEngineRequest, payload: payload)
			case .general(var generalEngineRequest):
				generalEngineRequest.commonData = newValue
				self = .general(generalEngineRequest)
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
