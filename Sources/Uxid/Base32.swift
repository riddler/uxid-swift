/// Crockford Base32 as the wire format writes it: most significant bit first,
/// one character per 5-bit group, with no padding.
enum Base32 {
  /// The 32 symbols in lower case, as ASCII bytes.
  private static let lower: [UInt8] = Array("0123456789abcdefghjkmnpqrstvwxyz".utf8)

  /// The 32 symbols in upper case, as ASCII bytes.
  private static let upper: [UInt8] = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ".utf8)

  /// The symbol table for a case.
  private static func symbols(_ letterCase: Uxid.Case) -> [UInt8] {
    letterCase == .upper ? upper : lower
  }

  /// Appends the low `5 x count` bits of `value` as `count` characters, so a
  /// value narrower than that (the 48-bit standard time in 10 characters)
  /// has its short group first.
  static func appendInteger(
    _ value: UInt64, characters count: Int, case letterCase: Uxid.Case, to out: inout [UInt8]
  ) {
    let table = symbols(letterCase)
    for index in 0..<count {
      let shift = UInt64(5 * (count - 1 - index))
      out.append(table[Int((value >> shift) & 31)])
    }
  }

  /// Appends a field of bytes in `ceil(8 x bytes / 5)` characters, the short
  /// group last and written as its raw value (the partial-group rule).
  static func appendBytes(_ bytes: [UInt8], case letterCase: Uxid.Case, to out: inout [UInt8]) {
    let table = symbols(letterCase)
    var buffer: UInt32 = 0
    var bits = 0
    for byte in bytes {
      buffer = (buffer << 8) | UInt32(byte)
      bits += 8
      while bits >= 5 {
        bits -= 5
        out.append(table[Int((buffer >> UInt32(bits)) & 31)])
      }
      buffer &= (1 << UInt32(bits)) - 1
    }
    if bits > 0 {
      out.append(table[Int(buffer)])
    }
  }
}
