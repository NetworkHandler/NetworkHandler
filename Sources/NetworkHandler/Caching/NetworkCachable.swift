import Foundation
import HTTPTypes

public protocol NetworkCachable: AnyObject {
	var name: String { get set }

	var countLimit: Int { get set }
	var totalCostLimit: Int { get set }

	func cachedItem(for key: NetworkCacheKey) -> NetworkCacheStore?
	func setCachedItem(_ newValue: NetworkCacheStore?, for key: NetworkCacheKey)
}

public enum NetworkCacheKey: Sendable, Hashable, RawRepresentable {
	private static let separator = "\0.\0"

	public var url: URL? {
		guard case .urlMethod(let url, _) = self else {
			return nil
		}
		return url
	}
	public var method: HTTPRequest.Method? {
		guard case .urlMethod(_, let method) = self else {
			return nil
		}
		return method
	}

	public var rawValue: String {
		switch self {
		case .rawString(let string):
			string
		case .urlMethod(let url, let method):
			"\(method.rawValue)\(Self.separator)\(url.absoluteString)"
		}
	}

	case rawString(String)
	case urlMethod(URL, HTTPRequest.Method)

	public init(rawValue: String) {
		let split = rawValue.split(separator: Self.separator).map(String.init)
		if
			split.count == 2,
			let method = split.first.flatMap(HTTPRequest.Method.init(rawValue:)),
			let url = split.last.flatMap(URL.init(string:)) {

			self = .urlMethod(url, method)
		} else {
			self = .rawString(rawValue)
		}
	}

}

public struct NetworkCacheStore: Sendable, Hashable, Codable {
	public let response: EngineResponseHeader
	public let data: Data
	public var cost: Int { data.count }
}
