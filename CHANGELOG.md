# Changelog

## 1.0.0 - 2026-10-21

The first release of `uxid` for Swift: prefixed, K-sortable identifiers a
person can read, wire-compatible with the Elixir `uxid` package. The SwiftPM
package is `uxid`, with one library product and module, `Uxid`, whose public
API lives in the namespace enum `Uxid`. It covers time-based generation
(`Uxid.generate(_:)` with `Uxid.Options`, `Uxid.Size`, `Uxid.Case`,
`Uxid.ByteSource` and `Uxid.maxTime`), deterministic ids (`Uxid.Options.from`),
decoding (`Uxid.decode(_:options:)` with `Uxid.DecodeOptions`, `Uxid.Decoded`,
read through `prefix`, `size`, `isCompact`, `isDeterministic` and `time`, and
`Uxid.DecodeError`), the validity checks (`Uxid.isValid(_:delimiter:prefix:)`
and `Uxid.isDeterministic(_:delimiter:)`), the monotonic generator
(`Uxid.Monotonic`, built with `Uxid.Monotonic(draws:)`, and
`Uxid.Monotonic.DrawSource`), the generation refusals (`Uxid.Error`:
`compactTimeOutOfRange`, `randWidthMismatch`, `randSizeTooLarge`,
`fromWithMonotonic`, `randWithFrom` and `randWithMonotonic`) and the version
constant `Uxid.version`. It needs Swift 6.0 tools (`swift-tools-version: 6.0`)
and builds in the Swift 6 language mode; it supports macOS 15, iOS 18, tvOS 18,
watchOS 11, visionOS 2 and Linux; and it depends on nothing beyond the Swift
standard library and the platform C library. A broken precondition stops the
process rather than throwing: an empty delimiter, a negative `randSize`, a time
above `Uxid.maxTime` or a decoder clock above it when a compact time is read, a
byte source or draw source that returns the wrong count or a step out of range,
a monotonic request with no random field to step, a monotonic field that
overflows in the last millisecond a time holds, or the platform's real-time
clock, read by default when no time or decoder clock is given, failing to read
or reading earlier than the Unix epoch. It is checked against the
conformance corpus vendored from riddler/uxid-ex at the tag `v2.10.0`
(`conformance/SOURCE.json` records the tag, its commit and the corpus hash),
and every case in it passes with no skip list.

### Added

- `Uxid.Options.from` asks `Uxid.generate(_:)` for a deterministic id: the marker `z` (or `Z` in upper case) and the leading bits of a SHA-256 digest of the prefix, the string and the size, so the same prefix, string and size give the same id on every call, on every machine.
- A deterministic request with fixed `rand` bytes is refused with `Uxid.Error.randWithFrom` (`rand_with_from`); its time, compact time, random field width and byte source are not read.
- `Uxid.maxTime`, the latest time an id carries (2^48 - 1 milliseconds), lets a caller check a time from outside before passing it, since a larger one stops the process.
- `Uxid.decode(_:options:)` reads an id to a `Result` of `Uxid.Decoded` (its prefix, size, compact flag, deterministic flag and time) or `Uxid.DecodeError`, the reason a string is refused (`empty`, `invalid_length` or `invalid_character`, checked in that order); it never throws or stops the process on a malformed string.
- `Uxid.DecodeOptions` takes the delimiter and the decoder's clock, which supplies a compact time's high bits, so a compact time decodes reproducibly under a fixed clock; a clock in the first 2^40 milliseconds after the Unix epoch can give a negative compact time.
- `Uxid.isValid(_:delimiter:prefix:)` answers whether a string decodes and, given a required prefix, carries exactly that prefix; `Uxid.isDeterministic(_:delimiter:)` answers whether a string decodes to a deterministic id.
- `Uxid.Monotonic` generates ids that increase strictly for each prefix and random field width, also within one millisecond and when the clock moves back, following the wire format's monotonic rule: in the last id's millisecond the random field moves on by a random step, and a field that overflows moves the id to the next millisecond with a fresh value.
- One `Uxid.Monotonic` is safe to share between tasks and threads: it is `Sendable`, and a `Mutex` inside the instance orders the calls; two generators keep separate state.
- `Uxid.Monotonic.generate(_:)` takes `Uxid.Options` per call and draws from its byte source (a step is masked bits, with no modulo bias), or from a `Uxid.Monotonic.DrawSource` given to the generator to replay known values; at size `xs` an unset `compactTime` is compact time.
- A monotonic request with `from` is refused with `Uxid.Error.fromWithMonotonic` (`from_with_monotonic`), and one with fixed `rand` bytes with `Uxid.Error.randWithMonotonic` (`rand_with_monotonic`); a refused call leaves the generator's state as it was.
- `Uxid.generate(_:)` builds a time-based id from `Uxid.Options`: a prefix (the empty string is no prefix), a size from `Uxid.Size` (default `xl`), an explicit random field width, compact time, the body's `Uxid.Case`, the delimiter and the time in milliseconds, with the clock read when no time is given.
- The random field's bytes come from `Uxid.Options.byteSource`, a `@Sendable` closure given a count, which defaults to `SystemRandomNumberGenerator`; fixed `rand` bytes build reproducible vectors and are never a source of randomness.
- `Uxid.Size(spelling:)` reads a size from its short spelling (`xs` to `xl`) or its long one (`xsmall` to `xlarge`).
- `Uxid.Error` names the refusals of generation with the spellings of the conformance corpus, such as `rand_width_mismatch`; `Uxid.generate(_:)` throws it with typed throws.
