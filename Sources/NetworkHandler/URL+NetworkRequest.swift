import Foundation

public extension URL {
	var generalRequest: StandardRequest {
		StandardRequest(url: self)
	}
}
