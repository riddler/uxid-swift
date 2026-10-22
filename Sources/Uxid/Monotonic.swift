import Synchronization

extension Uxid {
  /// A monotonic generator: for one prefix and random field width, each id
  /// it makes carries a pair of time and random value greater than the last
  /// one's (the time is at least the last time, and when it is equal the
  /// random value is greater), also when several fall in one millisecond and
  /// when the clock moves back.
  ///
  /// It follows the "Monotonic generation" rule of uxid's wire-format
  /// specification. A monotonic id is an ordinary time-based id of its size
  /// and length: nothing in it says how it was made, and
  /// ``Uxid/decode(_:options:)`` reads it as any other. Among ids of one
  /// prefix, random field width, letter case, delimiter and time form, each
  /// sorts after the last as a string. The random value alone is not
  /// monotonic: when the time moves on, the id carries a fresh value, which
  /// can be smaller than the last.
  ///
  /// ```swift
  /// let ids = Uxid.Monotonic()
  /// let options = Uxid.Options(prefix: "usr", size: .s)
  /// let first = try ids.generate(options)
  /// let second = try ids.generate(options)  // sorts after first, also in one millisecond
  /// ```
  ///
  /// ## The rule
  ///
  /// Each call takes ``Uxid/Options`` as ``Uxid/generate(_:)`` does, and the
  /// generator keeps its state per prefix and per random field width: for
  /// each such pair it has seen, the last time `T` it gave and the last
  /// random value `R`, the random field read as one big-endian unsigned
  /// integer of `w` bytes. For a call at time `now` (``Uxid/Options/time``,
  /// or the platform's real-time clock read at the call when that is `nil`):
  ///
  /// 1. With no state for the pair, or `now` later than `T`, the id carries
  ///    `now` and a fresh random value, the seed.
  /// 2. With `now` equal to or earlier than `T`, the id carries `T` and
  ///    `R + step`, where the step is drawn uniformly from 1 to 2^(4w)
  ///    inclusive, half the field's bit width.
  /// 3. When `R + step` is 2^(8w) or more, the id carries `T + 1` and a fresh
  ///    seed instead.
  ///
  /// The step is not a plus-one counter: consecutive ids in a millisecond are
  /// spread over a window of 2^(4w) values. That stops trivial enumeration,
  /// but it is a mitigation, not unpredictability, and a small random field
  /// stays small: a standard ``Uxid/Size/s`` id has 16 random bits. A compact
  /// time holds only the low 40 bits of the time, so compact ids keep their
  /// order only within one 2^40 millisecond window, as every compact id does.
  ///
  /// ## The draws
  ///
  /// A generator made with no ``DrawSource`` draws from each call's
  /// ``Uxid/Options/byteSource``, by default `SystemRandomNumberGenerator`: a
  /// seed is `w` bytes, read big-endian, and a step is the low `4w` bits of
  /// `ceil(w / 2)` bytes, read big-endian, plus one. The range of a step holds
  /// a power of two values, so the masked bits are exactly uniform over it,
  /// with no modulo bias and nothing drawn again. A ``DrawSource`` passed to
  /// ``init(draws:)`` replaces those draws, and the byte source is then never
  /// called.
  ///
  /// ## Options that differ from generate
  ///
  /// ``Uxid/Options/prefix``, ``Uxid/Options/size``,
  /// ``Uxid/Options/randSize``, ``Uxid/Options/case``,
  /// ``Uxid/Options/delimiter``, ``Uxid/Options/time`` and
  /// ``Uxid/Options/byteSource`` mean what they mean to ``Uxid/generate(_:)``,
  /// with the same defaults and preconditions, with these differences:
  ///
  /// - ``Uxid/Options/compactTime`` left `nil` is compact time at size
  ///   ``Uxid/Size/xs`` and standard time at every other size, because a
  ///   standard ``Uxid/Size/xs`` has no random field to step and a compact one
  ///   has a 1-byte field. The random field width must be at least one byte,
  ///   so a ``Uxid/Size/xs`` with ``Uxid/Options/compactTime`` set to `false`
  ///   and no ``Uxid/Options/randSize``, or a ``Uxid/Options/randSize`` of 0,
  ///   is a programmer error that stops the process.
  /// - ``Uxid/Options/from`` is refused with ``Uxid/Error/fromWithMonotonic``
  ///   and ``Uxid/Options/rand`` with ``Uxid/Error/randWithMonotonic``: the
  ///   generator makes no deterministic id, and it chooses the random field
  ///   itself.
  ///
  /// ## Safe to share
  ///
  /// One generator may be shared between tasks and threads: it is `Sendable`,
  /// and a `Mutex` from the `Synchronization` module inside the instance
  /// orders the calls. Each call reads the time, draws and updates the state
  /// with the lock held, so the ids one generator makes for one prefix and
  /// random field width increase strictly in the order the calls take the
  /// lock, whichever task makes them. The byte source and the draw source are
  /// called with the lock held. The state lives in the instance alone, with
  /// nothing kept in a static property, so two generators never affect each
  /// other, and ids from two generators carry no order between them within a
  /// millisecond. The state for each pair is kept for the generator's
  /// lifetime, so it grows by one entry for each distinct prefix and random
  /// field width the generator is given.
  ///
  /// ## A refused call
  ///
  /// A call that throws leaves the generator as it was: the state of every
  /// pair stays what it was before the call, and the next call starts from
  /// it. Draws a refused call already made are not given back. So after a
  /// step that overflows the field onto a compact time the wire format
  /// refuses (``Uxid/Error/compactTimeOutOfRange``), a later call at or before
  /// `T` draws a new step: it is refused again if that step also overflows
  /// the field, and with a step that does not, it gives an id at `T`.
  public final class Monotonic: Sendable {
    /// Where a generator takes its random values from in place of the byte
    /// source: a fresh random field, the seed, and the step that moves the
    /// field on within a millisecond.
    ///
    /// It exists to replay known values, as a test or a conformance case
    /// does, and is never a source of randomness for real ids: a monotonic id
    /// is exactly as guessable as its draws. A generator calls it with its
    /// lock held.
    public struct DrawSource: Sendable {
      /// Returns a fresh random value for a random field of the given width
      /// in bytes (1 to 10): exactly that many bytes, read as one big-endian
      /// unsigned integer.
      ///
      /// - Precondition: The array holds exactly the width's count of bytes.
      public var seed: @Sendable (Int) -> [UInt8]

