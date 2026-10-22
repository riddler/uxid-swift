### Added

- `Uxid.Monotonic` generates ids that increase strictly for each prefix and random field width, also within one millisecond and when the clock moves back, following the wire format's monotonic rule: in the last id's millisecond the random field moves on by a random step, and a field that overflows moves the id to the next millisecond with a fresh value.
- One `Uxid.Monotonic` is safe to share between tasks and threads: it is `Sendable`, and a `Mutex` inside the instance orders the calls; two generators keep separate state.
- `Uxid.Monotonic.generate(_:)` takes `Uxid.Options` per call and draws from its byte source (a step is masked bits, with no modulo bias), or from a `Uxid.Monotonic.DrawSource` given to the generator to replay known values; at size `xs` an unset `compactTime` is compact time.
- A monotonic request with `from` is refused with `Uxid.Error.fromWithMonotonic` (`from_with_monotonic`), and one with fixed `rand` bytes with `Uxid.Error.randWithMonotonic` (`rand_with_monotonic`); a refused call leaves the generator's state as it was.
