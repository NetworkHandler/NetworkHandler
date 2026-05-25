import Foundation

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