      /// Returns a step for a random field of the given width `w` in bytes
      /// (1 to 10), drawn uniformly from 1 to 2^(4w) inclusive.
      ///
      /// - Precondition: The step is from 1 to 2^(4w).
      public var step: @Sendable (Int) -> UInt64

      /// Creates a draw source from its two draws.
      ///
      /// - Parameters:
      ///   - seed: The fresh random value for a field of a width in bytes.
      ///   - step: The step for a field of a width in bytes.
      public init(
        seed: @escaping @Sendable (Int) -> [UInt8],
        step: @escaping @Sendable (Int) -> UInt64
      ) {
        self.seed = seed
        self.step = step
      }
    }

    /// The pair the state is kept for.
    private struct Key: Hashable {
      let prefix: String
      let width: Int
    }

    /// The last id's time and random value for one pair.
    private struct Last {
      let time: UInt64
      let value: UInt128
    }

    /// The draw source, or `nil` to draw from each call's byte source.
    private let draws: DrawSource?

    /// The last id of each pair, behind the instance's lock.
    private let state = Mutex<[Key: Last]>([:])

    /// Creates a generator with no state.
    ///
    /// - Parameter draws: The source of every seed and step, for replaying
    ///   known values; `nil`, the default, draws them from each call's
    ///   ``Uxid/Options/byteSource``, as production code should.
    public init(draws: DrawSource? = nil) {
      self.draws = draws
    }

