import HTTPTypes

extension HTTPFields {
	/// Creates a new `HTTPFields` instance from a dictionary with string keys and values.
	///
	/// Keys that don't represent valid HTTP field names are skipped.
	public init(_ dictionary: [String: String]) {
		let elements: [HTTPField] = dictionary.compactMap { (key: String, value: String) in
			guard let name = HTTPField.Name(key) else { return nil }
			return HTTPField(name: name, value: value)
		}
		self.init(elements)
	}

	/// Creates a new `HTTPFields` instance from a dictionary mapping typed HTTP field names to
	/// typed HTTP field values.
	public init(_ dictionary: [HTTPField.Name: HTTPField.Value]) {
		let stringDict = dictionary.mapValues(\.rawValue)
		self.init(stringDict)
	}

	/// Creates a new `HTTPFields` instance from a dictionary mapping typed HTTP field names to
	/// string values.
	public init(_ dictionary: [HTTPField.Name: String]) {
		let elements: [HTTPField] = dictionary.compactMap { (key: HTTPField.Name, value: String) in
			HTTPField(name: key, value: value)
		}
		self.init(elements)
	}
}
