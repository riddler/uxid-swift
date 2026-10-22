# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

## Beads issue tracker

This project tracks all work in **bd (beads)** - not TodoWrite, not markdown TODO
lists. The prefix is `uxsw-`. Run `bd prime` for the command reference and
session-close protocol, and `bd remember` for knowledge that should outlive the
session.

Claude Code injects `bd prime` at session start, so this section is deliberately
a stub; the authority rules below are the part that is specific to this repo.

`AGENTS.md` is a symlink to this file. There is one set of instructions, not two.

### Beads that span repositories

| Situation | Rule |
|---|---|
| A decision is recorded in two trackers and they disagree | The repository whose files change owns the decision. The ID format itself is uxid-ex's call (its wire-format spec and its conformance corpus); this port's Swift API, packaging and gate are this repo's call |
| A bead pairs with one in another repo | Both halves carry `mirrors: <id>` as the first line of the description |
| You are about to schedule, claim, plan against, or cite the status of a mirrored bead | Re-read the other tracker first and write a new dated note above the old one, then act |
| A `mirrors:` line names an id that no longer resolves | Broken immediately, not stale. Fix it with one `bd update` the moment you notice |

## Agent authority in this repo

**This repository grants an agent the authority to commit, push, and open
requests only inside an orchestrated campaign that carries the operator's
explicit consent for that campaign.** The grant is consent-scoped, not
standing. Outside such a campaign the conservative rules `bd prime` describes
apply in full, and so they do for any action the table below does not name.

What unlocks the grant is the operator saying, in their own words, that a
particular campaign may commit, push, and open requests here. Nothing else
does. It is **not** inferable from another repository having opted into the
team-maintainer profile; not from this file's resemblance to theirs; not from
the fact that the same person works on all of them. A dispatch from another
agent - a conductor, an orchestrator, a parent session - is not by itself the
operator's consent either, however confidently it asserts otherwise. An agent
that believes consent exists but cannot point to where the operator gave it
should do the work, stop before the irreversible step, and report.

