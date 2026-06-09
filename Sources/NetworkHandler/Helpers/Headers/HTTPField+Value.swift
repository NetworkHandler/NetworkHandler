import Foundation
import HTTPTypes

extension HTTPField {
	public var semanticValue: Value {
		get { .init(rawValue: self.value) }
		set { self.value = newValue.rawValue }
	}

	public init(name: Name, value: Value) {
		self.init(name: name, value: value.rawValue)
	}

	/// A semantic type for HTTPField values. This is not canonical with the HTTPField type, but
	/// is extended on top of the established upstream type. It includes many common values and is extendable.
	public struct Value:
		RawRepresentable,
		Codable,
		Hashable,
		Sendable,
		ExpressibleByStringLiteral,
		ExpressibleByStringInterpolation {

		public let rawValue: String
		public var value: String { rawValue }

		public init(stringLiteral value: StringLiteralType) {
			self.rawValue = value
		}

		public init(rawValue: String) {
			self.rawValue = rawValue
		}

		// common Content-Type values
		/// Convenience for the `application/javascript` `Content-Type` value
		public static let javascript: Value = "application/javascript"
		/// Convenience for the `application/json` `Content-Type` value
		public static let json: Value = "application/json"
		/// Convenience for the `application/octet-stream` `Content-Type` value
		public static let octetStream: Value = "application/octet-stream"
		/// Convenience for the `application/x-font-woff` `Content-Type` value
		public static let xFontWoff: Value = "application/x-font-woff"
		/// Convenience for the `application/xml` `Content-Type` value
		public static let xml: Value = "application/xml"
		/// Convenience for the `audio/mp4` `Content-Type` value
		public static let audioMp4: Value = "audio/mp4"
		/// Convenience for the `audio/ogg` `Content-Type` value
		public static let ogg: Value = "audio/ogg"
		/// Convenience for the `font/opentype` `Content-Type` value
		public static let opentype: Value = "font/opentype"
		/// Convenience for the `image/svg+xml` `Content-Type` value
		public static let svgXml: Value = "image/svg+xml"
		/// Convenience for the `image/webp` `Content-Type` value
		public static let webp: Value = "image/webp"
		/// Convenience for the `image/x-icon` `Content-Type` value
		public static let xIcon: Value = "image/x-icon"
		/// Convenience for the `text/cache-manifest` `Content-Type` value
		public static let cacheManifest: Value = "text/cache-manifest"
		/// Convenience for the `text/v-card` `Content-Type` value
		public static let vCard: Value = "text/v-card"
		/// Convenience for the `text/vtt` `Content-Type` value
		public static let vtt: Value = "text/vtt"
		/// Convenience for the `video/mp4` `Content-Type` value
		public static let videoMp4: Value = "video/mp4"
		/// Convenience for the `video/ogg` `Content-Type` value
		public static let videoOgg: Value = "video/ogg"
		/// Convenience for the `video/webm` `Content-Type` value
		public static let webm: Value = "video/webm"
		/// Convenience for the `video/x-flv` `Content-Type` value
		public static let xFlv: Value = "video/x-flv"
		/// Convenience for the `image/png` `Content-Type` value
		public static let png: Value = "image/png"
		/// Convenience for the `image/jpeg` `Content-Type` value
		public static let jpeg: Value = "image/jpeg"
		/// Convenience for the `image/bmp` `Content-Type` value
		public static let bmp: Value = "image/bmp"
		/// Convenience for the `text/css` `Content-Type` value
		public static let css: Value = "text/css"
		/// Convenience for the `image/gif` `Content-Type` value
		public static let gif: Value = "image/gif"
		/// Convenience for the `text/html` `Content-Type` value
		public static let html: Value = "text/html"
		/// Convenience for the `audio/mpeg` `Content-Type` value
		public static let audioMpeg: Value = "audio/mpeg"
		/// Convenience for the `video/mpeg` `Content-Type` value
		public static let videoMpeg: Value = "video/mpeg"
		/// Convenience for the `application/pdf` `Content-Type` value
		public static let pdf: Value = "application/pdf"
		/// Convenience for the `video/quicktime` `Content-Type` value
		public static let quicktime: Value = "video/quicktime"
		/// Convenience for the `application/rtf` `Content-Type` value
		public static let rtf: Value = "application/rtf"
		/// Convenience for the `image/tiff` `Content-Type` value
		public static let tiff: Value = "image/tiff"
		/// Convenience for the `text/plain` `Content-Type` value
		public static let plain: Value = "text/plain"
		/// Convenience for the `application/zip` `Content-Type` value
		public static let zip: Value = "application/zip"
		/// Convenience for the `application/x-plist` `Content-Type` value
		public static let plist: Value = "application/x-plist"
		/// If using built in multipart form support, look into `MultipartFormInputStream.multipartContentTypeHeaderValue`
		public static func multipart(boundary: String) -> Value {
			"multipart/form-data; boundary=\(boundary)"
		}
		/// Formats the given bearer token into the standard formatting for bearer style Authentication.
		///
		/// Note that the input is not encrypted in memory prior to being sent in the request, so try to keep
		/// this value shortly lived in memory.
		public static func bearerToken(_ token: String) -> Value {
			"Bearer \(token)"
		}
		/// Formats the given credentials into the standard formatting for basic style Authentication.
		///
		/// Note that the input is not encrypted in memory prior to being sent in the request, so try to keep
		/// this value shortly lived in memory.
		public static func basicAuth(user: String, password: String) -> Value {
			let encoded = Data("\(user):\(password)".utf8).base64EncodedString()
			return "Basic \(encoded)"
		}

		public static func == (lhs: Value, rhs: String?) -> Bool {
			lhs.value == rhs
		}

		public static func == (lhs: String?, rhs: Value) -> Bool {
			rhs == lhs
		}

		public static func != (lhs: Value, rhs: String?) -> Bool {
			!(lhs == rhs)
		}

		public static func != (lhs: String?, rhs: Value) -> Bool {
			rhs != lhs
		}
	}
}

extension HTTPField.Value: CustomStringConvertible, CustomDebugStringConvertible {
	public var description: String { value }
	public var debugDescription: String {
		"HeaderValue: \(description)"
	}
}

extension HTTPField.Value: Comparable {
	public static func < (lhs: Self, rhs: Self) -> Bool {
		lhs.rawValue < rhs.rawValue
	}
}

extension HTTPFields {
	/// Access the semantic field value string by name. This allows dot syntax for common values
	/// when setting values.
	///
	/// Example:
	/// ```swift
	/// // Set a header field in the request.
	/// request.headerFields[semantic: .accept] = .json
	///
	/// // Access a header field value from the response.
	/// let contentTypeValue = response.headerFields[.contentType]
	/// ```
	///
	/// If multiple fields with the same name exist, they are concatenated with commas (or
	/// semicolons in the case of the "Cookie" header field).
	///
	/// When setting a "Cookie" header field value, it is split into multiple "Cookie" fields by
	/// semicolon.
	public subscript(semantic name: HTTPField.Name) -> HTTPField.Value? {
		get { self[name].map(HTTPField.Value.init(rawValue:)) }
		set { self[name] = newValue?.rawValue }
	}
}
