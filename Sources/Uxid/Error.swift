extension Uxid {
  /// A request the wire format refuses, named as the conformance corpus names it.
  ///
  /// The cases are a closed set: each is one generation error the wire-format
  /// specification lists, and its `rawValue` is that error's spelling in the
  /// corpus, such as `rand_width_mismatch`. ``Uxid/generate(_:)`` throws it
  /// with typed throws, so a caller's `catch` reads a `Uxid.Error` with no cast.
  ///
  /// Inside the `Uxid` namespace the name `Error` means this type; the
  /// standard library's protocol is `Swift.Error`.
  public enum Error: String, Swift.Error, Sendable, Hashable, CaseIterable {
    /// A compact time whose first character would be the deterministic
    /// marker: the low 40 bits of the time at or above 31 x 2^35
    /// milliseconds, from mid-2038 until the 40-bit window rolls over in 2039.
    /// A standard time is never refused for this reason.
    case compactTimeOutOfRange = "compact_time_out_of_range"

    /// Fixed random bytes whose count is not the request's random field width.
    case randWidthMismatch = "rand_width_mismatch"

    /// An explicit random field width above 10 bytes.
    case randSizeTooLarge = "rand_size_too_large"

    /// A deterministic body asked for with monotonic generation.
    case fromWithMonotonic = "from_with_monotonic"

    /// Fixed random bytes asked for with a deterministic body.
    case randWithFrom = "rand_with_from"

    /// Fixed random bytes asked for with monotonic generation.
    case randWithMonotonic = "rand_with_monotonic"
  }
}
