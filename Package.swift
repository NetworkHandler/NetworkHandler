// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var products: [Product] = [
	.library(
		name: "NetworkHandler",
		targets: ["NetworkHandler"]),
	.library(
		name: "TestSupport",
		targets: ["TestSupport"]),
]

var targets: [Target] = [
	.target(
		name: "NetworkHandler",
		dependencies: [
			.product(name: "Crypto", package: "swift-crypto"),
			"SwiftPizzaSnips",
			.product(name: "Logging", package: "swift-log"),
			.product(name: "HTTPTypes", package: "swift-http-types"),
			"NHMacros",
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]),
	.target(
		name: "TestSupport",
		dependencies: [
			"PizzaMacros",
			"NetworkHandler",
			"SwiftlyDotEnv",
			"NHMacros",
			"Embassy",
			"DataScanner",
		],
		resources: [
			.process("Resources")
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]),
	.testTarget(
		name: "NetworkHandlerTests",
		dependencies: [
			"NetworkHandler",
			"TestSupport",
			"PizzaMacros",
			.product(name: "Logging", package: "swift-log"),
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]),

]

#if !canImport(FoundationNetworking)
products.append(
	.library(
		name: "NetworkHandlerURLSessionEngine",
		targets: ["NetworkHandlerURLSessionEngine"]))

targets.append(
	.target(
		name: "NetworkHandlerURLSessionEngine",
		dependencies: [
			"NetworkHandler",
			"SwiftPizzaSnips",
			.product(name: "Logging", package: "swift-log"),
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]))

targets.append(
	.testTarget(
		name: "NetworkHandlerURLSessionTests",
		dependencies: [
			"NetworkHandler",
			"TestSupport",
			"PizzaMacros",
			.product(name: "Logging", package: "swift-log"),
			"NetworkHandlerURLSessionEngine",
		],
		plugins: [
			.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
		]))
#endif

let package = Package(
	name: "NetworkHandler",
	platforms: [
		.macOS(.v13),
		.iOS(.v16),
		.tvOS(.v16),
		.watchOS(.v8),
	],
	products: products,
	dependencies: [
		.package(url: "https://github.com/apple/swift-crypto.git", .upToNextMajor(from: "3.0.0")),
		.package(url: "https://github.com/mredig/PizzaMacros.git", .upToNextMajor(from: "0.1.6")),
		.package(url: "https://github.com/mredig/SwiftPizzaSnips.git", .upToNextMajor(from: "0.4.35")),
		//		.package(url: "https://github.com/mredig/SwiftPizzaSnips.git", branch: "0.4.34h"),
		.package(url: "https://github.com/mredig/SwiftlyDotEnv.git", .upToNextMinor(from: "0.2.3")),
		.package(url: "https://github.com/mredig/DataScanner.git", .upToNextMinor(from: "0.4.3")),
		.package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.6.2")),
		.package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.58.2"),
		.package(url: "https://github.com/apple/swift-http-types.git", from: "1.5.1"),
		.package(url: "https://github.com/NetworkHandler/NHMacros.git", .upToNextMajor(from: "0.0.1")),
		.package(url: "https://github.com/envoy/Embassy.git", .upToNextMajor(from: "4.1.6")),
	],
	targets: targets)
