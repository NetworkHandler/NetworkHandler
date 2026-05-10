import Foundation

public extension URL {
	var generalRequest: NetworkRequest {
		NetworkRequest(url: self)
	}
}
