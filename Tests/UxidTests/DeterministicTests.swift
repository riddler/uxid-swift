import Testing
import Uxid

/// One deterministic case from the conformance corpus: its inputs and id.
struct DeterministicCase: Sendable, CustomTestStringConvertible {
  let id: String
  let prefix: String
  let from: String
  let size: Uxid.Size
  let letterCase: Uxid.Case
  let expected: String

  var testDescription: String { id }
}

private func derive(
  _ id: String, _ prefix: String, _ from: String, _ size: Uxid.Size,
  case letterCase: Uxid.Case = .lower, _ expected: String
) -> DeterministicCase {
  DeterministicCase(
    id: id, prefix: prefix, from: from, size: size, letterCase: letterCase, expected: expected)
}

private let alice = "alice@example.com"

/// The cases of `conformance/deterministic.json` at uxid-ex v2.10.0, copied
/// case by case (inputs and expected ids unchanged; a `null` prefix is `""`).
private let deterministicCases: [DeterministicCase] = [
  derive(
    "deterministic/golden-usr-xl", "usr", alice, .xl, "usr_zcvt7epac0t1ebcsjfyf7cwz25"),
  derive("deterministic/golden-cus-s", "cus", "acme-corp", .s, "cus_zt9vnyfd85bff0"),
  derive("deterministic/golden-no-prefix-m", "", alice, .m, "zqz4cwzgyw8ks97869"),
  derive("deterministic/usr-xs", "usr", alice, .xs, "usr_z1yhw20vag"),
  derive("deterministic/usr-s", "usr", alice, .s, "usr_z5rtsrkhx2h4dr"),
  derive("deterministic/usr-m", "usr", alice, .m, "usr_zt8naccefxhwnrmscd"),
  derive("deterministic/usr-l", "usr", alice, .l, "usr_zwbz6myvgz7ehe3nceap5n"),
  derive("deterministic/usr-xl", "usr", alice, .xl, "usr_zcvt7epac0t1ebcsjfyf7cwz25"),
  derive("deterministic/empty-prefix-xl", "", alice, .xl, "z4krgegf6drn563pvqhya4tsx9"),
  derive("deterministic/no-prefix-xl", "", alice, .xl, "z4krgegf6drn563pvqhya4tsx9"),
  derive(
    "deterministic/usr-xl-upper", "usr", alice, .xl, case: .upper, "usr_ZCVT7EPAC0T1EBCSJFYF7CWZ25"),
  derive("deterministic/non-ascii-from-m", "cus", "caf\u{e9}", .m, "cus_zfsx9se75671f9kdjv"),
]

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
  @Test("corpus (sabotage: count byte left out -> id mismatch)", arguments: deterministicCases)
  func corpusDeterministic(_ testCase: DeterministicCase) throws {
    let options = Uxid.Options(
      prefix: testCase.prefix, from: testCase.from, size: testCase.size,
      case: testCase.letterCase)
    #expect(try Uxid.generate(options) == testCase.expected)
  }

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
