import Foundation
import HTTPTypes

@freestanding(expression)
public macro HTTPFieldName(_ stringLiteral: String) -> HTTPField.Name = #externalMacro(module: "NHMacrosImp", type: "HTTPFieldNameMacro")
