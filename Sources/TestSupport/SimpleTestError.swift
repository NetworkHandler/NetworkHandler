/// A simple error type for use in tests.
///
/// Provides a basic `Error` implementation with a descriptive message.
/// Useful for testing error handling and recovery paths.
public struct SimpleTestError: Error {
	/// A description of the error.
	public let message: String

	/// Creates a simple test error.
	/// - Parameter message: A description of the error.
	public init(message: String) {
		self.message = message
	}
}
