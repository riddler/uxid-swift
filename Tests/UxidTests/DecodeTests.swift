import Testing
import Uxid

private let corpusTime: Int64 = 1_700_000_000_000

/// A clock fixed at the corpus time, inside the corpus clock window.
private let corpusClock: @Sendable () -> UInt64 = { 1_700_000_000_000 }

/// The low 40 bits of a compact time: one window of 2^40 milliseconds.
private let window: Int64 = 1 << 40

/// One day in milliseconds, the most a compact time may be ahead of the clock.
private let oneDay: Int64 = 86_400_000

/// The compact guard's last valid millisecond: the largest compact time field.
private let guardLastValid: Int64 = 1_065_151_889_407

/// The decoded value, or `nil` when the string was refused.
private func decoded(
  _ id: String, delimiter: String = "_", clock: @escaping @Sendable () -> UInt64 = corpusClock
) -> Uxid.Decoded? {
  try? Uxid.decode(id, options: Uxid.DecodeOptions(delimiter: delimiter, clock: clock)).get()
}

/// The corpus name of the reason a string was refused, or `nil` when it decoded.
private func reason(_ id: String, delimiter: String = "_") -> String? {
  switch Uxid.decode(id, options: Uxid.DecodeOptions(delimiter: delimiter, clock: corpusClock)) {
  case .success: return nil
  case .failure(let error): return error.rawValue
  }
}

/// The time a compact body decodes to under a fixed clock.
private func compactTime(_ id: String, clock: Int64) -> Int64? {
  decoded(id, clock: { UInt64(clock) })?.time
}

