import XCTest
@testable import AriCekirdek

/// Android AraziDurumTests ile aynı.
final class AraziDurumTests: XCTestCase {
    private func kv(_ id: String, _ durum: String = "yes", guc: String? = nil) -> JSONDeger {
        var k: Kayit = ["id": .metin(id), "num": .metin(id), "queenStatus": .metin(durum)]
        if let guc { k["strength"] = .metin(guc) }
        return .nesne(k)
    }
    private func mu(_ h: String, _ tarih: String, varroa: String? = nil, guc: String? = nil) -> JSONDeger {
        var k: Kayit = ["id": .metin(yeniKimlik()), "hiveId": .metin(h), "date": .metin(tarih)]
        if let varroa { k["varroaAction"] = .metin(varroa) }
        if let guc { k["strength"] = .metin(guc) }
        return .nesne(k)
    }
    private func isK(_ h: String, _ tarih: String, bitti: Bool = false) -> JSONDeger {
        .nesne(["id": .metin(yeniKimlik()), "text": .metin("x"), "done": .bool(bitti), "dueDate": .metin(tarih), "hiveIds": .dizi([.metin(h)])])
    }

    func test_isaretler() {
        let v = BBVeri(ham: [
            "hives": .dizi([kv("a", "no"), kv("b"), kv("c", "empty"), kv("d", guc: "2"), kv("e")]),
            "inspections": .dizi([mu("b", "2026-10-01"), mu("e", "2026-11-18", varroa: "takildi"), mu("c", "2026-01-01")]),
            "tasks": .dizi([isK("b", "2026-11-20"), isK("e", "2026-11-25"), isK("a", "2026-11-19", bitti: true)]),
        ])
        let d = araziDurumlari(v, bugun: "2026-11-20")
        XCTAssertEqual(d["a"], [.anasiz])
        XCTAssertEqual(d["b"], [.is_, .gecikmis])
        XCTAssertNil(d["c"])
        XCTAssertEqual(d["d"], [.zayif])
        XCTAssertEqual(d["e"], [.serit])
    }

    func test_seritCikarilincaKalkar() {
        let v = BBVeri(ham: [
            "hives": .dizi([kv("a")]),
            "inspections": .dizi([mu("a", "2026-10-01", varroa: "takildi"), mu("a", "2026-11-15", varroa: "cikarildi"), mu("a", "2026-11-19")]),
        ])
        XCTAssertNil(araziDurumlari(v, bugun: "2026-11-20")["a"])
    }

    func test_sonMuayeneGucuKovanGucundenOnce() {
        let v = BBVeri(ham: ["hives": .dizi([kv("a", guc: "4")]), "inspections": .dizi([mu("a", "2026-11-19", guc: "1")])])
        XCTAssertEqual(araziDurumlari(v, bugun: "2026-11-20")["a"], [.zayif])
    }

    func test_turSirasiYilanGibi() {
        let k: [String: (x: Double, y: Double)] = [
            "1": (40, 40), "2": (168, 42), "3": (296, 38),
            "4": (40, 232), "5": (168, 230), "6": (296, 235),
            "7": (100, 430),
        ]
        XCTAssertEqual(araziTurSirasi(k), ["1", "2", "3", "6", "5", "4", "7"])
    }
}
