extension Uxid {
  /// The latest time a standard time field holds: 2^48 - 1 milliseconds.
  private static let maxTime: UInt64 = (1 << 48) - 1

  /// The low 40 bits a compact time field holds.
  private static let compactMask: UInt64 = (1 << 40) - 1

  /// The widest random field at any size, in bytes.
  private static let maxRandBytes = 10

  /// The deterministic marker's value, which a compact time may not start with.
  private static let marker: UInt64 = 31

  /// Generates a time-based id: the prefix and the delimiter (none for no
  /// prefix), then the time field and the random field, as uxid's wire-format
  /// specification lays them out.
  ///
  /// ```swift
  /// let id = try Uxid.generate(Uxid.Options(prefix: "usr", size: .s))
  /// // a fresh id such as "usr_01hf7yat0004h1"
  ///
  /// // A fixed time and fixed random bytes, as a reproducible vector:
  /// let vector = try Uxid.generate(
  ///   Uxid.Options(prefix: "usr", size: .s, time: 1_700_000_000_000, rand: [0x01, 0x23]))
  /// // "usr_01hf7yat0004h1"
  /// ```
  ///
  /// The id is built as UTF-8 bytes: the prefix and the delimiter are written
  /// as given, and every body character is one ASCII byte.
  ///
  /// - Parameter options: The options to build the id from; the default takes
  ///   every default (see ``Uxid/Options``).
  /// - Returns: The id, for example `usr_01hf7yat0004hmasw9nf6yy093` at the
  ///   default size.
  /// - Throws: ``Uxid/Error/randSizeTooLarge`` for an explicit random field
  ///   width above 10 bytes, ``Uxid/Error/randWidthMismatch`` for fixed random
  ///   bytes of another count than the field's width, and
  ///   ``Uxid/Error/compactTimeOutOfRange`` for a compact time whose first
  ///   character would be the deterministic marker, checked in that order.
  public static func generate(_ options: Options = Options()) throws(Error) -> String {
    precondition(!options.delimiter.utf8.isEmpty, "the delimiter must not be empty")

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

    var id: [UInt8] = []
    id.reserveCapacity(options.prefix.utf8.count + options.delimiter.utf8.count + 26)
    if !options.prefix.isEmpty {
      id.append(contentsOf: options.prefix.utf8)
      id.append(contentsOf: options.delimiter.utf8)
    }
    if compact {
      Base32.appendInteger(compactTime, characters: 8, case: options.case, to: &id)
    } else {
      Base32.appendInteger(time, characters: 10, case: options.case, to: &id)
    }
    Base32.appendBytes(rand, case: options.case, to: &id)
    return String(decoding: id, as: UTF8.self)
  }
}
