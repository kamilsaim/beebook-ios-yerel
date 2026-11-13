import XCTest
@testable import AriCekirdek

final class KimlikTests: XCTestCase {
    // Web genId: Date.now().toString(36) + 5 rastgele base36 karakter
    func test_webBicimi() {
        let an = Date(timeIntervalSince1970: 1_700_000_000)
        let k = yeniKimlik(simdi: an)
        let onek = String(Int64(1_700_000_000_000), radix: 36)
        XCTAssertTrue(k.hasPrefix(onek))
        XCTAssertEqual(k.count, onek.count + 5)
        XCTAssertTrue(k.allSatisfy { ("0"..."9").contains($0) || ("a"..."z").contains($0) })
    }

    func test_tekil() {
        var gorulen = Set<String>()
        for _ in 0..<1000 { gorulen.insert(yeniKimlik()) }
        XCTAssertEqual(gorulen.count, 1000)
    }
}
