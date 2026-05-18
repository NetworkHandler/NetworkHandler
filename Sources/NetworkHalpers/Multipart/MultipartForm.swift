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

extension MultipartForm {
	public struct Part: Sendable, Hashable {
		public var dataCount: Int { content?.count ?? 0 }
		public var totalCount: Int { dataCount + headers.count + footer.count }

		public var boundary: String

		public var name: String
		public var contentType: String?
		public var filename: String?
		public var content: Content?

		public var headers: Data { Data(headersString.utf8) }
		private var headersString: String {
			var accumulator = "--\(boundary)\r\n"

			var dispositionLine: [String] = []
			if content != nil {
				dispositionLine.append("Content-Disposition: form-data")
				dispositionLine.append("name=\"\(name)\"")
			}
			if let filename {
				dispositionLine.append("filename=\"\(filename)\"")
			}
			accumulator += dispositionLine.joined(separator: "; ")

			if let contentType {
				accumulator += "\r\nContent-Type: \(contentType)\r\n\r\n"
			} else {
				accumulator += "\r\n\r\n"
			}

			return accumulator
		}

		public var footer: Data { Data(footerString.utf8) }
		private var footerString: String { "\r\n" }

		public func data(at offset: Int, count: Int) throws -> Data {
			let headers = headers

			var offset = offset

			let endOffset = min(offset + count, totalCount)

			let dataStart = headers.endIndex
			let footerStart = dataStart + dataCount
			let footerEnd = footerStart + footer.count

			var accumulator = Data(capacity: count)

			while offset < endOffset {
				switch offset {
				case ..<dataStart:
					let range: Range<Int>
					if endOffset <= dataStart {
						range = offset..<endOffset
						offset = endOffset
					} else {
						range = offset..<dataStart
						offset = dataStart
					}
					accumulator.append(headers[range])
				case dataStart..<footerStart:
					let content = content ?? .data(Data())
					let normalizedOffset = offset - dataStart
					let normalizedEndOffset = endOffset - dataStart
					let normalRange: Range<Int>
					if endOffset <= footerStart {
						normalRange = normalizedOffset..<normalizedEndOffset
						offset = endOffset
					} else {
						normalRange = normalizedOffset..<dataCount
						offset = footerStart
					}
					try accumulator.append(content.data(range: normalRange))
				case footerStart..<footerEnd:
					let normalizedOffset = offset - footerStart
					let normalizedEndOffset = endOffset - footerStart
					let normalRange: Range<Int>
					if endOffset <= footerEnd {
						normalRange = normalizedOffset..<normalizedEndOffset
						offset = endOffset
					} else {
						normalRange = normalizedOffset..<footerEnd
						offset = footerEnd
					}
					accumulator.append(footer[normalRange])
				default: offset = endOffset
				}
			}

			return accumulator
		}
	}
}

extension MultipartForm.Part {
	public enum Content: Sendable, Hashable {
		case data(Data)
		case file(URL)

		public static func string(_ string: String) -> Content {
			.data(Data(string.utf8))
		}

		var count: Int {
			switch self {
			case .data(let data):
				return data.count
			case .file(let url):
				guard url.isFileURL else { return 0 }
				let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
				return fileSize ?? 0
			}
		}

		func data(range: Range<Int>) throws -> Data {
			switch self {
			case .data(let data):
				return data[range]
			case .file(let fileURL):
				let handle = try FileHandle(forReadingFrom: fileURL)
				handle.seek(toFileOffset: UInt64(range.lowerBound))
				return try handle.read(upToCount: range.count) ?? Data()
			}
		}
	}
}
