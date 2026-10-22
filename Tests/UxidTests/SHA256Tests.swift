import Testing

@testable import Uxid

/// One SHA-256 known answer: a message and its digest in lowercase hex.
struct DigestCase: Sendable, CustomTestStringConvertible {
  let name: String
  let message: [UInt8]
  let digest: String

  var testDescription: String { name }
}

/// Writes bytes as lowercase hex.
private func hexString(_ bytes: [UInt8]) -> String {
  let digits = Array("0123456789abcdef")
  var text = ""
  for byte in bytes {
    text.append(digits[Int(byte >> 4)])
    text.append(digits[Int(byte & 0x0f)])
  }
  return text
}

private func ascii(_ text: String) -> [UInt8] { Array(text.utf8) }

private func repeated(_ count: Int) -> [UInt8] { [UInt8](repeating: 0x61, count: count) }

/// The SHA-256 examples of FIPS 180-4 (the NIST example values for the
/// one-block, two-block and long messages), then runs of `a` at the lengths
/// where padding changes shape, whose digests were computed with `shasum -a 256`.
private let digestCases: [DigestCase] = [
  DigestCase(
    name: "empty", message: [],
    digest: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
  DigestCase(
    name: "abc", message: ascii("abc"),
    digest: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
  DigestCase(
    name: "448 bits",
    message: ascii("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    digest: "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"),
  DigestCase(
    name: "896 bits",
    message: ascii(
      "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmno"
        + "ijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"),
    digest: "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1"),
  DigestCase(
    name: "55 a", message: repeated(55),
    digest: "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318"),
  DigestCase(
    name: "56 a", message: repeated(56),
    digest: "b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a"),
  DigestCase(
    name: "63 a", message: repeated(63),
    digest: "7d3e74a05d7db15bce4ad9ec0658ea98e3f06eeecf16b4c6fff2da457ddc2f34"),
  DigestCase(
    name: "64 a", message: repeated(64),
    digest: "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb"),
  DigestCase(
    name: "65 a", message: repeated(65),
    digest: "635361c48bb9eab14198e76ea8ab7f1a41685d6ad62aa9146d301d4f17eb0ae0"),
  DigestCase(
    name: "119 a", message: repeated(119),
    digest: "31eba51c313a5c08226adf18d4a359cfdfd8d2e816b13f4af952f7ea6584dcfb"),
  DigestCase(
    name: "120 a", message: repeated(120),
    digest: "2f3d335432c70b580af0e8e1b3674a7c020d683aa5f73aaaedfdc55af904c21c"),
]

@Suite("SHA-256")
struct SHA256Tests {
  @Test("known answers (sabotage: sigma0 rotr 8 -> digest mismatch)", arguments: digestCases)
  func knownAnswers(_ testCase: DigestCase) {
    #expect(hexString(SHA256.hash(testCase.message)) == testCase.digest)
  }

  @Test("one million a (sabotage: length in bytes not bits -> digest mismatch)")
  func millionA() {
    #expect(
      hexString(SHA256.hash(repeated(1_000_000)))
        == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
  }
}
