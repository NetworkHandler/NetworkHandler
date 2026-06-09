import HTTPTypes

extension HTTPFields {
	public init(_ dictionary: [String: String]) {
		let elements: [HTTPField] = dictionary.compactMap { (key: String, value: String) in
			guard let name = HTTPField.Name(key) else { return nil }
			return HTTPField(name: name, value: value)
		}
		self.init(elements)
	}

	public init(_ dictionary: [HTTPField.Name: HTTPField.Value]) {
		let stringDict = dictionary.mapValues(\.rawValue)
		self.init(stringDict)
	}

	public init(_ dictionary: [HTTPField.Name: String]) {
		let elements: [HTTPField] = dictionary.compactMap { (key: HTTPField.Name, value: String) in
			HTTPField(name: key, value: value)
		}
		self.init(elements)
	}
}
