import Foundation
import HTTPTypes
import UniformTypeIdentifiers

public struct MultipartForm: Sendable, Hashable {
	public var boundary: String { "Boundary-\(boundaryRoot)" }
	private let boundaryRoot: String

	public var multipartContentTypeHeaderValue: HTTPField.Value {
		"multipart/form-data; boundary=\(boundary)"
	}

	public var parts: [Part] = []

	public var count: Int { parts.reduce(0, { $0 + $1.totalCount }) + footer.count }

	public var footer: Data { Data(footerString.utf8) }
	private var footerString: String { "--\(boundary)--\r\n" }

	public init(boundary: String) {
		self.boundaryRoot = boundary
	}

	public mutating func append(_ part: Part) {
		parts.append(part)
	}

	public mutating func append(_ data: Data, named name: String, filename: String? = nil, contentType: String? = nil) {
		let part = Part(
			boundary: boundary,
			name: name,
			contentType: contentType ?? "application/octet-stream",
			filename: filename,
			content: .data(data))
		append(part)
	}

	public mutating func append(
		_ string: String,
		named name: String,
		filename: String? = nil,
		contentType: String? = nil
	) {
		let part = Part(
			boundary: boundary,
			name: name,
			contentType: contentType,
			filename: filename,
			content: .string(string))
		append(part)
	}

	public mutating func append(_ file: URL, named name: String, filename: String? = nil, contentType: String? = nil) {
		guard file.isFileURL else { fatalError("Must be a file URL") }
		let filename = filename ?? file.lastPathComponent
		let pathExtension = URL(filePath: "/\(filename)").pathExtension
		let mime = UTType(filenameExtension: pathExtension)?.preferredMIMEType
		let part = Part.init(
			boundary: boundary,
			name: name,
			contentType: contentType ?? mime,
			filename: filename,
			content: .file(file))

		append(part)
	}

	public func render() throws -> Data {
		var accum = Data()
		for part in parts {
			let partData = try part.data(at: 0, count: part.totalCount)
			accum.append(partData)
		}
		accum.append(footer)
		return accum
	}

	public func data(at offset: Int, count: Int) throws -> Data {
		guard count > 0 else { return Data() }

		var accumulator = Data()

		var lastPartEnd = 0
		for part in parts {
			guard
				let partRange = globalRange(for: part)
			else { continue }
			lastPartEnd = partRange.upperBound
			guard partRange.contains(offset) else { continue }

			let normalizedOffset = Self.normalizeGlobalOffset(offset, toGlobalChunkStart: partRange.lowerBound)

			try accumulator.append(part.data(at: normalizedOffset, count: count))
			let remaining = count - accumulator.count
			guard remaining > 0 else {
				return accumulator
			}

			try accumulator.append(data(at: partRange.upperBound, count: remaining))

			return accumulator
		}

		let normalRange = Self.normalizeGlobalRange(
			offset..<(offset + count),
			toGlobalChunkRange: lastPartEnd..<(lastPartEnd + footer.count))
		guard normalRange.clamped(to: footer.indices).isOccupied else {
			return Data()
		}
		return footer[normalRange]
	}

	private func globalRange(for partForRange: Part) -> Range<Int>? {
		var offset = 0

		for part in parts {
			if part == partForRange {
				return offset..<(offset + part.totalCount)
			}

			offset += part.totalCount
		}

		return nil
	}

	private static func normalizeGlobalOffset(_ globalOffset: Int, toGlobalChunkStart chunkStart: Int) -> Int {
		globalOffset - chunkStart
	}

	private static func normalizeGlobalRange(
		_ globalRange: Range<Int>,
		toGlobalChunkRange chunkRange: Range<Int>
	) -> Range<Int> {
		let clamped = chunkRange.clamped(to: globalRange)
		return (clamped.lowerBound - chunkRange.lowerBound)..<(clamped.upperBound - chunkRange.lowerBound)
	}
}
