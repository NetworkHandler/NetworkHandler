import Foundation

extension MultipartForm.Part {
	/// Represents the content of a multipart form part.
	///
	/// Content can be provided as raw ``Data`` or read from a file at a given ``URL``.
	public enum Content: Sendable, Hashable {
		/// Raw data bytes.
		case data(Data)

		/// A file referenced by its URL.
		case file(URL)

		/// Converts a `String` to `Data` and creates content using UTF-8 encoding.
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
