import Crypto
import Foundation

/// A sequence type that provides convenient access to digest values
/// as bytes, a hexadecimal string, and a Base64-encoded string.
public protocol DigestToValues: Sequence {
	/// Returns the digest as a `Data` object.
	func bytes() -> Data
	/// Returns the digest as a hexadecimal string.
	func hex() -> String
	/// Returns the digest as a Base64-encoded string using the specified encoding options.
	func base64(options: Data.Base64EncodingOptions) -> String
}

public extension DigestToValues where Element == UInt8 {
	func bytes() -> Data {
		Data(self)
	}

	func hex() -> String {
		self
			.map {
				let value = String($0, radix: 16)
				return value.count == 2 ? value : "0\(value)"
			}
			.joined()
	}

	func base64(options: Data.Base64EncodingOptions) -> String {
		bytes().base64EncodedString(options: options)
	}
}

extension SHA256Digest: DigestToValues {}
extension SHA384Digest: DigestToValues {}
extension SHA512Digest: DigestToValues {}
extension Insecure.MD5Digest: DigestToValues {}
extension Insecure.SHA1Digest: DigestToValues {}

extension HashedAuthenticationCode: DigestToValues {}
