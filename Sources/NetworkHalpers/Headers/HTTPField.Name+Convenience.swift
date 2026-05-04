import HTTPTypes

extension HTTPField.Name {
	public static func == (lhs: String?, rhs: Self) -> Bool {
		lhs?.lowercased() == rhs.canonicalName
	}

	public static func == (lhs: Self, rhs: String?) -> Bool {
		rhs == lhs
	}

	public static func != (lhs: String?, rhs: Self) -> Bool {
		!(lhs == rhs)
	}

	public static func != (lhs: Self, rhs: String?) -> Bool {
		rhs != lhs
	}
}
