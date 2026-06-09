import Foundation
import HTTPTypes
import UniformTypeIdentifiers

/// A multipart/form-data builder that assembles parts and renders them as `Data`.
///
/// Use this type to construct form data containing binary parts, text fields, and file uploads.
/// `MultipartForm` manages a configurable boundary string and provides methods to append content,
/// then either render the entire form into a single `Data` blob or retrieve a slice of
/// the data at a given offset.
public struct MultipartForm: Sendable, Hashable {
	/// The boundary string used to delimit parts in the rendered form-data.
	///
	/// The rendered boundary always starts with the prefix `"Boundary-"` followed by the value
	/// passed to ``init(boundary:)``.
	public var boundary: String { "Boundary-\(boundaryRoot)" }
	private let boundaryRoot: String

	/// The HTTP ``HTTPTypes/HTTPField.Value`` for the `Content-Type` header of this form.
	///
	/// Returns a value like `"multipart/form-data; boundary=Boundary-MyBoundary"` using
	/// the receiver's ``boundary``.
	public var multipartContentTypeHeaderValue: HTTPField.Value {
		"multipart/form-data; boundary=\(boundary)"
	}

	/// The collection of parts in this form, in the order they were appended.
	///
	/// Each element represents a single section of the multipart data, including file uploads,
	/// binary blobs, or text fields.
	public var parts: [Part] = []

	/// The total number of bytes in the rendered form.
	///
	/// This is the sum of each part's ``MultipartForm/Part/totalCount``, plus the closing
	/// footer delimiter.
	public var count: Int { parts.reduce(0, { $0 + $1.totalCount }) + footer.count }

	/// The closing footer delimeter (`"--\(boundary)--\r\n"`).
	///
	/// Appended after the last part when rendering the form.
	public var footer: Data { Data(footerString.utf8) }
	private var footerString: String { "--\(boundary)--\r\n" }

	/// Creates a new multipart form with the given boundary.
	///
	/// - Parameter boundary: The freeform boundary token to use. The ``boundary`` property
	///   will prefix this with `"Boundary-"` for the actual delimiter.
	public init(boundary: String) {
		self.boundaryRoot = boundary
	}

	/// Appends a pre-constructed part to the form.
	///
	/// - Parameter part: The part to add.
	public mutating func append(_ part: Part) {
		parts.append(part)
	}

	/// Appends a binary data part.
	///
	/// - Parameters:
	///   - data: The binary data to include.
	///   - name: The form-field name.
	///   - filename: Optional filename for the part.
	///   - contentType: The MIME type; defaults to `"application/octet-stream"` when `nil`.
	public mutating func append(_ data: Data, named name: String, filename: String? = nil, contentType: String? = nil) {
		let part = Part(
			boundary: boundary,
			name: name,
			contentType: contentType ?? "application/octet-stream",
			filename: filename,
			content: .data(data))
		append(part)
	}

	/// Appends a text string part.
	///
	/// - Parameters:
	///   - string: The text to include.
	///   - name: The form-field name.
	///   - filename: Optional filename for the part.
	///   - contentType: Optional MIME type.
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

	/// Appends a file-based part whose content is read from a URL on disk.
	///
	/// - Parameters:
	///   - file: A `file://` URL pointing to the file to include.
	///   - name: The form-field name.
	///   - filename: Optional override for the filename; defaults to the URL's last path component.
	///   - contentType: Optional MIME type; when `nil`, inferred from the path extension.
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

	/// Renders the entire multipart form as a single `Data` blob.
	///
	/// Returns the concatenation of all parts (each rendered with their headers, content,
	/// and footers) followed by the closing footer delimiter.
	public func render() throws -> Data {
		var accum = Data()
		for part in parts {
			let partData = try part.data(at: 0, count: part.totalCount)
			accum.append(partData)
		}
		accum.append(footer)
		return accum
	}

	/// Returns a slice of the rendered form data.
	///
	/// This method returns `count` bytes starting at the given `offset` within the fully rendered
	/// byte stream (parts + closing footer). Each part contributes its headers, content, and
	/// footer in sequence.
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
