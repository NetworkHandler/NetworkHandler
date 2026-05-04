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

	private static let _s3AccessKey: Result<String, Error> = {
		loadIfNeeded()
		guard let key = SwiftlyDotEnv[.s3AccessKeyKey] else {
			return .failure(
				SimpleTestError(
					message: "Env needs setting up - looks like the .env file might be missing or incomplete"))
		}

		return .success(key)
	}()
	public static var s3AccessKey: String {
		get throws {
			try _s3AccessKey.get()
		}
	}
	private static let _s3AccessSecret: Result<String, Error> = {
		loadIfNeeded()
		guard let secret = SwiftlyDotEnv[.s3AccessSecretKey] else {
			return .failure(
				SimpleTestError(
					message: "Env needs setting up - looks like the .env file might be missing or incomplete"))
		}

		return .success(secret)
	}()
	public static var s3AccessSecret: String {
		get throws {
			try _s3AccessSecret.get()
		}
	}
}

fileprivate extension String {
	static let s3AccessKeyKey = "S3KEY"
	static let s3AccessSecretKey = "S3SECRET"
}
