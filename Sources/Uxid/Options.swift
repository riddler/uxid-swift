extension Uxid {
  /// An id's size, which fixes the random field's width and so the body
  /// length.
  ///
  /// Random bytes and body lengths per size, in standard and compact time:
  /// `xs` 0 and 1 bytes, 10 and 10 characters; `s` 2 and 3 bytes, 14 and 13
  /// characters; `m` 5 and 6 bytes, 18 and 18 characters; `l` 7 and 8 bytes,
  /// 22 and 21 characters; `xl` 10 and 10 bytes, 26 and 24 characters. The
  /// default size of ``Uxid/Options`` is ``xl``.
  ///
  /// The `rawValue` is the short spelling; ``init(spelling:)`` also reads the
  /// long ones.
  public enum Size: String, Sendable, Hashable, CaseIterable {
    /// Extra small (`xs` or `xsmall`): no random field in standard time.
    case xs

    /// Small (`s` or `small`).
    case s

    /// Medium (`m` or `medium`).
    case m

    /// Large (`l` or `large`).
    case l

    /// Extra large (`xl` or `xlarge`), the default.
    case xl

    /// Reads a size from its short spelling (`xs`, `s`, `m`, `l`, `xl`) or
    /// its long one (`xsmall`, `small`, `medium`, `large`, `xlarge`), in
    /// lower case exactly.
    ///
    /// - Parameter spelling: The spelling to read.
    public init?(spelling: String) {
      switch spelling {
      case "xs", "xsmall": self = .xs
      case "s", "small": self = .s
      case "m", "medium": self = .m
      case "l", "large": self = .l
      case "xl", "xlarge": self = .xl
      default: return nil
      }
    }

    /// The random field's width in bytes at this size, in compact or
    /// standard time.
    func randBytes(compact: Bool) -> Int {
      switch self {
      case .xs: return compact ? 1 : 0
      case .s: return compact ? 3 : 2
      case .m: return compact ? 6 : 5
      case .l: return compact ? 8 : 7
      case .xl: return 10
      }
    }

    /// The number of hash characters a deterministic body carries at this
    /// size, after its marker, so the body has this size's standard length.
    var hashCharacters: Int {
      switch self {
      case .xs: return 9
      case .s: return 13
      case .m: return 17
      case .l: return 21
      case .xl: return 25
      }
    }
  }

  /// The letter case of an id's body. Case never applies to the prefix.
  ///
  /// The `rawValue` is the spelling the conformance corpus uses.
  public enum Case: String, Sendable, Hashable, CaseIterable {
    /// Lower case, the default: `usr_01hf7yat00`.
    case lower

    /// Upper case: `usr_01HF7YAT00`.
    case upper
  }

  /// A source of random bytes: given a count, it returns exactly that many.
  ///
  /// The bytes are the only unpredictable part of a time-based id, so a source
  /// must be cryptographically secure for any id that must not be guessed.
  /// The default, ``Uxid/Options/byteSource``'s, reads
  /// `SystemRandomNumberGenerator`, the platform's secure generator. A source
  /// does not throw: the default cannot fail (the standard library stops the
  /// process when the platform generator does), and the closed set of
  /// ``Uxid/Error`` names no failure of a source.
  public typealias ByteSource = @Sendable (Int) -> [UInt8]

  /// The options ``Uxid/generate(_:)`` builds an id from.
  ///
  /// Every property has a default, so `Uxid.Options()` asks for a time-based
  /// id with no prefix, size ``Uxid/Size/xl``, the size's random field width,
  /// standard time, lower case, the delimiter `_`, the current time and random
  /// bytes from `SystemRandomNumberGenerator`. Setting ``from`` asks for a
  /// deterministic id instead.
  ///
  /// A property that states a precondition is a programmer error when broken:
  /// ``Uxid/generate(_:)`` stops the process rather than throwing, since the
  /// closed set of ``Uxid/Error`` names only the refusals the wire format
  /// lists. A caller holding a value from outside checks it first; for the
  /// time, against ``Uxid/maxTime``.
  public struct Options: Sendable {
    /// The resource prefix, written before the delimiter exactly as given
    /// (case never applies to it). It may contain the delimiter. The empty
    /// string, the default, is no prefix: the id is the bare body, with no
    /// delimiter.
    public var prefix: String

    /// The string a deterministic id is derived from; `nil`, the default,
    /// builds a time-based id. The empty string is a string to derive from,
    /// not none.
    ///
    /// The body is the marker (`z`, or `Z` in upper case) and the first
    /// 5 bits per hash character of the SHA-256 digest of the prefix's UTF-8
    /// bytes (none for no prefix), a zero byte, this string's UTF-8 bytes, a
    /// zero byte and one byte holding the count of hash characters. The size
    /// sets that count: ``Uxid/Size/xs`` 9, ``Uxid/Size/s`` 13,
    /// ``Uxid/Size/m`` 17, ``Uxid/Size/l`` 21 and ``Uxid/Size/xl`` 25, so the
    /// body has a standard body's length, and the same string at two sizes or
    /// under two prefixes gives unrelated bodies. ``case`` and ``delimiter``
    /// apply as they do to a time-based id; case is not part of the hash
    /// input.
    ///
    /// A deterministic id carries no time and no random field, so ``time``,
    /// ``compactTime``, ``randSize`` and ``byteSource`` are not read (there is
    /// no compact deterministic form), and ``rand`` set beside this property
    /// is refused with ``Uxid/Error/randWithFrom``. ``Uxid/Monotonic`` refuses
    /// this property with ``Uxid/Error/fromWithMonotonic``.
    ///
    /// The id is exactly as guessable as the string: anyone who knows the
    /// prefix, the string and the size can build it.
    public var from: String?

    /// The size, which fixes the random field's width and so the body
    /// length. The default is ``Uxid/Size/xl``.
    public var size: Size

    /// An explicit random field width in bytes, from 0 to 10, in place of the
    /// size's width; `nil`, the default, takes the size's width.
    ///
    /// Above 10 is refused with ``Uxid/Error/randSizeTooLarge``. A body of a
    /// width the size table does not list has the same layout, but its length
    /// is one a decoder refuses.
    ///
    /// Not read for a deterministic id (``from``).
    ///
    /// - Precondition: Not negative.
    public var randSize: Int?

    /// Whether the time field is compact: the low 40 bits of the time in 8
    /// characters, in place of the 48-bit standard time in 10, the freed 8
    /// bits going to the random field at every size but ``Uxid/Size/xl``.
    ///
    /// `nil`, the default, is standard time, as `false` is, except to
    /// ``Uxid/Monotonic``, which reads `nil` at size ``Uxid/Size/xs`` as
    /// compact time. A compact time
    /// whose first character would be the deterministic marker is refused
    /// with ``Uxid/Error/compactTimeOutOfRange``. Not read for a
    /// deterministic id (``from``).
    public var compactTime: Bool?

    /// The letter case of the body. The default is ``Uxid/Case/lower``.
    public var `case`: Case

    /// The delimiter written between the prefix and the body; the default is
    /// `_`. It is not recorded in the id, so a reader must be told the same
    /// one. A delimiter made of alphabet characters makes an id ambiguous to
    /// read and is not supported.
    ///
    /// - Precondition: Not empty, for a time-based and a deterministic id
    ///   alike.
    public var delimiter: String

    /// The time the id carries, in milliseconds since the Unix epoch; `nil`,
    /// the default, reads the platform's real-time clock at the call. Not
    /// read for a deterministic id (``from``).
    ///
    /// - Precondition: At most ``Uxid/maxTime`` (2^48 - 1), the latest time a
    ///   standard time field holds. When it is `nil`, the clock must read
    ///   without failing, no earlier than the Unix epoch and no later than
    ///   ``Uxid/maxTime``.
    public var time: UInt64?

    /// Fixed bytes for the random field, for reproducible vectors such as
    /// the conformance corpus and tests; `nil`, the default, draws the bytes
    /// from ``byteSource``.
    ///
    /// They are never a source of randomness: an id built from them is
    /// exactly as guessable as the bytes. Their count must equal the random
    /// field's width (the size's, or ``randSize``), or the request is refused
    /// with ``Uxid/Error/randWidthMismatch``; size ``Uxid/Size/xs`` in
    /// standard time has no random field, so only an empty array fits it.
    /// Set beside ``from``, any array, the empty one included, is refused
    /// with ``Uxid/Error/randWithFrom``.
    public var rand: [UInt8]?

    /// The source of the random field's bytes; the default reads
    /// `SystemRandomNumberGenerator`.
    ///
    /// ``Uxid/generate(_:)`` calls it once per id, and not at all when
    /// ``rand`` is set, the random field is empty or the id is deterministic
    /// (``from``). ``Uxid/Monotonic`` calls it for each seed and step it
    /// draws, as its documentation says, with its lock held, so a source given
    /// to a generator must not call that generator.
    ///
    /// - Precondition: The source returns exactly the count it is asked for.
    public var byteSource: ByteSource

    /// Creates options for ``Uxid/generate(_:)``; each argument defaults as
    /// its property says.
    ///
    /// - Parameters:
    ///   - prefix: The resource prefix; the empty string is no prefix.
    ///   - from: The string a deterministic id is derived from, or `nil` for a
    ///     time-based id.
    ///   - size: The size.
    ///   - randSize: An explicit random field width in bytes, or `nil` for the
    ///     size's width.
    ///   - compactTime: Whether the time field is compact; `nil` is standard.
    ///   - case: The letter case of the body.
    ///   - delimiter: The delimiter between the prefix and the body.
    ///   - time: The time in milliseconds since the Unix epoch, or `nil` for
    ///     the clock.
    ///   - rand: Fixed random field bytes for reproducible vectors, or `nil` to
    ///     draw them.
    ///   - byteSource: The source of the random field's bytes.
    public init(
      prefix: String = "",
      from: String? = nil,
      size: Size = .xl,
      randSize: Int? = nil,
      compactTime: Bool? = nil,
      case: Case = .lower,
      delimiter: String = "_",
      time: UInt64? = nil,
      rand: [UInt8]? = nil,
      byteSource: @escaping ByteSource = Uxid.systemRandomBytes
    ) {
      self.prefix = prefix
      self.from = from
      self.size = size
      self.randSize = randSize
      self.compactTime = compactTime
      self.case = `case`
      self.delimiter = delimiter
      self.time = time
      self.rand = rand
      self.byteSource = byteSource
    }
  }
}
