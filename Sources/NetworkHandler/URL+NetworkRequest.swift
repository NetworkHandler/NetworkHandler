import Foundation

public extension URL {
	var networkRequest: NetworkRequest {
		NetworkRequest(url: self)
	}
}
