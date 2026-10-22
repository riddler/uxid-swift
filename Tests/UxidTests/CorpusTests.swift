import Testing

@testable import Uxid

// Every case of the vendored conformance corpus (`conformance/`, uxid-ex at
// the tag `conformance/SOURCE.json` names), one parameterized test per case
// file, with no skip list: a case this port cannot pass is reported against
// the reference, never skipped. CorpusRunner runs one case; the hash suite
// checks the files are the ones the manifest describes.

/// The cases of one case file, for a test's arguments.
private func cases(_ file: CaseFile) throws -> [CorpusCase] {
  try Corpus.cases(file)
}

@Suite("Corpus cases")
struct CorpusTests {
  @Test("encode (sabotage: rand field always lower -> id mismatch)", arguments: try cases(.encode))
  func encode(_ testCase: CorpusCase) throws {
    #expect(testCase.id.hasPrefix("encode/"))
    try CorpusRunner.encode(testCase.line)
  }

  @Test("derive (sabotage: no count byte -> id mismatch)", arguments: try cases(.deterministic))
  func deterministic(_ testCase: CorpusCase) throws {
    #expect(testCase.id.hasPrefix("deterministic/"))
    try CorpusRunner.deterministic(testCase.line)
  }

  @Test("decode (sabotage: no window step-back -> time mismatch)", arguments: try cases(.decode))
  func decode(_ testCase: CorpusCase) throws {
    #expect(testCase.id.hasPrefix("decode/"))
    try CorpusRunner.decode(testCase.line)
  }

  @Test("invalid (sabotage: no rand_with_from -> outcome mismatch)", arguments: try cases(.invalid))
  func invalid(_ testCase: CorpusCase) throws {
    #expect(testCase.id.hasPrefix("invalid/"))
    try CorpusRunner.invalid(testCase.line)
  }

  @Test("monotonic (sabotage: <= read as == -> ids mismatch)", arguments: try cases(.monotonic))
  func monotonic(_ testCase: CorpusCase) throws {
    #expect(testCase.id.hasPrefix("monotonic/"))
    try CorpusRunner.monotonic(testCase.line)
  }
}

/// A case line with a key the runner does not know, and the kind to run it as.
struct StrictCase: Sendable, CustomTestStringConvertible {
  let kind: CaseFile
  let line: String
  let missing: String?

  var testDescription: String { "\(kind.rawValue) \(missing ?? "unknown")" }

  /// Runs the line as its kind.
  func run() throws {
    switch kind {
    case .encode: try CorpusRunner.encode(line)
    case .deterministic: try CorpusRunner.deterministic(line)
    case .decode: try CorpusRunner.decode(line)
    case .invalid: try CorpusRunner.invalid(line)
    case .monotonic: try CorpusRunner.monotonic(line)
    }
  }
}

private let unknownKeys: [StrictCase] = [
  StrictCase(
    kind: .encode,
    line: #"{"expected":"hf7yat0001","extra":1,"id":"encode/x","input":{"case":"lower","#
      + #""compact":true,"prefix":null,"rand":"01","size":"xs","time":1700000000000}}"#,
    missing: nil),
  StrictCase(
    kind: .encode,
    line: #"{"expected":"hf7yat0001","id":"encode/x","input":{"case":"lower","compact":true,"#
      + #""extra":null,"prefix":null,"rand":"01","size":"xs","time":1700000000000}}"#,
    missing: nil),
  StrictCase(
    kind: .deterministic,
    line: #"{"expected":"z","extra":[],"id":"deterministic/x","input":{"case":"lower","#
      + #""from":"a","prefix":null,"size":"xs"}}"#,
    missing: nil),
  StrictCase(
    kind: .decode,
    line: #"{"expected":{"compact":false,"deterministic":false,"extra":true,"prefix":null,"#
      + #""size":"xs","time":0},"id":"decode/x","input":"0000000000"}"#,
    missing: nil),
  StrictCase(
    kind: .invalid,
    line: #"{"expected_error":"empty","id":"invalid/x","input":{"decode":"","extra":1}}"#,
    missing: nil),
  StrictCase(
    kind: .invalid,
    line: #"{"expected_error":"empty","id":"invalid/x","input":{"generate":{"extra":1,"#
      + #""from":"a","monotonic":true}}}"#,
    missing: nil),
  StrictCase(
    kind: .monotonic,
    line: #"{"expected":["hf7yat0000"],"extra":1,"id":"monotonic/x","input":{"compact":true,"#
      + #""initial_seed":0,"overflow_seed":null,"prefix":null,"size":"xs","steps":[],"#
      + #""times":[1700000000000]}}"#,
    missing: nil),
]

private let missingKeys: [StrictCase] = [
  StrictCase(
    kind: .encode,
    line: #"{"expected":"hf7yat0001","id":"encode/x","input":{"case":"lower","compact":true,"#
      + #""prefix":null,"size":"xs","time":1700000000000}}"#,
    missing: "rand"),
  StrictCase(
    kind: .deterministic,
    line: #"{"expected":"z","id":"deterministic/x","input":{"case":"lower","prefix":null,"#
      + #""size":"xs"}}"#,
    missing: "from"),
  StrictCase(
    kind: .decode,
    line: #"{"expected":{"compact":false,"deterministic":false,"prefix":null,"size":"xs"},"#
      + #""id":"decode/x","input":"0000000000"}"#,
    missing: "time"),
  StrictCase(
    kind: .invalid,
    line: #"{"id":"invalid/x","input":{"decode":""}}"#,
    missing: "expected_error"),
  StrictCase(
    kind: .monotonic,
    line: #"{"expected":["hf7yat0000"],"id":"monotonic/x","input":{"compact":true,"#
      + #""initial_seed":0,"overflow_seed":null,"prefix":null,"size":"xs","#
      + #""times":[1700000000000]}}"#,
    missing: "steps"),
]

/// An encode case for size xs in compact time with the given prefix JSON.
private func compactXsCase(prefix: String) -> String {
  #"{"expected":"hf7yat0001","id":"encode/x","input":{"case":"lower","compact":true,"#
    + #""prefix":\#(prefix),"rand":"01","size":"xs","time":1700000000000}}"#
}

/// The message of the reader's refusal of a case, or what happened instead:
/// `nothing thrown`, or `another error` and the error.
private func refusal(_ testCase: StrictCase) -> String {
  do {
    try testCase.run()
    return "nothing thrown"
  } catch let error as CorpusFormatError {
    return error.description
  } catch {
    return "another error: \(error)"
  }
}

/// A null prefix and the empty one, as a case spells them.
private let spellings = ["null", #""""#]

@Suite("Corpus reader")
struct CorpusReaderTests {
  @Test("unknown key (sabotage: done() a no-op -> nothing thrown)", arguments: unknownKeys)
  func rejectsUnknownKey(_ testCase: StrictCase) {
    #expect(refusal(testCase).hasPrefix("unknown key extra"))
  }

  @Test("missing key (sabotage: missing as null -> message differs)", arguments: missingKeys)
  func rejectsMissingKey(_ testCase: StrictCase) {
    #expect(refusal(testCase) == "missing key \(testCase.missing ?? "")")
  }

  @Test("null prefix is none (sabotage: null as \"null\" -> id mismatch)", arguments: spellings)
  func nullPrefixIsNoPrefix(_ prefix: String) throws {
    try CorpusRunner.encode(compactXsCase(prefix: prefix))
  }
}