@Suite("Decode")
struct DecodeTests {
  @Test("reasons are corpus spellings (sabotage: invalid_chars -> raw values differ)")
  func reasonSpellings() {
    #expect(
      Uxid.DecodeError.allCases.map(\.rawValue) == ["empty", "invalid_length", "invalid_character"])
  }

  @Test("10 and 18 read as standard (sabotage: 10 read as compact -> isCompact true)")
  func ambiguousLengthsAreStandard() throws {
    let xs = try #require(decoded("usr_hf7yat0001"))
    #expect(xs.size == .xs)
    #expect(!xs.isCompact)
    #expect(xs.time == 51_950_139_736_065)
    let m = try #require(decoded("usr_hf7yat0004hmasw9n3"))
    #expect(m.size == .m)
    #expect(!m.isCompact)
    #expect(m.time == 51_950_139_736_068)
  }

  @Test("clock window start is inclusive (sabotage: > oneDay as >= -> start differs)")
  func clockWindowStart() {
    // The cases at the corpus time are recovered by a clock no more than one
    // day behind them, which sets the start.
    let start = corpusTime - oneDay
    #expect(start == 1_699_913_600_000)
    #expect(compactTime("usr_hf7yat0004hm5", clock: start) == corpusTime)
    #expect(compactTime("usr_hf7yat0004hm5", clock: start - 1) == corpusTime - window)
  }

  @Test("clock window end is exclusive (sabotage: > oneDay as >= -> end differs)")
  func clockWindowEnd() {
    // The guard's last valid compact time from the window before is
    // recovered while 2^40 + it is more than one day ahead of the clock.
    let end = window + guardLastValid - oneDay
    #expect(end == 2_164_577_117_183)
    #expect(compactTime("usr_yzzzzzzz04hm5", clock: end - 1) == guardLastValid)
    #expect(compactTime("usr_yzzzzzzz04hm5", clock: end) == window + guardLastValid)
  }

  @Test("first window steps back below zero (sabotage: clamp at 0 -> time is positive)")
  func firstWindowGoesNegative() {
    // The low 40 bits of the corpus time, more than one day ahead of a clock
    // near the epoch, step back one window to a negative time.
    let low = corpusTime - window
    #expect(compactTime("usr_hf7yat0004hm5", clock: 0) == low - window)
    #expect(compactTime("usr_hf7yat0004hm5", clock: 1_000) == -499_023_255_552)
    #expect(compactTime("usr_hf7yat0004hm5", clock: low - oneDay) == low)
  }

  @Test("clock read for compact time only (sabotage: clock read up front -> asked [0, ...])")
  func clockReadOnlyForCompactTime() {
    let counts = Counts()
    let clock: @Sendable () -> UInt64 = {
      counts.append(0)
      return 1_700_000_000_000
    }
    for id in [
      "usr_01hf7yat0004h1", "usr_zt9vnyfd85bff0", "usr_hf7yat0001", "usr_", "usr_01hf7yat000",
      "usr_zzzzzzzzzzzzz",
    ] {
      _ = decoded(id, clock: clock)
    }
    #expect(counts.read().isEmpty)
    _ = decoded("usr_hf7yat0004hm5", clock: clock)
    #expect(counts.read() == [0])
  }

  @Test("garbage is refused, never a trap (sabotage: no empty case -> reason differs)")
  func garbageIsRefused() {
    #expect(reason("") == "empty")
    #expect(reason("_") == "empty")
    #expect(reason("___") == "empty")
    #expect(reason(String(repeating: "0", count: 1_000_000)) == "invalid_length")
    #expect(reason(String(repeating: "\u{1F600}", count: 6)) == "invalid_character")
    #expect(reason(String(repeating: "\u{e9}", count: 7)) == "invalid_character")
    #expect(reason("\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}") == "invalid_character")
    #expect(reason("usr_01hf7yat0\u{301}") == "invalid_length")
    #expect(reason("\u{301}", delimiter: "\u{e9}") == "invalid_length")
  }

  @Test("splits at the last delimiter (sabotage: split at the first -> decode refused)")
  func splitsAtLastDelimiter() throws {
    let colons = try #require(decoded("usr::a::01hf7yat0004h1", delimiter: "::"))
    #expect(colons.prefix == "usr::a")
    #expect(colons.size == .s)
    #expect(decoded("usr-01hf7yat0004h1", delimiter: "-")?.prefix == "usr")
    #expect(decoded("usr-01hf7yat0004h1")?.prefix == nil)
    // Matched from the left without overlap, as the reference splits.
    #expect(reason("a___01hf7yat0004h1", delimiter: "__") == "invalid_length")
    #expect(decoded("_01hf7yat0004h1")?.prefix == "")
    #expect(decoded("caf\u{e9}_01hf7yat0004h1")?.prefix == "caf\u{e9}")
  }

  @Test("isValid checks body and prefix (sabotage: prefix check dropped -> usr is true)")
  func isValid() {
    let id = "cus_01hf7yat0004h1"
    #expect(Uxid.isValid(id))
    #expect(Uxid.isValid(id, prefix: "cus"))
    #expect(!Uxid.isValid(id, prefix: "usr"))
    #expect(Uxid.isValid(id, prefix: ""))
    #expect(!Uxid.isValid("01hf7yat0004h1", prefix: "cus"))
    #expect(Uxid.isValid("01hf7yat0004h1"))
    #expect(!Uxid.isValid(id, delimiter: "-"))
    #expect(Uxid.isValid("cus-01hf7yat0004h1", delimiter: "-", prefix: "cus"))
    #expect(!Uxid.isValid("cus_01hf7yat0004h12"))
    #expect(!Uxid.isValid("cus_01hf7yat0004hl"))
    #expect(!Uxid.isValid("cus_"))
    #expect(Uxid.isValid("usr_zcvt7epac0t1ebcsjfyf7cwz25", prefix: "usr"))
  }

  @Test("isValid compares prefix bytes (sabotage: String == -> decomposed e is true)")
  func isValidComparesBytes() {
    let id = "caf\u{e9}_01hf7yat0004h1"
    #expect(Uxid.isValid(id, prefix: "caf\u{e9}"))
    #expect(!Uxid.isValid(id, prefix: "cafe\u{301}"))
  }

  @Test("isDeterministic needs a well-formed marker body (sabotage: marker only -> true)")
  func isDeterministic() {
    #expect(Uxid.isDeterministic("usr_zcvt7epac0t1ebcsjfyf7cwz25"))
    #expect(Uxid.isDeterministic("usr_ZCVT7EPAC0T1EBCSJFYF7CWZ25"))
    #expect(Uxid.isDeterministic("zqz4cwzgyw8ks97869"))
    #expect(!Uxid.isDeterministic("usr_01hf7yat0004h1"))
    #expect(!Uxid.isDeterministic("usr_zcvt7epac0t1ebcsjfyf7cwz2"))
    #expect(!Uxid.isDeterministic("usr_zcvt7epac0t1ebcsjfyf7cwzi5"))
    #expect(!Uxid.isDeterministic("usr_"))
    #expect(!Uxid.isDeterministic("usr-zcvt7epac0t1ebcsjfyf7cwz25"))
    #expect(Uxid.isDeterministic("usr-zcvt7epac0t1ebcsjfyf7cwz25", delimiter: "-"))
  }

  @Test("default options take _ and the system clock (sabotage: default \"-\" -> prefix nil)")
  func defaultOptions() throws {
    let value = try? Uxid.decode("usr_01hf7yat0004h1").get()
    #expect(value?.prefix == "usr")
    #expect(value?.time == corpusTime)
    // A compact time read on the system clock lands within one window of it.
    let now = try Uxid.decode(Uxid.generate(Uxid.Options(size: .s, compactTime: true))).get()
    #expect(now.isCompact)
    #expect(now.time.map { $0 > corpusTime } == true)
  }
}
