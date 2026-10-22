extension Uxid {
  /// The latest time an id carries: 2^48 - 1 milliseconds since the Unix
  /// epoch, the most a standard time field holds (in the year 10889).
  ///
  /// ``Uxid/generate(_:)`` requires ``Uxid/Options/time`` to be at most this
  /// value and stops the process when it is not, so a caller holding a time
  /// from outside checks it against this bound first.
  public static let maxTime: UInt64 = (1 << 48) - 1

  /// The low 40 bits a compact time field holds.
  private static let compactMask: UInt64 = (1 << 40) - 1

  /// The widest random field at any size, in bytes.
  private static let maxRandBytes = 10

  /// The deterministic marker's value, which a compact time may not start with.
  private static let marker: UInt64 = 31

  /// Generates an id: the prefix and the delimiter (none for no prefix),
  /// then a time-based body (the time field and the random field) or, when
  /// ``Uxid/Options/from`` is set, a deterministic body (the marker and the
  /// hash characters), as uxid's wire-format specification lays them out.
  ///
  /// ```swift
  /// let id = try Uxid.generate(Uxid.Options(prefix: "usr", size: .s))
  /// // a fresh id such as "usr_01hf7yat0004h1"
  ///
  /// // A fixed time and fixed random bytes, as a reproducible vector:
  /// let vector = try Uxid.generate(
  ///   Uxid.Options(prefix: "usr", size: .s, time: 1_700_000_000_000, rand: [0x01, 0x23]))
  /// // "usr_01hf7yat0004h1"
  ///
  /// // A deterministic id: the same prefix, string and size give it on every call.
  /// let derived = try Uxid.generate(Uxid.Options(prefix: "usr", from: "alice@example.com"))
  /// // "usr_zcvt7epac0t1ebcsjfyf7cwz25"
  /// ```
  ///
  /// The id is built as UTF-8 bytes: the prefix and the delimiter are written
  /// as given, and every body character is one ASCII byte.
  ///
  /// - Parameter options: The options to build the id from; the default takes
  ///   every default (see ``Uxid/Options``).
  /// - Returns: The id, for example `usr_01hf7yat0004hmasw9nf6yy093` at the
  ///   default size.
  /// - Precondition: ``Uxid/Options/delimiter`` is not empty. For a time-based
  ///   id also: ``Uxid/Options/randSize``, when set, is not negative;
  ///   ``Uxid/Options/time`` is at most ``Uxid/maxTime``, or, when it is
  ///   `nil`, the clock reads without failing, no earlier than the Unix epoch
  ///   and no later than ``Uxid/maxTime``; and ``Uxid/Options/byteSource``
  ///   returns exactly the count it is asked for. Each is a programmer error
  ///   that stops the process, not a refusal this function throws.
  /// - Throws: ``Uxid/Error/randWithFrom`` for fixed random bytes beside
  ///   ``Uxid/Options/from``, checked first and the one refusal of a
  ///   deterministic request. For a time-based id,
  ///   ``Uxid/Error/randSizeTooLarge`` for an explicit random field
  ///   width above 10 bytes, ``Uxid/Error/randWidthMismatch`` for fixed random
  ///   bytes of another count than the field's width, and
  ///   ``Uxid/Error/compactTimeOutOfRange`` for a compact time whose first
  ///   character would be the deterministic marker, checked in that order.
  public static func generate(_ options: Options = Options()) throws(Error) -> String {
    precondition(!options.delimiter.utf8.isEmpty, "the delimiter must not be empty")

    if let from = options.from {
      guard options.rand == nil else { throw .randWithFrom }
      return deterministic(from, options)
    }

    let time = options.time ?? clockMilliseconds()
    precondition(time <= maxTime, "the time must be at most 2^48 - 1 milliseconds")

    let compact = options.compactTime ?? false
    var width = options.size.randBytes(compact: compact)
    if let randSize = options.randSize {
      precondition(randSize >= 0, "the random field width must not be negative")
      guard randSize <= maxRandBytes else { throw .randSizeTooLarge }
      width = randSize
    }

    if let rand = options.rand, rand.count != width {
      throw .randWidthMismatch
    }

    let compactTime = time & compactMask
    if compact && compactTime >> 35 == marker {
      throw .compactTimeOutOfRange
    }

    let rand: [UInt8]
    if let fixed = options.rand {
      rand = fixed
    } else if width == 0 {
      rand = []
    } else {
      rand = options.byteSource(width)
      precondition(rand.count == width, "the byte source must return exactly the count asked for")
    }

    var id = start(options)
    if compact {
      Base32.appendInteger(compactTime, characters: 8, case: options.case, to: &id)
    } else {
      Base32.appendInteger(time, characters: 10, case: options.case, to: &id)
    }
    Base32.appendBytes(rand, case: options.case, to: &id)
    return String(decoding: id, as: UTF8.self)
  }

  /// The id's bytes before its body: the prefix and the delimiter, or
  /// nothing for no prefix, with room for the longest body.
  private static func start(_ options: Options) -> [UInt8] {
    var id: [UInt8] = []
    id.reserveCapacity(options.prefix.utf8.count + options.delimiter.utf8.count + 26)
    if !options.prefix.isEmpty {
      id.append(contentsOf: options.prefix.utf8)
      id.append(contentsOf: options.delimiter.utf8)
    }
    return id
  }

  /// Builds the deterministic id of `from` under the options' prefix, size,
  /// case and delimiter (see ``Uxid/Options/from`` for the layout).
  private static func deterministic(_ from: String, _ options: Options) -> String {
    let count = options.size.hashCharacters
    var input: [UInt8] = []
    input.reserveCapacity(options.prefix.utf8.count + from.utf8.count + 3)
    input.append(contentsOf: options.prefix.utf8)
    input.append(0)
    input.append(contentsOf: from.utf8)
    input.append(0)
    input.append(UInt8(count))

    var id = start(options)
    Base32.appendInteger(marker, characters: 1, case: options.case, to: &id)
    Base32.appendLeadingBits(SHA256.hash(input), characters: count, case: options.case, to: &id)
    return String(decoding: id, as: UTF8.self)
  }
}
