import Crypto
import Foundation
import NetworkHandler
import SwiftPizzaSnips
import Testing

struct MultipartFormTests {
	@Test func multipartFormModularOffsetCount() async throws {
		// given a form with known composition
		let boundary = "alsdkfajklsghdkjashdf"

		var form = MultipartForm(boundary: boundary)

		// a file part
		var rng: any RandomNumberGenerator = SeedableRNG(seed: 498_567)
		let loremIpsum = Data(String.randomLoremIpsum(wordCount: 6, using: &rng).utf8)

		let file = URL.temporaryDirectory.appending(component: "lorem-\(Int.random(in: 1000..<9999)).txt")
		defer { try? FileManager.default.removeItem(at: file) }
		try loremIpsum.write(to: file)
		form.append(file, named: "lorem", filename: "lorem.txt")

		// a data part
		let jsonSample = Sample(value: 5, label: "asdf", sub: nil)
		let jsonData = try JSONEncoder()
			.with { $0.outputFormatting = [.sortedKeys, .withoutEscapingSlashes] }
			.encode(jsonSample)
		form.append(jsonData, named: "metadata")

		// a string part
		let randomString = "bloo bar baz\n\ntrue fuzz"
		form.append(randomString, named: "randomized")

		let totalFormOutput = try form.render()
		let hash = totalFormOutput.persistentHashValue().toHexString()
		#expect(hash == "5c37579f467b73a33a99ba13b596a10f")

		// when it's read from any offset with any count
		for startOffset in 0..<(totalFormOutput.count + 10) {
			for count in 0..<(totalFormOutput.count + 10) {
				let chunk = try form.data(at: startOffset, count: count)

				let expectedChunk = {
					let range = (startOffset..<(startOffset + count)).clamped(to: totalFormOutput.indices)
					return totalFormOutput[range]
				}()

				// then it correctly maintains data integrity, including across internal component barriers
				#expect(chunk == expectedChunk)
			}
		}
	}

	@Test func dataPartModularOffsetCount() async throws {
		// given a part with known composition
		let boundary = "alsdkfajklsghdkjashdf"

		var form = MultipartForm(boundary: boundary)
		var rng: any RandomNumberGenerator = SeedableRNG(seed: 498_567)
		let loremIpsum = String.randomLoremIpsum(wordCount: 42, using: &rng)

		form.append(loremIpsum, named: "lorem")

		let part = form.parts[0]

		let totalPartOutput = try part.data(at: 0, count: part.totalCount)
		let hash = totalPartOutput.persistentHashValue().toHexString()
		#expect(hash == "3477f63728edfcbf24ead901a33b07ff")

		// when it's read from any offset with any count
		try exhaustivePartIterations(totalPartOutput: totalPartOutput, part: part)
	}

	@Test func filePartModularOffsetCount() async throws {
		// given a part with known composition
		let boundary = "alsdkfajklsghdkjashdf"

		var form = MultipartForm(boundary: boundary)
		var rng: any RandomNumberGenerator = SeedableRNG(seed: 498_567)
		let loremIpsum = Data(String.randomLoremIpsum(wordCount: 24, using: &rng).utf8)

		let file = URL.temporaryDirectory.appending(component: "lorem-\(Int.random(in: 1000..<9999)).txt")
		defer { try? FileManager.default.removeItem(at: file) }
		try loremIpsum.write(to: file)

		form.append(file, named: "lorem", filename: "lorem.txt")

		let part = form.parts[0]

		let totalPartOutput = try part.data(at: 0, count: part.totalCount)
		let hash = totalPartOutput.persistentHashValue().toHexString()
		#expect(hash == "1667026d5fac46ee103c7e62924bd34a")

		// when it's read from any offset with any count
		try exhaustivePartIterations(totalPartOutput: totalPartOutput, part: part)
	}

	private func exhaustivePartIterations(
		totalPartOutput: Data,
		part: MultipartForm.Part,
		line: Int = #line,
		column: Int = #column
	) throws {
		for startOffset in 0..<(totalPartOutput.count + 10) {
			for count in 0..<(totalPartOutput.count + 10) {
				let chunk = try part.data(at: startOffset, count: count)

				let expectedChunk = {
					let range = (startOffset..<(startOffset + count)).clamped(to: totalPartOutput.indices)
					return totalPartOutput[range]
				}()

				// then it correctly maintains data integrity, including across internal component barriers
				#expect(
					chunk == expectedChunk,
					sourceLocation: SourceLocation(
						fileID: #fileID,
						filePath: #filePath,
						line: line,
						column: column))
			}
		}
	}

	struct Sample: Codable, Sendable {
		let value: Int
		let label: String
		let sub: SubSample?

		struct SubSample: Codable, Sendable {
			let foo: String
		}
	}
}