    /// Generates the next id for the options' prefix and random field width,
    /// under the rule ``Uxid/Monotonic`` describes.
    ///
    /// A call that throws leaves the generator as it was.
    ///
    /// - Parameter options: The request; the default takes every default, so
    ///   it asks for an ``Uxid/Size/xl`` id with no prefix at the clock's time.
    /// - Returns: The id.
    /// - Precondition: Those of ``Uxid/generate(_:)`` for a time-based id; the
    ///   random field width is at least one byte; the field does not overflow
    ///   in millisecond ``Uxid/maxTime``, the last a time field holds; and a
    ///   ``DrawSource`` answers within the ranges it states. Each is a
    ///   programmer error that stops the process, not a refusal this method
    ///   throws.
    /// - Throws: ``Uxid/Error/fromWithMonotonic`` when ``Uxid/Options/from`` is
    ///   set, then ``Uxid/Error/randWithMonotonic`` when ``Uxid/Options/rand``
    ///   is set, both checked before anything else;
    ///   ``Uxid/Error/randSizeTooLarge`` for an explicit random field width
    ///   above 10 bytes; and ``Uxid/Error/compactTimeOutOfRange`` when the
    ///   compact time the id would carry would start with the deterministic
    ///   marker, also when that time is `T + 1`, reached by an overflow.
    public func generate(_ options: Options = Options()) throws(Error) -> String {
      guard options.from == nil else { throw .fromWithMonotonic }
      guard options.rand == nil else { throw .randWithMonotonic }
      precondition(!options.delimiter.utf8.isEmpty, "the delimiter must not be empty")

      let compact = options.compactTime ?? (options.size == .xs)
      var width = options.size.randBytes(compact: compact)
      if let randSize = options.randSize {
        precondition(randSize >= 0, "the random field width must not be negative")
        guard randSize <= Uxid.maxRandBytes else { throw .randSizeTooLarge }
        width = randSize
      }
      precondition(
        width > 0,
        "a monotonic id needs a random field to step; at size xs leave compactTime unset")

      let key = Key(prefix: options.prefix, width: width)
      return try state.withLock { (state) throws(Error) -> String in
        let now = options.time ?? Uxid.clockMilliseconds()
        precondition(now <= Uxid.maxTime, "the time must be at most 2^48 - 1 milliseconds")

        let next: Last
        if let last = state[key], now <= last.time {
          let value = last.value + UInt128(step(options, width))
          if value >> (8 * width) == 0 {
            next = Last(time: last.time, value: value)
          } else {
            precondition(
              last.time < Uxid.maxTime,
              "the random field overflowed in millisecond 2^48 - 1, the last a time field holds")
            next = Last(time: last.time + 1, value: seed(options, width))
          }
        } else {
          next = Last(time: now, value: seed(options, width))
        }

        if compact && Uxid.startsWithMarker(compactTime: next.time) {
          throw .compactTimeOutOfRange
        }
        let id = Uxid.timeId(
          options, time: next.time, compact: compact, rand: bytes(next.value, width))
        state[key] = next
        return id
      }
    }

    /// A fresh random value for a field of `width` bytes.
    private func seed(_ options: Options, _ width: Int) -> UInt128 {
      let drawn = draws?.seed(width) ?? options.byteSource(width)
      precondition(drawn.count == width, "a seed must be exactly the field's width in bytes")
      return drawn.reduce(0) { ($0 << 8) | UInt128($1) }
    }

    /// A step from 1 to 2^(4 x `width`), uniform over it.
    private func step(_ options: Options, _ width: Int) -> UInt64 {
      let max: UInt64 = 1 << (4 * width)
      if let draws {
        let step = draws.step(width)
        precondition(1 <= step && step <= max, "a step must be from 1 to 2^(4w)")
        return step
      }
      let count = (width + 1) / 2
      let drawn = options.byteSource(count)
      precondition(drawn.count == count, "the byte source must return exactly the count asked for")
      return (drawn.reduce(0) { ($0 << 8) | UInt64($1) } & (max - 1)) + 1
    }

    /// The `width`-byte big-endian form of `value`, which is below
    /// 2^(8 x `width`).
    private func bytes(_ value: UInt128, _ width: Int) -> [UInt8] {
      (0..<width).map { UInt8(truncatingIfNeeded: value >> (8 * (width - 1 - $0))) }
    }
  }
}
