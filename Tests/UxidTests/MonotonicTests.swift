import Foundation
import Synchronization
import Testing
import Uxid

/// Replays known draws: each seed call answers the next of `seeds` (zero once
/// they run out) as a big-endian field of the asked width, each step call the
/// next of `steps` (one once they run out), and every call is logged.
final class ReplayDraws: Sendable {
  private struct Queue {
    var seeds: [UInt64]
    var steps: [UInt64]
    var log: [String] = []
  }

  private let queue: Mutex<Queue>

  init(seeds: [UInt64], steps: [UInt64]) {
    queue = Mutex(Queue(seeds: seeds, steps: steps))
  }

  /// The calls made so far, each `seed` or `step` with its width.
  var log: [String] { queue.withLock { $0.log } }

  /// The seeds and steps not drawn yet.
  var remaining: Int { queue.withLock { $0.seeds.count + $0.steps.count } }

  var source: Uxid.Monotonic.DrawSource {
    Uxid.Monotonic.DrawSource(
      seed: { [self] width in
        queue.withLock { queue in
          queue.log.append("seed \(width)")
          let value = queue.seeds.isEmpty ? 0 : queue.seeds.removeFirst()
          return (0..<width).map { UInt8(truncatingIfNeeded: value >> (8 * (width - 1 - $0))) }
        }
      },
      step: { [self] width in
        queue.withLock { queue in
          queue.log.append("step \(width)")
          return queue.steps.isEmpty ? 1 : queue.steps.removeFirst()
        }
      })
  }
}

/// A byte source that answers each call with the next of `answers` and
/// records the count it was asked for.
final class ScriptedBytes: Sendable {
  private let state: Mutex<(answers: [[UInt8]], asked: [Int])>

  init(_ answers: [[UInt8]]) {
    state = Mutex((answers: answers, asked: []))
  }

  var asked: [Int] { state.withLock { $0.asked } }

  var source: Uxid.ByteSource {
    { [self] count in
      state.withLock { state in
        state.asked.append(count)
        return state.answers.removeFirst()
      }
    }
  }
}

/// The id the generator gives for the options, or the corpus name of the
/// refusal it throws.
private func call(_ generator: Uxid.Monotonic, _ options: Uxid.Options) -> String {
  do {
    return try generator.generate(options)
  } catch {
    return error.rawValue
  }
}

/// The time-based id `Uxid.generate(_:)` builds from fixed bytes, the oracle
/// the generator's ids are compared with.
private func expectedId(
  _ prefix: String, _ size: Uxid.Size, compact: Bool, time: UInt64, rand: [UInt8]
) -> String {
  do {
    return try Uxid.generate(
      Uxid.Options(prefix: prefix, size: size, compactTime: compact, time: time, rand: rand))
  } catch {
    return error.rawValue
  }
}

private let corpusTime: UInt64 = 1_700_000_000_000

/// The last millisecond whose compact time does not start with the marker:
/// one more is refused.
private let lastCompactTime: UInt64 = 31 * (1 << 35) - 1

@Suite("Monotonic")
struct MonotonicTests {
  @Test("refusals (sabotage: from check removed -> outcome is an id)")
  func refusals() {
    let generator = Uxid.Monotonic()
    let from = Uxid.Options(prefix: "usr", from: "alice@example.com")
    #expect(call(generator, from) == "from_with_monotonic")
    let rand = Uxid.Options(prefix: "usr", size: .s, time: corpusTime, rand: [0x01, 0x02])
    #expect(call(generator, rand) == "rand_with_monotonic")
    let both = Uxid.Options(from: "alice@example.com", rand: [])
    #expect(call(generator, both) == "from_with_monotonic")
    let wide = Uxid.Options(size: .s, randSize: 11, time: corpusTime)
    #expect(call(generator, wide) == "rand_size_too_large")
  }

