import Foundation
import Testing
import Uxid

/// One encode case from the conformance corpus: its id, inputs and expected id.
struct EncodeCase: Sendable, CustomTestStringConvertible {
  let id: String
  let prefix: String
  let size: Uxid.Size
  let compact: Bool
  let letterCase: Uxid.Case
  let time: UInt64
  let rand: [UInt8]
  let expected: String

  var testDescription: String { id }
}

/// One generate refusal from the corpus's invalid cases.
struct RefusalCase: Sendable, CustomTestStringConvertible {
  let id: String
  let options: Uxid.Options
  let expected: Uxid.Error

  var testDescription: String { id }
}

/// Reads lowercase hex, as the corpus spells bytes.
private func hex(_ text: String) -> [UInt8] {
  var bytes: [UInt8] = []
  var index = text.startIndex
  while index < text.endIndex {
    let next = text.index(index, offsetBy: 2)
    bytes.append(UInt8(text[index..<next], radix: 16)!)
    index = next
  }
  return bytes
}

private let corpusTime: UInt64 = 1_700_000_000_000

private func encode(
  _ id: String, _ prefix: String, _ size: Uxid.Size, compact: Bool,
  _ letterCase: Uxid.Case = .lower,
  time: UInt64 = corpusTime, rand: String, _ expected: String
) -> EncodeCase {
  EncodeCase(
    id: id, prefix: prefix, size: size, compact: compact, letterCase: letterCase, time: time,
    rand: hex(rand), expected: expected)
}

/// A hand-picked subset of `conformance/encode.json` at uxid-ex v2.10.0, copied
/// case by case (inputs and expected ids unchanged; a `null` prefix is `""`).
private let encodeCases: [EncodeCase] = [
  encode("encode/xs-standard-lower", "usr", .xs, compact: false, rand: "", "usr_01hf7yat00"),
  encode(
    "encode/xs-standard-upper", "usr", .xs, compact: false, .upper, rand: "", "usr_01HF7YAT00"),
  encode("encode/xs-compact-lower", "usr", .xs, compact: true, rand: "01", "usr_hf7yat0001"),
  encode(
    "encode/s-standard-lower", "usr", .s, compact: false, rand: "0123", "usr_01hf7yat0004h1"),
  encode(
    "encode/s-compact-upper", "usr", .s, compact: true, .upper, rand: "012345",
    "usr_HF7YAT0004HM5"),
  encode(
    "encode/m-standard-lower", "usr", .m, compact: false, rand: "0123456789",
    "usr_01hf7yat0004hmasw9"),
  encode(
    "encode/m-compact-lower", "usr", .m, compact: true, rand: "0123456789ab",
    "usr_hf7yat0004hmasw9n3"),
  encode(
    "encode/l-standard-lower", "usr", .l, compact: false, rand: "0123456789abcd",
    "usr_01hf7yat0004hmasw9nf61"),
  encode(
    "encode/l-compact-lower", "usr", .l, compact: true, rand: "0123456789abcdef",
    "usr_hf7yat0004hmasw9nf6yf"),
  encode(
    "encode/xl-standard-upper", "usr", .xl, compact: false, .upper, rand: "0123456789abcdef0123",
    "usr_01HF7YAT0004HMASW9NF6YY093"),
  encode(
    "encode/xl-compact-lower", "usr", .xl, compact: true, rand: "0123456789abcdef0123",
    "usr_hf7yat0004hmasw9nf6yy093"),
  encode(
    "encode/xs-compact-rand-all-ones", "cus", .xs, compact: true, rand: "ff", "cus_hf7yat00z7"),
  encode(
    "encode/s-standard-rand-all-ones", "cus", .s, compact: false, rand: "ffff",
    "cus_01hf7yat00zzz1"),
  encode(
    "encode/l-compact-rand-all-ones", "cus", .l, compact: true, rand: "ffffffffffffffff",
    "cus_hf7yat00zzzzzzzzzzzzf"),
  encode("encode/xs-standard-time-zero", "", .xs, compact: false, time: 0, rand: "", "0000000000"),
  encode(
    "encode/xs-standard-time-max", "", .xs, compact: false, time: 281_474_976_710_655, rand: "",
    "7zzzzzzzzz"),
  encode(
    "encode/s-compact-guard-last-valid", "usr", .s, compact: true, time: 1_065_151_889_407,
    rand: "012345", "usr_yzzzzzzz04hm5"),
  encode(
    "encode/xl-standard-empty-prefix", "", .xl, compact: false, rand: "0123456789abcdef0123",
    "01hf7yat0004hmasw9nf6yy093"),
  encode(
    "encode/s-standard-prefix-with-delimiter", "a_b", .s, compact: false, rand: "0123",
    "a_b_01hf7yat0004h1"),
]

