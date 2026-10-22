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

  /// Each ASCII byte's symbol value, or -1 for a byte that is no symbol in
  /// either case. Bytes from 128 up are never symbols.
  private static let values: [Int8] = {
    var table = [Int8](repeating: -1, count: 128)
    for (value, symbol) in lower.enumerated() {
      table[Int(symbol)] = Int8(value)
    }
    for (value, symbol) in upper.enumerated() {
      table[Int(symbol)] = Int8(value)
    }
    return table
  }()

  /// The value of the symbol `byte` in either case, or `nil` when the byte is
  /// not a symbol: no reading substitution is applied, so `I`, `L`, `O`, `U`
  /// and a hyphen are refused like any other byte outside the table.
  static func value(_ byte: UInt8) -> UInt64? {
    guard byte < 128 else { return nil }
    let value = values[Int(byte)]
    return value < 0 ? nil : UInt64(value)
  }

  /// Reads `count` symbols of `bytes` from `start` as one integer, most
  /// significant first. The caller has checked that every byte is a symbol.
  static func readInteger(_ bytes: [UInt8], from start: Int, characters count: Int) -> UInt64 {
    var result: UInt64 = 0
    for index in start..<(start + count) {
      result = (result << 5) | (value(bytes[index]) ?? 0)
    }
    return result
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

  /// Appends the first `5 x count` bits of `bytes`, most significant bit
  /// first, as `count` characters with no short group: the hash characters of
  /// a deterministic body.
  static func appendLeadingBits(
    _ bytes: [UInt8], characters count: Int, case letterCase: Uxid.Case, to out: inout [UInt8]
  ) {
    let table = symbols(letterCase)
    var buffer: UInt32 = 0
    var bits = 0
    var next = 0
    for _ in 0..<count {
      if bits < 5 {
        buffer = (buffer << 8) | UInt32(bytes[next])
        next += 1
        bits += 8
      }
      bits -= 5
      out.append(table[Int((buffer >> UInt32(bits)) & 31)])
      buffer &= (1 << UInt32(bits)) - 1
    }
  }
}
