import Testing
import Uxid

// Runs one conformance case, given as its line of a case file, by the corpus
// README's rule for its kind ("Running the cases"). Each case is read
// strictly (see Fields): a key the runner does not know fails the case, and
// so does a missing one, before anything is generated or decoded. A null
// prefix in a case is no prefix, as the empty string is.

/// Runs the cases of the vendored corpus.
enum CorpusRunner {
  /// The decoder clock of the decode cases, in milliseconds since the Unix
  /// epoch: inside the window the corpus README gives for its compact cases
  /// (1699913600000 ms inclusive to 2164577117183 ms exclusive).
  static let decoderClock: UInt64 = 1_700_000_000_000

  /// An encode case: the id built from the case's input with its fixed
  /// random bytes equals the expected id.
  static func encode(_ line: String) throws {
    var root = try Fields.parse(line)
    _ = try root.string("id")
    var input = try root.object("input")
    let options = Uxid.Options(
      prefix: try input.nullableString("prefix") ?? "",
      size: try size(input.string("size")),
      compactTime: try input.bool("compact"),
      case: try letterCase(input.string("case")),
      time: try time(input.integer("time")),
      rand: try corpusHex(input.string("rand")))
    let expected = try root.string("expected")
    try input.done()
    try root.done()

    let given = outcome { () throws(Uxid.Error) in try Uxid.generate(options) }
    #expect(given == expected)
  }

  /// A deterministic case: the deterministic id of `from` equals the
  /// expected id.
  static func deterministic(_ line: String) throws {
    var root = try Fields.parse(line)
    _ = try root.string("id")
    var input = try root.object("input")
    let options = Uxid.Options(
      prefix: try input.nullableString("prefix") ?? "",
      from: try input.string("from"),
      size: try size(input.string("size")),
      case: try letterCase(input.string("case")))
    let expected = try root.string("expected")
    try input.done()
    try root.done()

    let given = outcome { () throws(Uxid.Error) in try Uxid.generate(options) }
    #expect(given == expected)
  }

  /// A decode case: the string decodes, under the fixed decoder clock, to
  /// the expected prefix, size, compact flag, deterministic flag and time.
  static func decode(_ line: String) throws {
    var root = try Fields.parse(line)
    _ = try root.string("id")
    let text = try root.string("input")
    var expected = try root.object("expected")
    let prefix = try expected.nullableString("prefix")
    let size = try size(expected.string("size"))
    let compact = try expected.bool("compact")
    let deterministic = try expected.bool("deterministic")
    let time = try expected.nullableInteger("time")
    try expected.done()
    try root.done()

    let result = Uxid.decode(text, options: Uxid.DecodeOptions(clock: { decoderClock }))
    let value = try result.get()
    #expect(value.prefix == prefix)
    #expect(value.size == size)
    #expect(value.isCompact == compact)
    #expect(value.isDeterministic == deterministic)
    #expect(value.time == time)
  }

  /// An invalid case: the string is refused with the expected decode reason,
  /// or the generation request (an absent option taking its default) is
  /// refused with the expected generation error.
  static func invalid(_ line: String) throws {
    var root = try Fields.parse(line)
    _ = try root.string("id")
    var input = try root.object("input")
    let expectedError = try root.string("expected_error")
    try root.done()

    if input.has("decode") {
      let text = try input.string("decode")
      try input.done()

      let result = Uxid.decode(text, options: Uxid.DecodeOptions(clock: { decoderClock }))
      switch result {
      case .success(let value):
        Issue.record("decoded to \(value), expected the refusal \(expectedError)")
      case .failure(let reason):
        #expect(reason.rawValue == expectedError)
      }
      return
    }

    var request = try input.object("generate")
    try input.done()
    var options = Uxid.Options()
    if request.has("prefix") { options.prefix = try request.nullableString("prefix") ?? "" }
    if request.has("from") { options.from = try request.string("from") }
    if request.has("size") { options.size = try size(request.string("size")) }
    if request.has("rand_size") { options.randSize = Int(try request.integer("rand_size")) }
    if request.has("compact") { options.compactTime = try request.bool("compact") }
    if request.has("case") { options.case = try letterCase(request.string("case")) }
    if request.has("time") { options.time = try time(request.integer("time")) }
    if request.has("rand") { options.rand = try corpusHex(request.string("rand")) }
    let monotonic = request.has("monotonic") ? try request.bool("monotonic") : false
    try request.done()

    let given = outcome { () throws(Uxid.Error) in
      monotonic ? try Uxid.Monotonic().generate(options) : try Uxid.generate(options)
    }
    #expect(given == "refused \(expectedError)")
  }

  /// A monotonic case: one generator, its draws replaced by the case's
  /// seeds and steps, called once per time, gives the expected ids in order
  /// and draws every value the case carries.
  static func monotonic(_ line: String) throws {
    var root = try Fields.parse(line)
    _ = try root.string("id")
    var input = try root.object("input")
    let prefix = try input.nullableString("prefix") ?? ""
    let size = try size(input.string("size"))
    let compact = try input.bool("compact")
    let times = try input.integers("times").map(time)
    let initialSeed = try input.integer("initial_seed")
    let steps = try input.integers("steps")
    let overflowSeed = try input.nullableInteger("overflow_seed")
    let expected = try root.strings("expected")
    try input.done()
    try root.done()

    let seeds = [initialSeed] + (overflowSeed.map { [$0] } ?? [])
    let draws = ReplayDraws(seeds: try seeds.map(unsigned), steps: try steps.map(unsigned))
    let generator = Uxid.Monotonic(draws: draws.source)
    let ids = times.map { time in
      outcome { () throws(Uxid.Error) in
        try generator.generate(
          Uxid.Options(prefix: prefix, size: size, compactTime: compact, time: time))
      }
    }
    #expect(ids == expected)
    #expect(draws.remaining == 0, "every seed and step the case carries is drawn")
  }

  /// The id a call returns, or `refused` and the corpus name of the error
  /// it throws.
  private static func outcome(_ call: () throws(Uxid.Error) -> String) -> String {
    do {
      return try call()
    } catch {
      return "refused \(error.rawValue)"
    }
  }

  private static func size(_ spelling: String) throws -> Uxid.Size {
    guard let size = Uxid.Size(rawValue: spelling) else {
      throw CorpusFormatError("not a corpus size: \(spelling)")
    }
    return size
  }

  private static func letterCase(_ spelling: String) throws -> Uxid.Case {
    guard let letterCase = Uxid.Case(rawValue: spelling) else {
      throw CorpusFormatError("not a corpus case: \(spelling)")
    }
    return letterCase
  }

  private static func time(_ value: Int64) throws -> UInt64 {
    try unsigned(value)
  }

  private static func unsigned(_ value: Int64) throws -> UInt64 {
    guard let unsigned = UInt64(exactly: value) else {
      throw CorpusFormatError("a negative value: \(value)")
    }
    return unsigned
  }
}