/// The generate refusals of `conformance/invalid.json` at uxid-ex v2.10.0 that
/// need neither a deterministic body nor monotonic generation (an absent
/// option takes its default).
private let refusalCases: [RefusalCase] = [
  RefusalCase(
    id: "invalid/generate-compact-time-at-guard",
    options: Uxid.Options(
      prefix: "usr", size: .s, compactTime: true, time: 2_164_663_517_184, rand: hex("010203")),
    expected: .compactTimeOutOfRange),
  RefusalCase(
    id: "invalid/generate-compact-time-at-guard-previous-window",
    options: Uxid.Options(
      prefix: "usr", size: .s, compactTime: true, time: 1_065_151_889_408, rand: hex("010203")),
    expected: .compactTimeOutOfRange),
  RefusalCase(
    id: "invalid/generate-rand-too-wide",
    options: Uxid.Options(prefix: "usr", size: .s, time: corpusTime, rand: hex("010203")),
    expected: .randWidthMismatch),
  RefusalCase(
    id: "invalid/generate-rand-too-narrow",
    options: Uxid.Options(
      prefix: "usr", size: .xl, time: corpusTime, rand: hex("010203040506070809")),
    expected: .randWidthMismatch),
  RefusalCase(
    id: "invalid/generate-rand-on-xs-standard",
    options: Uxid.Options(prefix: "usr", size: .xs, time: corpusTime, rand: hex("01")),
    expected: .randWidthMismatch),
  RefusalCase(
    id: "invalid/generate-rand-size-11",
    options: Uxid.Options(prefix: "usr", size: .xl, randSize: 11, time: corpusTime),
    expected: .randSizeTooLarge),
]

/// A byte source that records each count it is asked for and answers with
/// that many bytes of `fill`.
final class RecordingSource: Sendable {
  private let counts = Counts()
  let fill: UInt8

  init(fill: UInt8) { self.fill = fill }

  var asked: [Int] { counts.read() }

  var source: Uxid.ByteSource {
    { [counts, fill] count in
      counts.append(count)
      return [UInt8](repeating: fill, count: count)
    }
  }
}

/// A lock-guarded array of counts, so a `@Sendable` source can record them.
final class Counts: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [Int] = []

  func append(_ value: Int) {
    lock.lock()
    values.append(value)
    lock.unlock()
  }

  func read() -> [Int] {
    lock.lock()
    defer { lock.unlock() }
    return values
  }
}

/// Reads a standard time body's first 10 characters back to milliseconds.
private func standardTime(_ body: Substring) -> UInt64 {
  let alphabet = Array("0123456789abcdefghjkmnpqrstvwxyz")
  return body.prefix(10).reduce(0) { value, character in
    (value << 5) | UInt64(alphabet.firstIndex(of: character)!)
  }
}

private let crockford = Set("0123456789abcdefghjkmnpqrstvwxyz")

@Suite("Generate")
struct GenerateTests {
  @Test("encode (sabotage: short group shifted left -> id mismatch)", arguments: encodeCases)
  func corpusEncode(_ testCase: EncodeCase) throws {
    let options = Uxid.Options(
      prefix: testCase.prefix, size: testCase.size, compactTime: testCase.compact,
      case: testCase.letterCase, time: testCase.time, rand: testCase.rand)
    #expect(try Uxid.generate(options) == testCase.expected)
  }

  @Test("refusal (sabotage: no compact marker check -> nothing thrown)", arguments: refusalCases)
  func corpusRefusal(_ testCase: RefusalCase) {
    #expect(throws: testCase.expected) { try Uxid.generate(testCase.options) }
  }

