import HTTPTypes

extension HTTPField.Name {
	/// Compares a `String` and an `HTTPField.Name` in a case insensitive manner for equality.
	public static func == (lhs: String?, rhs: Self) -> Bool {
		lhs?.lowercased() == rhs.canonicalName
	}

	/// Compares a `String` and an `HTTPField.Name` in a case insensitive manner for equality.
	public static func == (lhs: Self, rhs: String?) -> Bool {
		rhs == lhs
	}

	/// Compares a `String` and an `HTTPField.Name` in a case insensitive manner for inequality.
	public static func != (lhs: String?, rhs: Self) -> Bool {
		!(lhs == rhs)
	}

	/// Compares a `String` and an `HTTPField.Name` in a case insensitive manner for inequality.
	public static func != (lhs: Self, rhs: String?) -> Bool {
		rhs != lhs
	}
}