  @Test("a refused call keeps the state (sabotage: state saved first -> outcome is the refusal)")
  func refusedCallKeepsState() {
    let draws = ReplayDraws(seeds: [250], steps: [10, 3, 2])
    let generator = Uxid.Monotonic(draws: draws.source)
    let options = Uxid.Options(prefix: "usr", size: .xs, time: lastCompactTime)
    let first = call(generator, options)
    #expect(first == expectedId("usr", .xs, compact: true, time: lastCompactTime, rand: [250]))
    #expect(call(generator, options) == "compact_time_out_of_range")
    #expect(
      call(generator, options)
        == expectedId("usr", .xs, compact: true, time: lastCompactTime, rand: [253]))
    var from = options
    from.from = "alice@example.com"
    #expect(call(generator, from) == "from_with_monotonic")
    #expect(
      call(generator, options)
        == expectedId("usr", .xs, compact: true, time: lastCompactTime, rand: [255]))
    #expect(draws.log == ["seed 1", "step 1", "seed 1", "step 1", "step 1"])
  }

  @Test("default draws mask the byte source (sabotage: no mask -> id mismatch)")
  func byteSourceDraws() {
    let bytes = ScriptedBytes([[0x00, 0x00, 0x01], [0xff, 0xff]])
    let generator = Uxid.Monotonic()
    let options = Uxid.Options(
      prefix: "cus", size: .s, compactTime: true, time: corpusTime, byteSource: bytes.source)
    let first = call(generator, options)
    let second = call(generator, options)
    #expect(first == expectedId("cus", .s, compact: true, time: corpusTime, rand: [0, 0, 1]))
    #expect(
      second == expectedId("cus", .s, compact: true, time: corpusTime, rand: [0x00, 0x10, 0x01]))
    #expect(bytes.asked == [3, 2])
  }

  @Test("time form: xs compact, others standard (sabotage: unset is compact -> id mismatch)")
  func timeFormDefaults() {
    let draws = ReplayDraws(seeds: [7, 7], steps: [])
    let generator = Uxid.Monotonic(draws: draws.source)
    let xs = call(generator, Uxid.Options(size: .xs, time: corpusTime))
    let s = call(generator, Uxid.Options(size: .s, time: corpusTime))
    #expect(xs == expectedId("", .xs, compact: true, time: corpusTime, rand: [7]))
    #expect(s == expectedId("", .s, compact: false, time: corpusTime, rand: [0, 7]))
  }

  @Test("state per prefix and width (sabotage: key ignores prefix -> log mismatch)")
  func statePerPrefixAndWidth() {
    let draws = ReplayDraws(seeds: [1, 2, 3], steps: [4])
    let generator = Uxid.Monotonic(draws: draws.source)
    let usr = Uxid.Options(prefix: "usr", size: .s, time: corpusTime)
    let cus = Uxid.Options(prefix: "cus", size: .s, time: corpusTime)
    let wider = Uxid.Options(prefix: "usr", size: .s, randSize: 3, time: corpusTime)
    let ids = [usr, cus, usr, wider].map { options in call(generator, options) }
    #expect(draws.log == ["seed 2", "seed 2", "step 2", "seed 3"])
    #expect(ids[2] == expectedId("usr", .s, compact: false, time: corpusTime, rand: [0, 5]))
    let other = Uxid.Monotonic(draws: ReplayDraws(seeds: [9], steps: []).source)
    #expect(
      call(other, usr)
        == expectedId("usr", .s, compact: false, time: corpusTime, rand: [0, 9]))
  }

  @Test("strict increase across tasks (sabotage: lock split around draws -> duplicate ids)")
  func concurrentStrictIncrease() async {
    let generator = Uxid.Monotonic()
    let options = Uxid.Options(prefix: "usr", size: .s, time: corpusTime)
    let perTask = 500
    let all = await withTaskGroup(of: [String].self) { group in
      for _ in 0..<8 {
        group.addTask {
          (0..<perTask).map { _ in call(generator, options) }
        }
      }
      var all: [[String]] = []
      for await ids in group {
        all.append(ids)
      }
      return all
    }
    for ids in all {
      #expect(zip(ids, ids.dropFirst()).allSatisfy { $0 < $1 })
    }
    #expect(Set(all.joined()).count == 8 * perTask)
  }

  @Test("no time reads the clock (sabotage: time read as 0 -> time outside the window)")
  func clockTime() throws {
    let before = Int64(Date().timeIntervalSince1970 * 1000) - 1
    let id = try Uxid.Monotonic().generate(Uxid.Options(size: .s))
    let after = Int64(Date().timeIntervalSince1970 * 1000) + 1
    let time = try #require(try Uxid.decode(id).get().time)
    #expect(before <= time && time <= after)
  }

  @Test("xl compact and standard share state (sabotage: key adds compact -> no refusal)")
  func compactAfterStandardShares() throws {
    // 31 x 2^35 ms: a standard time, and the first one a compact field refuses.
    // A compact request one second earlier is fine alone.
    let marked: UInt64 = 31 << 35
    let later = Uxid.Options(prefix: "usr", compactTime: true, time: marked - 1000)

    let fresh = Uxid.Monotonic()
    _ = try fresh.generate(later)

    let shared = Uxid.Monotonic()
    _ = try shared.generate(Uxid.Options(prefix: "usr", time: marked))
    #expect(throws: Uxid.Error.compactTimeOutOfRange) { try shared.generate(later) }
  }
}
