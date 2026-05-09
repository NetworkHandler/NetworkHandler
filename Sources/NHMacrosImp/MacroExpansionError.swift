import SwiftSyntaxMacros

extension MacroExpansionErrorMessage {
	static func message(_ message: String) -> MacroExpansionErrorMessage {
		MacroExpansionErrorMessage(message)
	}
}
