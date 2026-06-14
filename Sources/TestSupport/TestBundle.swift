import Foundation

extension Bundle {
	/// Access to the bundle for the test suite
	///
	/// Internally, it's just a hoisted value of `Bundle.module`, but again, specific to the test suite
	public static var testBundle: Bundle { module }
}