  @Test("error names are corpus spellings (sabotage: rand_size_too_big -> raw values differ)")
  func errorNames() {
    #expect(
      Uxid.Error.allCases.map(\.rawValue) == [
        "compact_time_out_of_range", "rand_width_mismatch", "rand_size_too_large",
        "from_with_monotonic", "rand_with_from", "rand_with_monotonic",
      ])
  }

  @Test("sizes read short and long spellings (sabotage: drop xlarge -> xlarge is nil)")
  func sizeSpellings() {
    let short = ["xs", "s", "m", "l", "xl"].map { Uxid.Size(spelling: $0) }
    let long = ["xsmall", "small", "medium", "large", "xlarge"].map { Uxid.Size(spelling: $0) }
    #expect(short == [.xs, .s, .m, .l, .xl])
    #expect(long == [.xs, .s, .m, .l, .xl])
    #expect(Uxid.Size(spelling: "XL") == nil)
    #expect(Uxid.Size(spelling: "") == nil)
    #expect(Uxid.Size.allCases.map(\.rawValue) == ["xs", "s", "m", "l", "xl"])
  }

  @Test("defaults are xl, standard, lower, no prefix (sabotage: default .l -> asked [7])")
  func defaults() throws {
    let recording = RecordingSource(fill: 0xff)
    let id = try Uxid.generate(Uxid.Options(time: corpusTime, byteSource: recording.source))
    #expect(id == "01hf7yat00zzzzzzzzzzzzzzzz")
    #expect(recording.asked == [10])
  }

  @Test("byte source fills the field (sabotage: ignore source, zeros -> id mismatch)")
  func byteSourceFillsField() throws {
    let recording = RecordingSource(fill: 0xff)
    let options = Uxid.Options(
      prefix: "cus", size: .m, compactTime: true, time: corpusTime, byteSource: recording.source)
    #expect(try Uxid.generate(options) == "cus_hf7yat00zzzzzzzzz7")
    #expect(recording.asked == [6])
  }

  @Test("no draw for fixed bytes or no field (sabotage: always draw -> asked not empty)")
  func noDrawWhenNotNeeded() throws {
    let recording = RecordingSource(fill: 0)
    _ = try Uxid.generate(
      Uxid.Options(size: .s, time: corpusTime, rand: [1, 2], byteSource: recording.source))
    _ = try Uxid.generate(Uxid.Options(size: .xs, time: corpusTime, byteSource: recording.source))
    #expect(recording.asked.isEmpty)
  }

  @Test("explicit rand size sets the width (sabotage: ignore randSize -> asked [2])")
  func explicitRandSize() throws {
    let recording = RecordingSource(fill: 0xff)
    let options = Uxid.Options(
      prefix: "usr", size: .s, randSize: 3, time: corpusTime, byteSource: recording.source)
    #expect(try Uxid.generate(options) == "usr_01hf7yat00zzzzf")
    #expect(recording.asked == [3])
    let zero = Uxid.Options(size: .xl, randSize: 0, time: corpusTime, byteSource: recording.source)
    #expect(try Uxid.generate(zero) == "01hf7yat00")
    #expect(recording.asked == [3])
  }

  @Test("explicit rand size 10 is allowed (sabotage: limit 9 -> outcome is the refusal)")
  func randSizeAtLimit() {
    let options = Uxid.Options(
      size: .s, randSize: 10, time: corpusTime, rand: hex("ffff0000ffff0000ffff"))
    let outcome: String
    do {
      outcome = try Uxid.generate(options)
    } catch {
      outcome = error.rawValue
    }
    #expect(outcome == "01hf7yat00zzzg007zzw001zzz")
  }

  @Test("the delimiter joins prefix and body (sabotage: hard-coded _ -> id mismatch)")
  func delimiter() throws {
    let options = Uxid.Options(
      prefix: "usr", size: .s, delimiter: "--", time: corpusTime, rand: [0x01, 0x23])
    #expect(try Uxid.generate(options) == "usr--01hf7yat0004h1")
    let bare = Uxid.Options(size: .s, delimiter: "--", time: corpusTime, rand: [0x01, 0x23])
    #expect(try Uxid.generate(bare) == "01hf7yat0004h1")
  }

  @Test("prefix is written as given, in bytes (sabotage: uppercase prefix -> id mismatch)")
  func prefixAsGiven() throws {
    let options = Uxid.Options(
      prefix: "Usr\u{e9}", size: .xs, case: .upper, time: corpusTime)
    let id = try Uxid.generate(options)
    #expect(id == "Usr\u{e9}_01HF7YAT00")
    #expect(id.utf8.count == 5 + 1 + 10)
  }

  @Test("no time reads the clock (sabotage: clock returns 0 -> time before window)")
  func clockTime() throws {
    let before = UInt64(Date().timeIntervalSince1970 * 1000) - 1
    let id = try Uxid.generate(Uxid.Options(size: .xs))
    let after = UInt64(Date().timeIntervalSince1970 * 1000) + 1
    let time = standardTime(id[...])
    #expect(before <= time && time <= after)
  }

  @Test("default source gives fresh bytes (sabotage: zero bytes -> ids equal)")
  func systemSource() throws {
    let options = Uxid.Options(prefix: "usr", time: corpusTime)
    let first = try Uxid.generate(options)
    let second = try Uxid.generate(options)
    #expect(first != second)
    for id in [first, second] {
      let body = id.dropFirst(4)
      #expect(body.count == 26)
      #expect(body.allSatisfy { crockford.contains($0) })
      #expect(body.hasPrefix("01hf7yat00"))
    }
  }
}
