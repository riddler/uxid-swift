import Foundation
import Testing

// The vendored conformance corpus (`conformance/` at the repository root):
// where it is, how a case file splits into lines, and a strict reader for one
// case. The reader hands a case's keys out by name and fails on a key it was
// not asked for, on a missing key and on a value of the wrong JSON type, so a
// corpus that grows a key this runner does not know fails rather than being
// half read. JSON is read with Foundation, in the test target only.

/// A corpus file that is not what the runner expects: a key it does not
/// know, a missing key, a value of the wrong type or a malformed line.
struct CorpusFormatError: Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}

/// The case files the manifest lists, in its order.
enum CaseFile: String, CaseIterable, Sendable {
  case encode
  case deterministic
  case decode
  case invalid
  case monotonic

  /// The file's name in the corpus directory.
  var fileName: String { rawValue + ".json" }
}

/// One case of a case file: its id and its line, as the runner reads it.
struct CorpusCase: Sendable, CustomTestStringConvertible {
  let id: String
  let line: String

  var testDescription: String { id }
}

/// Reads the vendored corpus.
enum Corpus {
  /// The corpus directory: `conformance/` at the repository root, found from
  /// this file's path (`Tests/UxidTests/Corpus.swift`).
  static let directory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("conformance")

  /// The bytes of one corpus file, named relative to the corpus directory.
  static func bytes(_ name: String) throws -> [UInt8] {
    [UInt8](try Data(contentsOf: directory.appendingPathComponent(name)))
  }

  /// The lines of one case file, by the corpus README's rule: the file is
  /// valid UTF-8, split on newlines, and every line, the last included, ends
  /// in one.
  static func lines(_ file: CaseFile) throws -> [String] {
    let data = try bytes(file.fileName)
    guard let text = String(bytes: data, encoding: .utf8) else {
      throw CorpusFormatError("\(file.fileName) is not UTF-8")
    }
    guard text.utf8.last == UInt8(ascii: "\n") else {
      throw CorpusFormatError("\(file.fileName) does not end in a newline")
    }
    let lines = text.utf8.dropLast().split(
      separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false
    ).map { String(decoding: $0, as: UTF8.self) }
    guard !lines.contains(where: \.isEmpty) else {
      throw CorpusFormatError("\(file.fileName) holds an empty line")
    }
    return lines
  }

  /// Every case of one case file, in file order, each with its id.
  static func cases(_ file: CaseFile) throws -> [CorpusCase] {
    try lines(file).map { line in
      CorpusCase(id: try Fields.parse(line).peekString("id"), line: line)
    }
  }
}

/// One JSON value, as the corpus spells them: integers only (every one at
/// most 2^53 - 1), never a fraction.
enum JSONValue: Decodable, Sendable {
  case null
  case bool(Bool)
  case integer(Int64)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int64.self) {
      self = .integer(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else {
      throw CorpusFormatError("a value that is not an integer, string, bool, array or object")
    }
  }

  /// The JSON type's name, for a refusal's message.
  var typeName: String {
    switch self {
    case .null: return "null"
    case .bool: return "a bool"
    case .integer: return "an integer"
    case .string: return "a string"
    case .array: return "an array"
    case .object: return "an object"
    }
  }
}

/// One JSON object read key by key. ``done()`` fails on a key no getter
/// asked for.
struct Fields {
  private let members: [String: JSONValue]
  private var read: Set<String> = []

  init(_ value: JSONValue) throws {
    guard case .object(let members) = value else {
      throw CorpusFormatError("expected an object, found \(value.typeName)")
    }
    self.members = members
  }

  /// Parses one case line.
  static func parse(_ line: String) throws -> Fields {
    try Fields(JSONDecoder().decode(JSONValue.self, from: Data(line.utf8)))
  }

  /// Whether the object has the key.
  func has(_ name: String) -> Bool { members[name] != nil }

  /// Reads a string without marking the key as read.
  func peekString(_ name: String) throws -> String {
    guard case .string(let value) = try value(name) else { throw wrongType(name) }
    return value
  }

  mutating func string(_ name: String) throws -> String {
    let value = try peekString(name)
    read.insert(name)
    return value
  }

  mutating func nullableString(_ name: String) throws -> String? {
    switch try take(name) {
    case .string(let value): return value
    case .null: return nil
    default: throw wrongType(name)
    }
  }

  mutating func bool(_ name: String) throws -> Bool {
    guard case .bool(let value) = try take(name) else { throw wrongType(name) }
    return value
  }

  mutating func integer(_ name: String) throws -> Int64 {
    guard case .integer(let value) = try take(name) else { throw wrongType(name) }
    return value
  }

  mutating func nullableInteger(_ name: String) throws -> Int64? {
    switch try take(name) {
    case .integer(let value): return value
    case .null: return nil
    default: throw wrongType(name)
    }
  }

  mutating func object(_ name: String) throws -> Fields {
    try Fields(take(name))
  }

  mutating func array(_ name: String) throws -> [JSONValue] {
    guard case .array(let items) = try take(name) else { throw wrongType(name) }
    return items
  }

  mutating func integers(_ name: String) throws -> [Int64] {
    try array(name).map { item in
      guard case .integer(let value) = item else { throw wrongType(name) }
      return value
    }
  }

  mutating func strings(_ name: String) throws -> [String] {
    try array(name).map { item in
      guard case .string(let value) = item else { throw wrongType(name) }
      return value
    }
  }

  /// Fails when the object holds a key no getter read.
  func done() throws {
    let unknown = members.keys.filter { !read.contains($0) }.sorted()
    guard unknown.isEmpty else {
      throw CorpusFormatError("unknown key \(unknown.joined(separator: ", "))")
    }
  }

  private func value(_ name: String) throws -> JSONValue {
    guard let value = members[name] else { throw CorpusFormatError("missing key \(name)") }
    return value
  }

  private mutating func take(_ name: String) throws -> JSONValue {
    let found = try value(name)
    read.insert(name)
    return found
  }

  private func wrongType(_ name: String) -> CorpusFormatError {
    CorpusFormatError("\(name) is \(members[name]?.typeName ?? "missing") or holds the wrong type")
  }
}

/// Lowercase hex, as the corpus spells bytes, to bytes; anything else is
/// refused.
func corpusHex(_ text: String) throws -> [UInt8] {
  let digits = Array(text.utf8)
  guard digits.count % 2 == 0 else { throw CorpusFormatError("odd-length hex: \(text)") }
  func nibble(_ digit: UInt8) throws -> UInt8 {
    switch digit {
    case UInt8(ascii: "0")...UInt8(ascii: "9"): return digit - UInt8(ascii: "0")
    case UInt8(ascii: "a")...UInt8(ascii: "f"): return digit - UInt8(ascii: "a") + 10
    default: throw CorpusFormatError("not lowercase hex: \(text)")
    }
  }
  return try stride(from: 0, to: digits.count, by: 2).map { index in
    (try nibble(digits[index]) << 4) | (try nibble(digits[index + 1]))
  }
}
