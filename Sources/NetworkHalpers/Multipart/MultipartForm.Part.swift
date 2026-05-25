import Foundation

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
