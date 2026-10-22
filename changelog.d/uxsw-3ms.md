### Added

- `Uxid.Options.from` asks `Uxid.generate(_:)` for a deterministic id: the marker `z` (or `Z` in upper case) and the leading bits of a SHA-256 digest of the prefix, the string and the size, so the same prefix, string and size give the same id on every call, on every machine.
- A deterministic request with fixed `rand` bytes is refused with `Uxid.Error.randWithFrom` (`rand_with_from`); its time, compact time, random field width and byte source are not read.
- `Uxid.maxTime`, the latest time an id carries (2^48 - 1 milliseconds), lets a caller check a time from outside before passing it, since a larger one stops the process.