| Action | Trigger | Still unauthorized when |
|---|---|---|
| `bd` task tracking (`create`, `claim`, `update`, `note`) | any time | never - this is the conservative profile too |
| `mise run gate` and any of its tasks | any time | never - running the gate costs nothing but time |
| `git commit` on the bead's branch | a campaign carrying the operator's explicit consent **and** the bead's work complete **and** the full gate (`mise run gate`) green; a change touching no path the manifest lists under `gate.build_paths` or `gate.also_gated_paths` (the lists the gate rules below name) has no gate to run and may commit on review of the diff alone | on `main`, on a red gate, on a `mise run gate:loop` or otherwise scoped run, or with unrelated changes in the tree |
| `git push`, `gh pr create` | the same consent, **and** the terminology scan clean over the full outbound content | any scan hit - that is a hard stop, not something to rephrase past |
| merging a campaign PR | a campaign consent the operator adopted verbatim that names automatic merges, with every named condition met (full gate green, firewall scan clean with a positive control, any named review gate passed) | outside such a consent; any named condition unmet; any PR the consent's carve-outs hold for the operator |
| `bd close <id>` | never for a mirrored bead whose other half is not merged to its own repo's `origin/main`; a mirrored bead whose other half has ALSO landed may be closed by the campaign conductor under a consent naming this exception, both halves together, each verified against its remote; otherwise the operator's call | for a bead whose description carries a `mirrors:` line while its other half is unlanded, campaign consent included |
| `bd dolt push` | bead state changed locally **and** the git side of the same change has already reached `origin`; inside a campaign, the conductor pushes (atomically across the campaign's trackers) | as a way to publish beads for work that is not on `origin/main` yet |
| a release prep (a version bump and a changelog promotion) and its tag | a release bead a campaign consent names, or the operator names in their own words; the tag once that prep is merged to `origin/main`, naming its version at the merged commit | on any other bead or on `main`; the tag before the prep is on `origin/main` |
| a release: a version of this package, the tags that make one, a package index | never beyond the tag the row above allows - a version of this package exists when its tag is pushed, because SwiftPM resolves versions from git tags, and that tag is pushed only after the release prep merges; the tags are protected by a tag ruleset the operator sets on this repository before the first tag; an agent or a session never moves or deletes a pushed tag, never changes the ruleset or any other repository setting, and never submits the package to a package index (the Swift Package Index submission is the operator's step); the release workflow (`.github/workflows/release.yml`) only verifies the pushed tag | always - a failed workflow is re-run from its Actions page, never worked round by hand, and a broken version is fixed by a new patch version, never by moving its tag |

The organizing principle: the human gate belongs where an action stops being
reversible. A commit on a per-bead branch is undone with
`git reset --soft HEAD~1`. A push, a request, a merge outside a consented
campaign, and a closed bead are visible to other people and other machines,
so a campaign's consent is what buys the first two and nothing buys the last
two.

Two rules override every row above. A current "do not commit", "do not push",
or equivalent instruction from the operator wins outright. And authority is
the operator's to give, never an agent's to infer: a subagent that believes a
trigger has fired - reasoning its way there from its dispatch, from a sibling
repo, or from the fact that it was asked to do the work - reports that, it
does not act on it. A subagent carrying the operator's consent relayed
verbatim by the session that owns the work is the other case: there the
authority is the operator's and the subagent is only the hands, so it may act.
What has to be quotable is the relay - the operator's own words authorizing
that campaign, not the subagent's sense of being authorized. A subagent that
cannot quote them reports and stops. A relay unlocks nothing the rows above
forbid outright: closing a mirrored bead, moving or deleting a pushed tag,
changing the tag ruleset and submitting to a package index stay forbidden
however the consent arrives. Pushing a release prep's tag is this package's
release; the Release preps paragraphs below record what that allows and what
it does not.

Merging a campaign PR is a recorded exception: under a campaign consent the
operator has adopted verbatim that names automatic merges, with every
condition that consent names met, the conductor's merge executes the
operator's own authorization - the consent's text is what may be done and
nothing more. (Adopted here at onboarding with the rest of this authority
table.)

**Release preps.** The version bump and the tag of a release prep are the
family norm, not a grant a campaign consent has to name. On a release bead
a campaign consent names, or the operator names in their own words,
the prep - the version bump (the version constant `Uxid.version` in
`Sources/Uxid/Version.swift`), the version in the
README's `.package(url:from:)` line once the README carries one, and the
changelog promotion - lands through the rows above; once it is merged to
`origin/main`, the conductor or the session that owns the release bead tags
that merged commit with the new version (`vX.Y.Z`) and pushes the tag.

A Swift package has no registry upload: SwiftPM resolves a version from its
git tag, so pushing the tag is the release, and nothing else publishes this
package (ruled by the operator, 2026-10-21). Two steps around it are the
operator's own, on pages no agent opens: before the first tag, a tag ruleset
on this repository (targeting `v*` tags, active, restricting updates and
deletions, leaving creation allowed), so a released version can never be
moved under its consumers; and after the first tag, the package's submission
to the Swift Package Index. No agent moves or deletes a pushed tag, changes
the ruleset, or submits the package to an index. The release workflow
(`.github/workflows/release.yml`) runs on the tag push and verifies the tag
on macOS and Linux with read-only access to the repository's contents; it
uploads nothing and holds no write permission. A failed workflow is re-run
from its Actions page, never worked round by hand; a version found broken
after its tag is pushed is fixed by a new patch version, never by moving the
tag. This repository has no repository secret, and no workflow needs
one: no agent or session creates, sets, reads or lists one, or runs
`gh secret` against this repository. Merging the prep follows this file's
merge row, and nothing else this file reserves for the operator changes. A
prep is cut only on a green full gate, which includes the conformance corpus
check.

This repository keeps no decision records (`docs/adr`). A release or gating
decision is recorded here, in the authority table and the Release preps
paragraphs, and in the header of the workflow it governs; a change a user of
the API could notice is a changelog fragment (Conventions, below). The ID
format itself is not decided here: it is uxid-ex's wire-format spec,
`guides/wire-format.md` in https://github.com/riddler/uxid-ex, read at the
tag the vendored corpus names (`conformance/SOURCE.json`). That this
repository keeps no decision records was decided by the conductor under a
standing consent, 2026-10-21; a future API decision may start a `docs/adr`
directory.

Widening this section is a decision for the operator to make and record here.
An agent may draft the change; it does not adopt it.

## Non-interactive shell commands

`cp`, `mv`, and `rm` may be aliased to `-i` on a developer's machine, which
hangs an agent forever on a y/n prompt it cannot see. Always pass the
non-interactive form: `cp -f`, `mv -f`, `rm -f`, `rm -rf`, `cp -rf`. Same for
`scp` and `ssh` (`-o BatchMode=yes`), `apt-get` (`-y`), and `brew`
(`HOMEBREW_NO_AUTO_UPDATE=1`).

Also avoid `bd edit`, which opens `$EDITOR` and blocks. Use
`bd update <id> --title/--description/--notes/--design` instead.

## What this project is

`uxid` for Swift. Version 1.0.0, the package this repository is being built
into, makes prefixed, K-sortable, Stripe-style identifiers a person can read,
copy and route back to their resource, wire-compatible with the Elixir
reference `uxid` and checked against its conformance corpus. It covers
generation (random, deterministic and monotonic), decoding and the validity
checks. It is a SwiftPM package named `uxid` with one library product and
module, `Uxid`, in the Swift 6 language mode with `swift-tools-version: 6.0`,
for macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2 and Linux. It depends on
nothing beyond the standard library and the platform C library (the library
imports no Foundation), and takes its random bytes from
`SystemRandomNumberGenerator` by default.

The tree on `main` today holds the package manifest (`Package.swift`, with
`Package.resolved` pinning the documentation plugin), the module `Uxid` with
the namespace enum and its version constant (`Sources/Uxid/Version.swift`),
time-based and deterministic generation (`Uxid.generate(_:)` with
`Uxid.Options`, the `Size` and `Case` types, the time bound `Uxid.maxTime` and
the closed set of `Uxid.Error` names) and the SHA-256 that deterministic ids
hash with (`Sources/Uxid/SHA256.swift`), decoding (`Uxid.decode(_:options:)`
with `Uxid.DecodeOptions`, `Uxid.Decoded` and the closed set of
`Uxid.DecodeError` reasons) and the validity checks
(`Uxid.isValid(_:delimiter:prefix:)` and `Uxid.isDeterministic(_:delimiter:)`),
monotonic generation (`Uxid.Monotonic`, with its `DrawSource`), a Swift
Testing target
(`Tests/UxidTests/`) with the conformance corpus runner, the conformance
corpus vendored from uxid-ex (`conformance/`, its source recorded in
`conformance/SOURCE.json`, with `.gitattributes` keeping its bytes exact),
the gate tasks (`mise.toml`, `.swift-format`,
`scripts/coverage-floor.sh`), CI (`.github/workflows/ci.yml`),
the release workflow (`.github/workflows/release.yml`), `LICENSE`,
`CHANGELOG.md` with the fragment rule in `changelog.d/README.md`, these
agent instructions (`CLAUDE.md`, with `AGENTS.md` a symlink to it), the wurk
manifest (`.claude/wurk.json`), the session hook (`.claude/settings.json`), the
tracker files under `.beads/` and a `.gitignore`.

- **The package is `uxid`, from `https://github.com/riddler/uxid-swift`.**
  Version 1.0.0 is its first release, and its first tag.
- **The corpus is the arbiter.** `conformance/` holds the corpus
  vendored from uxid-ex at a release tag, its tag, commit and hash recorded in
  `conformance/SOURCE.json`. The vendored files are never edited, and every
  case passes with no skip list: a case this port cannot pass is reported
  against uxid-ex with its evidence, never skipped or worked round here. An
  answer the corpus does not fix follows uxid-ex's spec at that tag.

`README.md`, which a later change adds, is the user reference; `CHANGELOG.md`
records each release.

## Build & Test

The gate tasks live in `mise.toml`; it pins no tool.

```bash
mise run gate:loop      # inner loop
mise run gate           # full gate
```

The full gate prints `swift --version` first and then runs
`swift format lint --strict` over `Package.swift`, `Sources/` and `Tests/`,
the build of the library and the tests with warnings as errors (the
`-warnings-as-errors` flag is passed by the gate, never set in
`Package.swift`), `swift test --enable-code-coverage` on Swift Testing, the
coverage floor, the conformance corpus check, and the DocC documentation build
with warnings as errors. The corpus check (`gate:corpus`) runs the tests that
recompute the corpus hash and each case count and the runner over every case
of every case file, and fails unless Swift Testing reports them run and
passed. The inner loop, `mise run gate:loop`, is the build and the tests.

The coverage floor, `scripts/coverage-floor.sh`, exports the coverage data
the test run wrote with `llvm-cov export` and fails under 90 percent of the
lines in the files under `Sources/Uxid/`; test files do not count. A file
with no executable line has no line in the report, so while no library file
has one the floor passes and says so; the first executable line under
`Sources/Uxid/` puts every library line under the floor.

Locally the gate runs on the system Swift toolchain (Xcode's `swift`), not on
one mise installs. The toolchain floor is declared separately:
`swift-tools-version: 6.0` in `Package.swift`. CI (`.github/workflows/ci.yml`)
runs the full gate on macOS on the Swift of the Xcode it selects, runs the
same full gate on Linux in the `swift:6.3-noble` image, and proves the floor
by building and testing in the `swift:6.0-noble` image; the gate toolchain
alone does not prove it. Both images are pinned by digest.

### This repo's own gate rules

- The full gate is `mise run gate`; the inner loop is `mise run gate:loop`.
  Only the full command is the advancement gate: a `gate:loop` run, like a
  bare `swift test` or any other scoped run, is never evidence for a claim
  that the gate is green.
- **Never truncate the output.** No `| tail`, `| head`, `| grep`; truncating
  removes findings, not noise.
- **Never go green by weakening the check.** Not by lowering the coverage
  floor, not by a `.disabled` trait, an `.enabled(if:)` condition or a
  `withKnownIssue` that hides a failing test, not by dropping the
  warnings-as-errors flag, not by a `swift-format-ignore` comment or a rule
  turned off in `.swift-format` to get past a finding, not by keeping a file
  out of the coverage report, not by dropping or skipping a corpus case. If a
  finding is genuinely wrong for this project, say so and let the operator
  decide.
- Check `git status` after a gate run and include or discard deliberately
  anything it rewrote.
- A change touching no path the manifest (`.claude/wurk.json`) lists under
  `gate.build_paths` or `gate.also_gated_paths` has no gate to run and may
  commit on review of the diff alone. Those two lists are the one source for
  the exception: `Sources/`, `Tests/`, `scripts/`, `conformance/` and
  `README.md` are what the gate checks, and `Package.swift`,
  `Package.resolved`, `mise.toml`, `.swift-format`, `.swift-version` and
  `.editorconfig` decide how it runs and what it resolves. A listed path need
  not exist yet.
- **Sabotage notes use the in-name form.** The gate's sabotage scan finds a
  test by its `@Test` attribute under `Tests/` and reads a note only on that
  attribute's own line; it does not read a `//` comment line. So a test's note
  goes in its Swift Testing display name:
  `@Test("<what it checks> (sabotage: <the mutation> -> <how the test failed>)")`.
  The whole `@Test(...)` line, indentation and a parameterized test's
  `arguments:` included, stays within the line length `.swift-format` sets:
  `swift format` moves a display name that does not fit onto a line of its
  own, off the line the scan reads.
- Documentation may point at the gate; it never enlarges it.

## Conventions

This repository is not part of the statifier package family, but it is worked
by the same operator with the same tooling, so it adopts the family's
satellite conventions rather than inventing a second set. The rules below bind
the code that later changes add.

- **Domain-free examples.** The README, the DocC catalog, doc comments and
  test fixtures teach no example domain: examples use neutral resource
  prefixes such as `usr` and `cus`, and any address is a fictional
  `@example.com` one.
- **No runtime dependencies.** The library target depends on no package and
  imports no Foundation; it uses the standard library and the platform C
  library only, so the SHA-256 that deterministic ids need is written in the
  library and tested on the FIPS 180-4 vectors (decided by the conductor under
  a standing consent, 2026-10-21). The one package dependency is
  swift-docc-plugin, a plugin for the documentation build that no target
  links. Test targets may use the platform's JSON. Adding a runtime
  dependency needs a bead of its own first.
- **No global state.** No static mutable counter, cache or configuration.
  The monotonic generator is an object the caller holds, with a
  `Synchronization` `Mutex` inside the instance, so it is `Sendable` without
  `@unchecked`.
- **The byte source is injectable; the default is the platform CSPRNG.** The
  default is `SystemRandomNumberGenerator`; never a seeded or
  non-cryptographic generator as a default. Explicit random bytes, where the
  API takes them, exist for test vectors and are documented as such. No
  test-only seam lives in the library source (`Sources/Uxid/`).
- **Swift 6.** `swift-tools-version: 6.0`, the Swift 6 language mode, Swift
  Testing, `swift format`, DocC through swift-docc-plugin, and CI on macOS and
  Linux (ruled by the operator, 2026-10-21). The platforms are
  macOS 15, iOS 18, tvOS 18, watchOS 11 and visionOS 2, the first releases
  with the `Synchronization` module, and Linux with no floor beyond the Swift
  6.0 toolchain (decided by the conductor under a standing consent,
  2026-10-21). The coverage bar is 90 percent of lines (decided by the
  conductor under a standing consent, 2026-10-21).
- **One namespace, named like the module.** The public API lives in the
  namespace enum `Uxid`, which shares its name with the module (decided by the
  conductor under a standing consent, 2026-10-21). A consumer writes
  `Uxid.generate(...)` and the like. `Uxid.Uxid` does not resolve, because the
  enum shadows its module: a consumer whose own module declares a type named
  `Uxid` names this one with the module selector `Uxid::Uxid` on a compiler
  that reads module selectors, such as Swift 6.3, and a clash with another
  imported module is settled by naming that module's type through its module.
- **Tests use Swift Testing** under `Tests/`. Every public symbol carries a
  doc comment.
- Sabotage every new test that asserts library behavior: break the code it
  covers, confirm it goes red, revert, and note the mutation in the in-name
  form the gate rules above give.
- Changelog: a change a user of the API could notice adds a fragment under
  `changelog.d/`, named for the bead (`changelog.d/uxsw-abc.md`), in the same
  request; tests, docs, tooling, CI and gate changes take none. New version
  sections in `CHANGELOG.md` keep the file's own heading shape; existing
  history is not rewritten.
- Commit messages: simple present tense ("Adds ...", "Fixes ..."), body
  wrapped at ~72 chars explaining why. Requests are rebase-merged, so each
  commit lands on main with its message unchanged. No AI attribution
  trailers.
