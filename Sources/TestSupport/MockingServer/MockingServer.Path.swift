@available(macOS 15.0.0, iOS 18.0.0, tvOS 18.0.0, *)
extension MockingServer {
	public struct Path:
		RawRepresentable,
		Sendable,
		Hashable,
		ExpressibleByArrayLiteral,
		ExpressibleByStringLiteral,
		ExpressibleByStringInterpolation {

		public var rawValue: [String]

		public init(rawValue: [String]) {
			self.rawValue = rawValue
		}

		public init(arrayLiteral elements: String...) {
			self.init(rawValue: elements)
		}

		public init(stringLiteral value: String) {
			let path = value.split(separator: "/").map(String.init)
			self.init(rawValue: path)
		}
	}
}
