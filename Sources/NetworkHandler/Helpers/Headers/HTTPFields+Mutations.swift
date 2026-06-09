//
//  HTTPFields+Mutations.swift
//  NetworkHandler
//
//  Created by Michael Redig on 5/3/26.
//

import HTTPTypes

extension HTTPFields {
	public mutating func addValue(_ value: HTTPField.Value, for name: HTTPField.Name) {
		self.append(HTTPField(name: name, value: value))
	}

	public mutating func setValue(_ value: HTTPField.Value?, for name: HTTPField.Name) {
		self[name] = value?.rawValue
	}

	public mutating func setContentType(_ value: HTTPField.Value?) {
		setValue(value, for: .contentType)
	}

	public mutating func setAuthorization(_ value: HTTPField.Value?) {
		setValue(value, for: .authorization)
	}
}
