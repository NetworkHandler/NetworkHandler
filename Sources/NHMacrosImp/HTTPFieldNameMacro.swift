import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation
import HTTPTypes

public enum HTTPFieldNameMacro: ExpressionMacro {
	public static func expansion(
		of node: some FreestandingMacroExpansionSyntax,
		in context: some MacroExpansionContext
	) throws -> ExprSyntax {
		guard
			let argument = node.arguments.first?.expression,
			let segments = argument.as(StringLiteralExprSyntax.self)?.segments,
			segments.count == 1,
			case .stringSegment(let literalSegment)? = segments.first
		else {
			throw MacroError.message("#HTTPFieldName requires a static string literal")
		}

		guard HTTPField.Name(literalSegment.content.text) != nil else {
			throw MacroError.message("Malformed field name: \(argument)")
		}

		return "HTTPField.Name(\(argument))!"
	}
}
