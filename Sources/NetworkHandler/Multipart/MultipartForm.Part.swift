import Foundation

extension MultipartForm {
	/// A single part within an `MultipartForm`.
	///
	/// Each `Part` contains metadata (headers, boundary) and optional
	/// content, and can produce the raw bytes that represent it in a
	/// multipart message.
	public struct Part: Sendable, Hashable {
		/// The number of content bytes in this part.
		///
		/// Returns `0` when no content is present.
		public var dataCount: Int { content?.count ?? 0 }

		/// The total number of bytes emitted for this part.
		///
		/// Includes content bytes plus the byte lengths of the headers
		/// and footer.
		public var totalCount: Int { dataCount + headers.count + footer.count }

		/// The MIME boundary that separates this part from adjacent parts
		/// when serialized.
		public var boundary: String

		/// The part's "name" as used in `Content-Disposition` for form
		/// data uploads.
		public var name: String

		/// The media type describing the part's payload (e.g.
		/// `"application/json"`), or `nil` when no `Content-Type` header
		/// should be emitted.
		public var contentType: String?

		/// The suggested filename for the part's content (e.g. when it
		/// represents an uploaded file).
		public var filename: String?

		/// The content payload for the part, or `nil` when this part
		/// carries no body (only headers).
		public var content: Content?

		/// The assembled header bytes for this part.
		///
		/// Includes the boundary line, the `Content-Disposition` header
		/// (with the part's `name` and `filename` when applicable), and
		/// an optional `Content-Type` header.
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

		/// The trailing bytes appended after the content.
		///
		/// Currently emits a single CRLF (`\r\n`) to terminate the
		/// headers section before the body begins.
		public var footer: Data { Data(footerString.utf8) }
		private var footerString: String { "\r\n" }

		/// Returns the raw bytes for this part starting at ``offset``
		/// with the given ``count``.
		///
		/// - Parameters:
		///    - offset: The starting byte offset within the fully-assembled
		///      part (including headers, content, and footer).
		///    - count: The number of bytes to extract.
		/// - Returns: The extracted bytes as a ``Data`` instance.
		/// - Throws: An error if the `content` is unavailable
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
