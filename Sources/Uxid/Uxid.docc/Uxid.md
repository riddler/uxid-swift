# ``Uxid``

Prefixed, K-sortable identifiers a person can read, copy and route back to
their resource.

## Overview

An id looks like `usr_01hf7yat0004h1`: the prefix names the resource, and the
body carries a time and some randomness in Crockford Base32. The ids follow the
wire format of the Elixir reference implementation, uxid-ex, and the package is
checked against that implementation's conformance corpus, every case, with no
skip list.

The whole API lives in the namespace enum `Uxid`, which shares its name with
the module. Write `Uxid.generate(_:)` and the like. `Uxid.Uxid` does not
resolve, because the enum shadows its module; a program whose own module
declares a type named `Uxid` names this one with the module selector
`Uxid::Uxid` on a compiler that reads module selectors, such as Swift 6.3.

```swift
import Uxid

let id = try Uxid.generate(Uxid.Options(prefix: "usr", size: .s))
let decoded = try Uxid.decode(id).get()
// decoded.prefix == "usr" and decoded.size == .s
```

The package depends on nothing beyond the Swift standard library and the
platform C library. Random bytes come from `SystemRandomNumberGenerator`, the
platform's secure generator, unless a call is given another byte source; fixed
random bytes exist for reproducible vectors and make an id exactly as guessable
as those bytes.

### Stopping the process

A request the wire format refuses is a thrown ``Uxid/Error``. A broken
precondition of the API, such as an empty delimiter or a time past
``Uxid/maxTime``, is a programmer error and stops the process: a caller holding
a value from outside checks it first. Decoding never throws and never stops the
process for a malformed string, which comes back as a failure.

## Topics

### Generating an id

- ``Uxid/generate(_:)``
- ``Uxid/Options``
- ``Uxid/Size``
- ``Uxid/Case``
- ``Uxid/ByteSource``
- ``Uxid/maxTime``
- ``Uxid/Error``

### Generating ids that increase

- ``Uxid/Monotonic``
- ``Uxid/Monotonic/DrawSource``

### Reading an id

- ``Uxid/decode(_:options:)``
- ``Uxid/DecodeOptions``
- ``Uxid/Decoded``
- ``Uxid/DecodeError``

### Checking an id

- ``Uxid/isValid(_:delimiter:prefix:)``
- ``Uxid/isDeterministic(_:delimiter:)``

### The package version

- ``Uxid/version``
