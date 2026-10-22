# uxid

[![MIT License][badge_license_url]](LICENSE)
[![CI][badge_ci_url]](https://github.com/riddler/uxid-swift/actions/workflows/ci.yml)

User eXperience focused IDentifiers for Swift: prefixed, K-sortable,
Stripe-style ids a person can read, copy and route back to their resource. An
id looks like `usr_01hf7yat0004h1`: the prefix names the resource, and the body
carries a time and randomness in lower-case Crockford Base32. The ids follow
the wire format of the Elixir reference implementation,
[uxid-ex](https://github.com/riddler/uxid-ex), and the package is checked
against that implementation's conformance corpus, every case, with no skip
list.

## Why UXID

An auto-increment key leaks how many rows a table holds and invites
enumeration; a random UUID fixes both but is long, unordered and anonymous, so
in a log line, a URL or a support thread nobody can tell what it points at, and
a double-click selects only part of it. A UXID names its resource in its
prefix, selects whole on a double-click, reads aloud without ambiguity, sorts
by creation time so it indexes well, and is generated in the application with
no coordination between nodes. Its size is tunable for low-cardinality
resources, a monotonic generator keeps a burst within one millisecond unique
and in order, and a deterministic mode maps the same input to the same id.

Because the format is shared, an id this package makes is read by the other
implementations of the format, and the other way round.

## Install

Add the package to `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/riddler/uxid-swift", from: "1.0.0")
],
targets: [
  .target(name: "YourTarget", dependencies: [.product(name: "Uxid", package: "uxid")])
]
```

## Basic usage

```swift
import Uxid

// A prefix names the resource; the body is a time and randomness.
let id = try Uxid.generate(Uxid.Options(prefix: "usr"))

// A smaller size shortens the random part, for low-cardinality resources.
let small = try Uxid.generate(Uxid.Options(prefix: "cus", size: .s))

// Deterministic: the same prefix and input give the same id, every time.
let named = try Uxid.generate(Uxid.Options(prefix: "usr", from: "alice@example.com"))
// named == "usr_zcvt7epac0t1ebcsjfyf7cwz25"

// Read an id back. A malformed id is a failure value, never a thrown error.
let decoded = try Uxid.decode("cus_01hf7yat0004h1").get()
// decoded.prefix == "cus", decoded.size == .s, decoded.time == 1_700_000_000_000
let refused = Uxid.decode("cus_")  // .failure(.empty)
let valid = Uxid.isValid("cus_01hf7yat0004h1", prefix: "cus")  // true

// Monotonic: ids from one generator increase, also within one millisecond.
// You hold the generator; the package keeps no global state.
let ids = Uxid.Monotonic()
let options = Uxid.Options(prefix: "usr", size: .m)
let first = try ids.generate(options)
let second = try ids.generate(options)  // sorts after first
```

The package's tests compile and run this block and check that this file holds
it verbatim.

The API lives in the namespace enum `Uxid`, which shares its name with the
module, so write `Uxid.generate(...)`. `Uxid.Uxid` does not resolve; if your
own module declares a type named `Uxid`, name this one with the module selector
`Uxid::Uxid` on a compiler that reads module selectors, such as Swift 6.3.

A request the wire format refuses, such as a random width above 10 bytes,
throws a `Uxid.Error` with typed throws, so a `catch` reads it with no cast;
its `rawValue` is the stable `snake_case` name the conformance corpus uses.
`Uxid.decode` never throws on a malformed string: it returns `.failure` with
the first rule the string breaks, in the order `empty`, `invalid_length`,
`invalid_character`.

`Uxid.generate` and `Uxid.Monotonic.generate` read the platform's clock when
they need a time and `SystemRandomNumberGenerator`, the platform's secure
generator, when they need random bytes. `Uxid.Options.time` and `byteSource`
replace them, and `Uxid.DecodeOptions.clock` replaces the clock `Uxid.decode`
reads for a compact time. `rand` takes fixed random bytes for test vectors: an
id built from them is exactly as guessable as those bytes.

`Uxid.isValid(_:delimiter:prefix:)` and `Uxid.isDeterministic(_:delimiter:)`
take the delimiter the id was generated with and read no clock. They decode
the string in full: `isValid` is true for a body of a length the format
defines in Crockford Base32 characters, and, given a prefix, one that carries
exactly that prefix; `isDeterministic` is true for such a body that starts
with the marker `z` or `Z`. Both are stricter than the Elixir reference, whose
`valid?` accepts any alphabet body of at least 8 characters and whose
`deterministic?` reads the first body character only; the conformance corpus
does not fix these two answers.

A `Uxid.Monotonic` keeps the last time and random value for each prefix and
random field width it is given, and each id it makes sorts after the last
(within one letter case, delimiter and time form). The state is per prefix and
width, not per size or time form, so a compact `xl` request after a standard
one shares it and can be refused with `compactTimeOutOfRange`; keep one
generator for each form. A byte source or draw source given to a generator is
called with its lock held and must not call that generator.

## Compatibility

- Swift 6.0 tools (`swift-tools-version: 6.0`), built in the Swift 6 language
  mode with strict concurrency.
- macOS 15, iOS 18, tvOS 18, watchOS 11 and visionOS 2, the first releases with
  the `Synchronization` module; and Linux, with no floor beyond the Swift 6.0
  toolchain. CI builds and tests on macOS and on Linux.
- No dependencies beyond the Swift standard library and the platform C library:
  the library imports no Foundation, and the SHA-256 that deterministic ids need
  is written in the package.
- Thread safety: every public type is `Sendable`. One `Uxid.Monotonic` may be
  shared between tasks and threads; a `Mutex` inside the instance orders its
  calls, and two generators never affect each other. The package keeps no
  global state.
- A broken precondition of the API, such as an empty delimiter, a negative
  `randSize`, a byte source that returns the wrong count, or a time above
  `Uxid.maxTime` (2^48 - 1 milliseconds), stops the process rather than
  throwing; a caller holding such a value from outside checks it first.

## Documentation

- The API reference is DocC documentation, built with
  `swift package generate-documentation --target Uxid` and hosted by the
  Swift Package Index once the package is listed there. Every public symbol
  has a doc comment.
- [The wire format](docs/wire-format.md): where the normative layout of an id
  lives, and which version of it this package follows.
- [The changelog](CHANGELOG.md): what changed in each version.
- [The conformance corpus](conformance): the cases every implementation of the
  wire format passes, vendored here from uxid-ex.
- [The reference spec, at v2.10.0][guide_wire_format_url]: the alphabet, bit
  packing, sizes, prefix grammar, deterministic and monotonic bodies, and
  decoding.

## Development

`mise run gate:loop` runs the inner loop (build and tests), and `mise run gate`
runs the full gate: the format check, the build with warnings as errors, the
tests with 90 percent line coverage, the conformance corpus check and the DocC
build with warnings as errors. A release is the tag `vX.Y.Z`; the release
workflow only verifies it.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/riddler/uxid-swift.

## License

The package is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).

<!-- LINKS -->
[guide_wire_format_url]: https://github.com/riddler/uxid-ex/blob/v2.10.0/guides/wire-format.md

<!-- BADGES -->
[badge_license_url]: https://img.shields.io/badge/license-MIT-brightgreen.svg
[badge_ci_url]: https://github.com/riddler/uxid-swift/actions/workflows/ci.yml/badge.svg
