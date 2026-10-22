#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#elseif canImport(Android)
  import Android
#else
  #error("uxid reads the clock through the platform C library, which this platform lacks")
#endif

extension Uxid {
  /// Reads `count` bytes from `SystemRandomNumberGenerator`, the platform's
  /// secure generator: the default byte source.
  @usableFromInline
  @Sendable
  static func systemRandomBytes(_ count: Int) -> [UInt8] {
    var generator = SystemRandomNumberGenerator()
    var bytes: [UInt8] = []
    bytes.reserveCapacity(count)
    while bytes.count < count {
      var word: UInt64 = generator.next()
      for _ in 0..<min(8, count - bytes.count) {
        bytes.append(UInt8(truncatingIfNeeded: word))
        word >>= 8
      }
    }
    return bytes
  }

  /// The platform's real-time clock in whole milliseconds since the Unix
  /// epoch, read with `clock_gettime(CLOCK_REALTIME)`.
  static func clockMilliseconds() -> UInt64 {
    var now = timespec()
    let status = clock_gettime(CLOCK_REALTIME, &now)
    precondition(status == 0, "clock_gettime(CLOCK_REALTIME) failed")
    return UInt64(now.tv_sec) * 1000 + UInt64(now.tv_nsec) / 1_000_000
  }
}
