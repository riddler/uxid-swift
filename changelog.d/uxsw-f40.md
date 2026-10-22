### Added

- `Uxid.generate(_:)` builds a time-based id from `Uxid.Options`: a prefix (the empty string is no prefix), a size from `Uxid.Size` (default `xl`), an explicit random field width, compact time, the body's `Uxid.Case`, the delimiter and the time in milliseconds, with the clock read when no time is given.
- The random field's bytes come from `Uxid.Options.byteSource`, a `@Sendable` closure given a count, which defaults to `SystemRandomNumberGenerator`; fixed `rand` bytes build reproducible vectors and are never a source of randomness.
- `Uxid.Size(spelling:)` reads a size from its short spelling (`xs` to `xl`) or its long one (`xsmall` to `xlarge`).
- `Uxid.Error` names the refusals of generation with the spellings of the conformance corpus, such as `rand_width_mismatch`; `Uxid.generate(_:)` throws it with typed throws.
