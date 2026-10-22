extension Uxid {
  /// Why ``Uxid/decode(_:options:)`` refused a string, named as the
  /// conformance corpus names it.
  ///
  /// The cases are a closed set: each is one refusal reason the wire-format
  /// specification lists, and its `rawValue` is that reason's spelling in the
  /// corpus, such as `invalid_length`. A body that breaks more than one rule
  /// is refused for the first it breaks, in the order of the cases below.
  ///
  /// It is a type of its own beside ``Uxid/Error``, which names the
  /// generation refusals only.
  public enum DecodeError: String, Swift.Error, Sendable, Hashable, CaseIterable {
    /// The body is empty: the string is empty or ends in the delimiter.
    case empty

    /// The body's length in UTF-8 bytes is not one of the body lengths a
    /// size gives (10, 13, 14, 18, 21, 22, 24 or 26).
    case invalidLength = "invalid_length"

    /// A body character is not a Crockford Base32 symbol in either case. The
    /// letters `I`, `L`, `O` and `U` are not symbols, and no reading
    /// substitution is applied.
    case invalidCharacter = "invalid_character"
  }

  /// What a well-formed id says about itself, as ``Uxid/decode(_:options:)``
  /// reads it: its prefix, the size and time form its body length gives,
  /// whether its body is deterministic, and the time it carries.
  ///
  /// The random field and the hash characters are not read back.
  public struct Decoded: Sendable, Hashable {
    /// Everything before the last delimiter, or `nil` when the string has no
    /// delimiter. A string that starts with the delimiter, which no producer
    /// emits, has the empty prefix, best read as no prefix.
    public let prefix: String?

    /// The size the body length gives.
    public let size: Size

    /// Whether the body length is a compact-time one (13, 21 or 24).
    ///
    /// The lengths 10 and 18 are always read as standard time, so a compact
    /// ``Uxid/Size/xs`` or compact ``Uxid/Size/m`` id decodes with this
    /// `false` and a time read from its first 10 body characters, not the
    /// time it was generated at.
    public let isCompact: Bool

    /// Whether the body starts with the deterministic marker `z` or `Z`.
    public let isDeterministic: Bool

    /// The time in milliseconds since the Unix epoch, or `nil` for a
    /// deterministic body, which carries none.
    ///
    /// A compact time's bits above the low 40 come from the decoder's clock
    /// (see ``Uxid/DecodeOptions/clock``). The time is negative when that
    /// clock is in the first 2^40 milliseconds after the Unix epoch and the
    /// compact time is more than one day ahead of it.
    public let time: Int64?
  }

  /// The options ``Uxid/decode(_:options:)`` reads a string with.
  ///
  /// `Uxid.DecodeOptions()` takes the delimiter `_` and the platform's
  /// real-time clock.
  public struct DecodeOptions: Sendable {
    /// The delimiter the string is split at; the default is `_`. An id does
    /// not record its delimiter, so this must be the one it was generated
    /// with.
    ///
    /// - Precondition: Not empty.
    public var delimiter: String

    /// The decoder's clock: the current time in milliseconds since the Unix
    /// epoch. The default reads the platform's real-time clock.
    ///
    /// A compact body carries only the low 40 bits of its time; the decoder
    /// takes the bits above them from this clock, and when the result is
    /// more than one day (86400000 ms) ahead of the clock it subtracts one
    /// window of 2^40 milliseconds, with no floor at zero. The time comes back
    /// exact while the id and the clock fall in the same 2^40 ms window
    /// (about 34.8 years) and the id is no more than one day ahead of the
    /// clock; an id from the window before is recovered while it is less
    /// than 2^40 ms minus one day older than the clock.
    ///
    /// A fixed clock, such as `{ 1_700_000_000_000 }`, makes a compact time's
    /// reading reproducible. The clock is called once per compact time-based
    /// body, and not at all for a standard or deterministic body or a refused
    /// string.
    ///
    /// - Precondition: The clock reads at most ``Uxid/maxTime``, and the
    ///   default reads without failing and no earlier than the Unix epoch.
    public var clock: @Sendable () -> UInt64

    /// Creates options for ``Uxid/decode(_:options:)``; each argument defaults
    /// as its property says.
    ///
    /// - Parameters:
    ///   - delimiter: The delimiter the string is split at.
    ///   - clock: The decoder's clock, in milliseconds since the Unix epoch.
    public init(
      delimiter: String = "_",
      clock: @escaping @Sendable () -> UInt64 = Uxid.clockMilliseconds
    ) {
      self.delimiter = delimiter
      self.clock = clock
    }
  }

  /// One day in milliseconds: how far ahead of the decoder's clock a compact
  /// time may be before it is read as the window before.
  private static let oneDay: Int64 = 86_400_000

  /// One compact window: 2^40 milliseconds.
  private static let compactWindow: Int64 = 1 << 40

  /// Reads a string as an id: its prefix, size, time form, whether it is
  /// deterministic and its time, as uxid's wire-format specification
  /// decodes them.
  ///
  /// ```swift
  /// let decoded = try Uxid.decode("usr_01hf7yat0004h1").get()
  /// // decoded.prefix == "usr", decoded.size == .s, decoded.time == 1_700_000_000_000
  ///
  /// switch Uxid.decode("usr_01hf7yat000") {
  /// case .success(let decoded): print(decoded.size)
  /// case .failure(let reason): print(reason.rawValue)  // "invalid_length"
  /// }
  /// ```
  ///
  /// The body is everything after the last delimiter, and the prefix
  /// everything before it; a string with no delimiter is a body with no
  /// prefix. The body's length in UTF-8 bytes gives the size and the time
  /// form; the lengths 10 and 18 are read as standard time. A body that
  /// starts with `z` or `Z` is deterministic and carries no time.
  ///
  /// Any string is a value to classify: a malformed one comes back as a
  /// failure, never as a thrown error or a stop.
  ///
  /// - Parameters:
  ///   - id: The string to read.
  ///   - options: The delimiter and the clock; the default takes `_` and the
  ///     platform's real-time clock (see ``Uxid/DecodeOptions``).
  /// - Returns: The decoded id, or the reason it was refused:
  ///   ``Uxid/DecodeError/empty``, ``Uxid/DecodeError/invalidLength`` or
  ///   ``Uxid/DecodeError/invalidCharacter``, checked in that order.
  /// - Precondition: ``Uxid/DecodeOptions/delimiter`` is not empty, and for a
  ///   compact time-based body the clock reads at most ``Uxid/maxTime``.
  ///   Each is a programmer error that stops the process.
  public static func decode(
    _ id: String, options: DecodeOptions = DecodeOptions()
  ) -> Result<Decoded, DecodeError> {
    let (prefix, body) = split(id, options.delimiter)
    let shape: (size: Size, compact: Bool)
    switch wellFormed(body) {
    case .failure(let reason): return .failure(reason)
    case .success(let found): shape = found
    }

    let deterministic = body[0] == UInt8(ascii: "z") || body[0] == UInt8(ascii: "Z")
    var time: Int64?
    if deterministic {
      time = nil
    } else if shape.compact {
      time = compactTime(Base32.readInteger(body, from: 0, characters: 8), options.clock)
    } else {
      let high = Base32.readInteger(body, from: 0, characters: 1) & 7
      time = Int64(high << 45 | Base32.readInteger(body, from: 1, characters: 9))
    }

    return .success(
      Decoded(
        prefix: prefix, size: shape.size, isCompact: shape.compact,
        isDeterministic: deterministic, time: time))
  }

  /// Answers whether a string is a well-formed id under a delimiter, one
  /// ``Uxid/decode(_:options:)`` would decode, and, given a required prefix,
  /// whether it carries exactly that prefix.
  ///
  /// ```swift
  /// Uxid.isValid("cus_01hf7yat0004h1")                  // true
  /// Uxid.isValid("cus_01hf7yat0004h1", prefix: "cus")   // true
  /// Uxid.isValid("cus_01hf7yat0004h1", prefix: "usr")   // false
  /// Uxid.isValid("cus-01hf7yat0004h1", delimiter: "-")  // true
  /// ```
  ///
  /// This checks structure, not origin: any well-formed string passes. It
  /// reads no clock. The prefixes are compared as UTF-8 bytes, so two
  /// spellings of one accented letter are different prefixes. The body must
  /// have one of the lengths a size gives, which is stricter than the Elixir
  /// reference's `valid?`, whose body need only be 8 alphabet characters or
  /// more; the conformance corpus does not fix this answer.
  ///
  /// - Parameters:
  ///   - id: The string to check.
  ///   - delimiter: The delimiter the id was generated with; the default is
  ///     `_`.
  ///   - prefix: The prefix the id must carry; `nil`, the default, and the
  ///     empty string accept any prefix or none. A required prefix is never
  ///     met by a string with no delimiter.
  /// - Returns: `true` when the id is well formed and carries the required
  ///   prefix.
  /// - Precondition: `delimiter` is not empty.
  public static func isValid(_ id: String, delimiter: String = "_", prefix: String? = nil) -> Bool {
    let (actual, body) = split(id, delimiter)
    guard case .success = wellFormed(body) else { return false }
    guard let required = prefix, !required.isEmpty else { return true }
    guard let actual else { return false }
    return actual.utf8.elementsEqual(required.utf8)
  }

  /// Answers whether a string is a well-formed deterministic id under a
  /// delimiter: one ``Uxid/decode(_:options:)`` would decode whose body
  /// starts with the marker `z` or `Z`.
  ///
  /// ```swift
  /// Uxid.isDeterministic("usr_zcvt7epac0t1ebcsjfyf7cwz25")  // true
  /// Uxid.isDeterministic("usr_01hf7yat0004h1")              // false
  /// ```
  ///
  /// A malformed string is not deterministic, whatever its first body
  /// character, which is stricter than the Elixir reference's
  /// `deterministic?`, which reads the first body character only; the
  /// conformance corpus does not fix this answer. It reads no clock.
  ///
  /// - Parameters:
  ///   - id: The string to check.
  ///   - delimiter: The delimiter the id was generated with; the default is
  ///     `_`.
  /// - Returns: `true` when the id is well formed and deterministic.
  /// - Precondition: `delimiter` is not empty.
  public static func isDeterministic(_ id: String, delimiter: String = "_") -> Bool {
    let (_, body) = split(id, delimiter)
    guard case .success = wellFormed(body) else { return false }
    return body[0] == UInt8(ascii: "z") || body[0] == UInt8(ascii: "Z")
  }

  /// Splits a string at the last occurrence of the delimiter, matched as
  /// UTF-8 bytes from the left without overlap: the prefix before it (`nil`
  /// with no delimiter) and the body's bytes after it.
  private static func split(_ id: String, _ delimiter: String) -> (String?, [UInt8]) {
    let mark = Array(delimiter.utf8)
    precondition(!mark.isEmpty, "the delimiter must not be empty")
    let bytes = Array(id.utf8)
    var last: Int?
    var index = 0
    while index + mark.count <= bytes.count {
      if bytes[index..<(index + mark.count)].elementsEqual(mark) {
        last = index
        index += mark.count
      } else {
        index += 1
      }
    }
    guard let last else { return (nil, bytes) }
    // A match of a whole UTF-8 sequence starts and ends on scalar boundaries,
    // so the prefix's bytes decode back to exactly the text before it.
    return (String(decoding: bytes[..<last], as: UTF8.self), Array(bytes[(last + mark.count)...]))
  }

  /// The first rule a body breaks, in the order empty, length in bytes,
  /// alphabet; or, for a well-formed body, the size and time form its length
  /// gives.
  private static func wellFormed(_ body: [UInt8]) -> Result<
    (size: Size, compact: Bool), DecodeError
  > {
    let shape: (size: Size, compact: Bool)
    switch body.count {
    case 0: return .failure(.empty)
    case 10: shape = (.xs, false)
    case 13: shape = (.s, true)
    case 14: shape = (.s, false)
    case 18: shape = (.m, false)
    case 21: shape = (.l, true)
    case 22: shape = (.l, false)
    case 24: shape = (.xl, true)
    case 26: shape = (.xl, false)
    default: return .failure(.invalidLength)
    }
    for byte in body where Base32.value(byte) == nil {
      return .failure(.invalidCharacter)
    }
    return .success(shape)
  }

  /// The full time of a compact body: its low 40 bits under the clock's
  /// higher bits, less one window when that lands more than one day ahead of
  /// the clock. There is no floor at zero, so a clock in the first window can
  /// give a negative time.
  private static func compactTime(_ low: UInt64, _ clock: @Sendable () -> UInt64) -> Int64 {
    let now = clock()
    precondition(now <= maxTime, "the decoder's clock must read at most 2^48 - 1 milliseconds")
    let current = Int64(now)
    let time = (current & ~(compactWindow - 1)) | Int64(low)
    return time - current > oneDay ? time - compactWindow : time
  }
}
