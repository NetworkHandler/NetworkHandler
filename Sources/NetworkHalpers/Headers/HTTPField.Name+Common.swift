import HTTPTypes

extension HTTPField.Name {
	/// Convenience for the `X-Request-ID` HTTP Header name
	public static let xRequestID: Self = .init("X-Request-ID")!

	/// Convenience for the `Accept-Charset` HTTP Header name
	public static let acceptCharset: Self = .init("Accept-Charset")!

	/// Convenience for the `Accept-Datetime` HTTP Header name
	public static let acceptDatetime: Self = .init("Accept-Datetime")!

	/// Convenience for the `Front-End-Https` HTTP Header name
	public static let frontEndHttps: Self = .init("Front-End-Https")!

	/// Convenience for the `Pragma` HTTP Header name
	public static let pragma: Self = .init("Pragma")!

	/// Convenience for the `Proxy-Connection` HTTP Header name
	public static let proxyConnection: Self = .init("Proxy-Connection")!

	/// Convenience for the `Warning` HTTP Header name
	public static let warning: Self = .init("Warning")!
}
