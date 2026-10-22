import Testing
import Uxid

@Suite("Version")
struct VersionTests {
  @Test("is major.minor.patch (sabotage: version \"0.1\" -> the count fails)")
  func versionIsSemanticVersionCore() {
    let parts = Uxid.version.split(separator: ".", omittingEmptySubsequences: false)
    #expect(parts.count == 3)
    for part in parts {
      #expect(!part.isEmpty && part.allSatisfy(\.isASCII) && part.allSatisfy(\.isNumber))
    }
  }
}
