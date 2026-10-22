import Testing
import Uxid

private let alice = "alice@example.com"

/// The id a call returns, or the corpus name of the error it throws.
private func outcome(_ options: Uxid.Options) -> String {
  do {
    return try Uxid.generate(options)
  } catch {
    return error.rawValue
  }
}

@Suite("Deterministic")
struct DeterministicTests {
  @Test("rand with from is refused (sabotage: rand check removed -> outcome is an id)")
  func randWithFrom() {
    // The corpus case invalid/generate-rand-with-from, then the empty array.
    let corpusRand: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    #expect(outcome(Uxid.Options(prefix: "usr", from: alice, rand: corpusRand)) == "rand_with_from")
    #expect(outcome(Uxid.Options(prefix: "usr", from: alice, rand: [])) == "rand_with_from")
  }

  @Test("time options are not read (sabotage: from after width check -> outcome is refusal)")
  func timeOptionsNotRead() {
    let recording = RecordingSource(fill: 0)
    let options = Uxid.Options(
      prefix: "usr", from: alice, randSize: 11, compactTime: true, time: 2_164_663_517_184,
      byteSource: recording.source)
    #expect(outcome(options) == "usr_zcvt7epac0t1ebcsjfyf7cwz25")
    #expect(recording.asked.isEmpty)
  }

  @Test("the delimiter joins prefix and body (sabotage: hard-coded _ -> id mismatch)")
  func delimiter() throws {
    let options = Uxid.Options(prefix: "usr", from: alice, delimiter: "--")
    #expect(try Uxid.generate(options) == "usr--zcvt7epac0t1ebcsjfyf7cwz25")
  }

  @Test("the empty string is derived from (sabotage: empty from read as nil -> time-based id)")
  func emptyFrom() throws {
    #expect(
      try Uxid.generate(Uxid.Options(prefix: "usr", from: "")) == "usr_z5006zc7jgfjwsjagnepj46p6x")
  }

  @Test("maxTime is 2^48 - 1 (sabotage: bound 2^48 -> value differs)")
  func maxTime() throws {
    #expect(Uxid.maxTime == 281_474_976_710_655)
    let options = Uxid.Options(size: .xs, time: Uxid.maxTime)
    #expect(try Uxid.generate(options) == "7zzzzzzzzz")
  }
}
