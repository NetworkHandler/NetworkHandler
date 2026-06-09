import Foundation
#if canImport(CommonCrypto)
import CommonCrypto

/// An enumeration of HMAC algorithms supported by this implementation.
///
/// Maps to Common Crypto HMAC algorithms and provides digest length information.
public enum HMACAlgorithm {
	case md5, sha1, sha224, sha256, sha384, sha512

	/// The corresponding Common Crypto HMAC algorithm value.
	public var hmacAlgValue: CCHmacAlgorithm {
		let value: Int
		switch self {
		case .md5:
			value = kCCHmacAlgMD5
		case .sha1:
			value = kCCHmacAlgSHA1
		case .sha224:
			value = kCCHmacAlgSHA224
		case .sha256:
			value = kCCHmacAlgSHA256
		case .sha384:
			value = kCCHmacAlgSHA384
		case .sha512:
			value = kCCHmacAlgSHA512
		}
		return CCHmacAlgorithm(value)
	}

	/// The digest length in bytes for this algorithm.
	public var digestLength: Int {
		let result: Int32
		switch self {
		case .md5:
			result = CC_MD5_DIGEST_LENGTH
		case .sha1:
			result = CC_SHA1_DIGEST_LENGTH
		case .sha224:
			result = CC_SHA224_DIGEST_LENGTH
		case .sha256:
			result = CC_SHA256_DIGEST_LENGTH
		case .sha384:
			result = CC_SHA384_DIGEST_LENGTH
		case .sha512:
			result = CC_SHA512_DIGEST_LENGTH
		}
		return Int(result)
	}
}

public extension String {
	/// Computes an HMAC for this string using the specified algorithm and key.
	///
	/// - Parameters:
	///   - algorithm: The HMAC algorithm to use.
	///   - key: The key to use for HMAC computation.
	/// - Returns: A base64-encoded HMAC digest string.
	func hmac(algorithm: HMACAlgorithm, key: String) -> String {
		var result = [UInt8].init(repeating: 0, count: algorithm.digestLength)
		CCHmac(algorithm.hmacAlgValue, key, key.count, self, self.count, &result)

		let hmacData = Data(result)
		return hmacData.base64EncodedString(options: .lineLength76Characters)
	}
}
#endif
