import Foundation

extension AWSV4Signature {
	/// Initializes an `AWSV4Signature` instance for a `StandardRequest`.
	///
	/// This initializer extracts the relevant metadata from a `StandardRequest` to construct an AWS Signature V4 context.
	/// The `hexContentHash` argument must reflect the SHA-256 hash of the body payload specific to the signing process.
	///
	/// - Parameters:
	///   - request: A `StandardRequest` object encapsulating details like method and URL.
	///   - date: The date and time for the request signature. Defaults to the current system date.
	///   - awsKey: The AWS access key string.
	///   - awsSecret: The AWS secret access key string.
	///   - awsRegion: The AWS region identifier for the request.
	///   - awsService: The AWS service name (e.g., `s3`).
	///   - hexContentHash: The precomputed SHA-256 hash of the request payload, as a hex string.
	public init(
		for request: StandardRequest,
		date: Date = Date(),
		awsKey: String,
		awsSecret: String,
		awsRegion: AWSV4Signature.AWSRegion,
		awsService: AWSV4Signature.AWSService,
		hexContentHash: AWSContentHash
	) {
		self.init(
			requestMethod: request.method,
			url: request.url,
			date: date,
			awsKey: awsKey,
			awsSecret: awsSecret,
			awsRegion: awsRegion,
			awsService: awsService,
			hexContentHash: hexContentHash,
			additionalSignedHeaders: [:])
	}

	/// Processes an existing `StandardRequest` by attaching AWS-signed headers.
	///
	/// This function validates the `url` and `method` of the incoming request, generates AWS-specific headers,
	/// and merges them into the existing request's headers. The updated request is then returned.
	///
	/// - Parameter request: A `StandardRequest` to be signed.
	/// - Returns: The updated `StandardRequest` with the signed headers integrated.
	/// - Throws: `AWSAuthError` if the `url` or `method` on the request does not match
	///   those defined in the signature context.
	public func processRequest(_ request: StandardRequest) throws -> StandardRequest {
		try processRequestInfo(url: request.url, method: request.method) { newHeaders in
			var new = request
			new.headers += newHeaders
			return new
		}
	}
}
