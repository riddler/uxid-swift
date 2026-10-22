import Foundation
import Testing
import Uxid

/// The values the README's basic-usage block produces.
private struct ReadmeResults {
  let id: String
  let small: String
  let named: String
  let decoded: Uxid.Decoded
  let refused: Result<Uxid.Decoded, Uxid.DecodeError>
  let valid: Bool
  let first: String
  let second: String
}

// The lines between the two markers are the README's basic-usage block, body
// only: a test below checks the README holds them verbatim, so the example
// cannot drift from code that compiles and runs.
private func readmeExample() throws -> ReadmeResults {
  // README begin
  // A prefix names the resource; the body is a time and randomness.
  let id = try Uxid.generate(Uxid.Options(prefix: "usr"))

  // A smaller size shortens the random part, for low-cardinality resources.
  let small = try Uxid.generate(Uxid.Options(prefix: "cus", size: .s))

  // Deterministic: the same prefix and input give the same id, every time.
  let named = try Uxid.generate(Uxid.Options(prefix: "usr", from: "alice@example.com"))
  // named == "usr_zcvt7epac0t1ebcsjfyf7cwz25"

  // Read an id back. A malformed id is a failure value, never a thrown error.
  let decoded = try Uxid.decode("cus_01hf7yat0004h1").get()
  // decoded.prefix == "cus", decoded.size == .s, decoded.time == 1_700_000_000_000
  let refused = Uxid.decode("cus_")  // .failure(.empty)
  let valid = Uxid.isValid("cus_01hf7yat0004h1", prefix: "cus")  // true

  // Monotonic: ids from one generator increase, also within one millisecond.
  // You hold the generator; the package keeps no global state.
  let ids = Uxid.Monotonic()
  let options = Uxid.Options(prefix: "usr", size: .m)
  let first = try ids.generate(options)
  let second = try ids.generate(options)  // sorts after first
  // README end
  return ReadmeResults(
    id: id, small: small, named: named, decoded: decoded, refused: refused, valid: valid,
    first: first, second: second)
}

@Suite("README")
struct ReadmeTests {
  @Test("the basic-usage block runs (sabotage: small size ignored -> small id length mismatch)")
  func exampleRuns() throws {
    let r = try readmeExample()
    #expect(r.id.hasPrefix("usr_") && r.id.utf8.count == 4 + 26)
    #expect(r.small.hasPrefix("cus_") && r.small.utf8.count == 4 + 14)
    #expect(r.named == "usr_zcvt7epac0t1ebcsjfyf7cwz25")
    #expect(r.decoded.prefix == "cus" && r.decoded.size == .s)
    #expect(r.decoded.time == 1_700_000_000_000)
    #expect(r.refused == .failure(.empty))
    #expect(r.valid)
    #expect(r.first < r.second)
  }

  @Test("the README holds the example verbatim (sabotage: README line edited -> block missing)")
  func readmeHoldsExample() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let source = try String(contentsOf: URL(fileURLWithPath: #filePath), encoding: .utf8)
    let readme = try String(
      contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let begin = try #require(lines.firstIndex { $0.contains("// README begin") })
    let end = try #require(lines.firstIndex { $0.contains("// README end") })
    let body = lines[(begin + 1)..<end].map { $0.hasPrefix("  ") ? String($0.dropFirst(2)) : $0 }
    #expect(!body.isEmpty)
    #expect(readme.contains(body.joined(separator: "\n")))
  }
}
