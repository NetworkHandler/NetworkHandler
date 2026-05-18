import Foundation
import NetworkHalpers
import SwiftPizzaSnips
import Testing

struct MultipartFormTests {
	@Test func sameOutput() async throws {
		let boundary = "alsdkfajklsghdkjashdf"

		let baseForm = MultipartFormInputTempFile(boundary: boundary)
		var newFormat = MultipartForm(boundary: boundary)

		let jsonSample = Sample(value: 5, label: "asdf", sub: .init(foo: "bar"))
		let jsonData = try JSONEncoder()
			.with { $0.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] }
			.encode(jsonSample)
		baseForm.addPart(named: "metadata", data: jsonData)
		newFormat.append(jsonData, named: "metadata")

		let randomString = "bloo bar bazination\n\ntrue fuzz"
		baseForm.addPart(named: "randomized", string: randomString)
		newFormat.append(randomString, named: "randomized")

		var rng: any RandomNumberGenerator = SeedableRNG(seed: 498_567)
		let randomTextForFile = String.randomLoremIpsum(wordCount: 42, using: &rng)
		let randomFile = URL.temporaryDirectory.appending(component: "afile.txt")
		try Data(randomTextForFile.utf8).write(to: randomFile)
		defer { try? FileManager.default.removeItem(at: randomFile) }
		baseForm.addPart(named: "thefile", fileURL: randomFile, filename: "lorem.txt", contentType: "text/plain")
		newFormat.append(randomFile, named: "thefile", filename: "lorem.txt")

		let baseOut = try await baseForm.renderToFile()

		let oldFileURL = URL.homeDirectory.appending(path: "Swap/multi-old.bin")
		let newFileURL = URL.homeDirectory.appending(path: "Swap/multi-new.bin")
		let newChunkFileURL = URL.homeDirectory.appending(path: "Swap/multi-new-datachunked.bin")

		for file in [oldFileURL, newFileURL, newChunkFileURL] {
			try? FileManager.default.removeItem(at: file)
		}

		try FileManager.default.moveItem(at: baseOut, to: oldFileURL)
		try newFormat.render().write(to: newFileURL)
		try newFormat.data(at: 0, count: newFormat.count).write(to: newChunkFileURL)
	}

	struct Sample: Codable, Sendable {
		let value: Int
		let label: String
		let sub: SubSample

		struct SubSample: Codable, Sendable {
			let foo: String
		}
	}
}
