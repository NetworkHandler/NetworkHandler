import Foundation
import Logging
@preconcurrency import SwiftlyDotEnv

/// most easily populated by setting up env vars in xcode scheme. not sure how to do on linux...
public enum TestEnvironment {
	private typealias SDEnv = SwiftlyDotEnv

	private static let logger = Logger(label: "Test Environment")

	private static func loadIfNeeded() {
		guard SwiftlyDotEnv.isLoaded == false else { return }
		do {
			try SwiftlyDotEnv.loadDotEnv(
				from: URL(fileURLWithPath: #filePath)
					.deletingLastPathComponent()
					.deletingLastPathComponent()
					.deletingLastPathComponent(),
				envName: "tests",
				requiringKeys: [
					"S3KEY",
					"S3SECRET",
				])
		} catch {
			let message = """
				Could not load env vars (you probably need a `.env.tests` file in the NetworkHandler root directory: \(error)
				"""
			logger.error("\(message)")
			fatalError(message)
		}
	}
}
