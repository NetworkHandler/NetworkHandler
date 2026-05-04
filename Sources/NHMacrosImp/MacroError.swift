import Foundation

struct MacroError: Error {
	let message: String

	static func message(_ message: String) -> MacroError {
		MacroError(message: message)
	}
}
