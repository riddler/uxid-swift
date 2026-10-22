import Foundation
import Testing

@testable import Uxid

// The vendored corpus is the one its manifest and `conformance/SOURCE.json`
// describe. The hash is recomputed by the reference's rule (the corpus
// README, "The format" and "Running the cases"): the string `sha256:` and the
// lowercase hex SHA-256 of the case files' bytes concatenated in the order of
// the manifest's files; each `case_count` is the number of lines of its file.
// A mismatch means the vendored copy is not the one recorded; it is never
// repaired by rewriting a hash.

/// One entry of the manifest's `files`.
private struct ManifestFile: Equatable {
  let kind: String
  let file: String
  let caseCount: Int
}

/// The manifest, read strictly.
private struct Manifest {
  let version: Int64
  let corpusHash: String
  let files: [ManifestFile]

  static func read() throws -> Manifest {
    let text = String(decoding: try Corpus.bytes("manifest.json"), as: UTF8.self)
    var root = try Fields.parse(text)
    let version = try root.integer("corpus_version")
    let corpusHash = try root.string("corpus_hash")
    let files = try root.array("files").map { entry in
      var fields = try Fields(entry)
      let file = ManifestFile(
        kind: try fields.string("kind"), file: try fields.string("file"),
        caseCount: Int(try fields.integer("case_count")))
      try fields.done()
      return file
    }
    try root.done()
    return Manifest(version: version, corpusHash: corpusHash, files: files)
  }
}

/// `sha256:` and the lowercase hex SHA-256 of the named files' bytes,
/// concatenated in the order given.
private func corpusHash(_ files: [String]) throws -> String {
  var bytes: [UInt8] = []
  for file in files {
    bytes += try Corpus.bytes(file)
  }
  let digits = Array("0123456789abcdef")
  var text = "sha256:"
  for byte in SHA256.hash(bytes) {
    text.append(digits[Int(byte >> 4)])
    text.append(digits[Int(byte & 0x0f)])
  }
  return text
}

private let caseFiles = CaseFile.allCases.map(\.fileName)

@Suite("Corpus hash")
struct CorpusHashTests {
  @Test("files hash to corpus_hash (sabotage: files hashed reversed -> hash mismatch)")
  func corpusHashMatches() throws {
    let manifest = try Manifest.read()
    #expect(try corpusHash(manifest.files.map(\.file)) == manifest.corpusHash)
  }

  @Test("case_count is each file's lines (sabotage: last line dropped -> count mismatch)")
  func caseCounts() throws {
    let manifest = try Manifest.read()
    for entry in manifest.files {
      let file = try #require(CaseFile(rawValue: entry.kind))
      #expect(try Corpus.lines(file).count == entry.caseCount, "\(entry.file)")
      #expect(try Corpus.cases(file).count == entry.caseCount, "\(entry.file)")
    }
  }

  @Test("manifest lists the runner's files (sabotage: order swapped -> files mismatch)")
  func manifestFiles() throws {
    let manifest = try Manifest.read()
    #expect(manifest.version == 1)
    #expect(manifest.files.map(\.file) == caseFiles)
    #expect(manifest.files.map(\.kind) == CaseFile.allCases.map(\.rawValue))
  }

  @Test("SOURCE.json records the tag and hash (sabotage: one byte changed -> hash mismatch)")
  func sourceRecord() throws {
    let text = String(decoding: try Corpus.bytes("SOURCE.json"), as: UTF8.self)
    var source = try Fields.parse(text)
    let repo = try source.string("repo")
    let tag = try source.string("tag")
    let sha = try source.string("sha")
    let recorded = try source.string("corpus_hash")
    try source.done()

    #expect(repo == "riddler/uxid-ex")
    #expect(tag.hasPrefix("v"))
    #expect(sha.count == 40 && sha.allSatisfy { "0123456789abcdef".contains($0) })
    #expect(recorded == (try Manifest.read().corpusHash))
    #expect(recorded == (try corpusHash(caseFiles)))
  }

  @Test("case files use newline endings (sabotage: a carriage return added -> CR found)")
  func newlineEndings() throws {
    for file in caseFiles {
      #expect(!(try Corpus.bytes(file)).contains(UInt8(ascii: "\r")), "\(file)")
    }
  }
}
