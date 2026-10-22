### Added

- `Uxid.decode(_:options:)` reads an id to a `Result` of `Uxid.Decoded` (its prefix, size, compact flag, deterministic flag and time) or `Uxid.DecodeError`, the reason a string is refused (`empty`, `invalid_length` or `invalid_character`, checked in that order); it never throws or stops the process on a malformed string.
- `Uxid.DecodeOptions` takes the delimiter and the decoder's clock, which supplies a compact time's high bits, so a compact time decodes reproducibly under a fixed clock; a clock in the first 2^40 milliseconds after the Unix epoch can give a negative compact time.
- `Uxid.isValid(_:delimiter:prefix:)` answers whether a string decodes and, given a required prefix, carries exactly that prefix; `Uxid.isDeterministic(_:delimiter:)` answers whether a string decodes to a deterministic id.
