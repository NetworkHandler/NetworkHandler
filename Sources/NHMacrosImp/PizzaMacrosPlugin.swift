import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct PizzaMacrosPlugin: CompilerPlugin {
	let providingMacros: [Macro.Type] = [
		HTTPFieldNameMacro.self,
	]
}
