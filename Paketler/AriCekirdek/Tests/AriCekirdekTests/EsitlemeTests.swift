import XCTest
@testable import AriCekirdek

// aricilik/tests/sync-merge.test.mjs testlerinin birebir karşılığı (+ iOS ekleri).

private func rec(_ id: String, _ up: Int64, _ ek: Kayit = [:]) -> JSONDeger {
    var k = ek; k["id"] = .metin(id); k["_up"] = .tam(up); return .nesne(k)
}
private func mezar(_ id: String, _ c: String, _ ts: Int64) -> JSONDeger {
    .nesne(["id": .metin(id), "c": .metin(c), "ts": .tam(ts)])
}
private func D(_ ek: [String: JSONDeger] = [:]) -> BBVeri {
    var h: [String: JSONDeger] = [:]
    for c in ["hives", "sales", "expenses", "milk", "queens", "tasks", "seasons", "stock", "deleted"] { h[c] = .dizi([]) }
    for (k, v) in ek { h[k] = v }
    return BBVeri(ham: h)
}

final class EsitlemeTests: XCTestCase {
    // ---- union
    func test_yerelEklenenYasar() {
        let r = veriBirlestir(yerel: D(["sales": .dizi([rec("a", 5)])]), uzak: D())
        XCTAssertEqual(r.birlesik.koleksiyon("sales").count, 1)
        XCTAssertTrue(r.uzakKirli)
        XCTAssertFalse(r.yerelKirli)
    }
    func test_uzakEklenenYasar() {
        let r = veriBirlestir(yerel: D(), uzak: D(["sales": .dizi([rec("b", 5)])]))
        XCTAssertEqual(r.birlesik.koleksiyon("sales").count, 1)
        XCTAssertTrue(r.yerelKirli)
    }
    // ---- LWW
    func test_buyukUpKazanir() {
        let r = veriBirlestir(yerel: D(["hives": .dizi([rec("h", 10, ["num": .metin("yerel")])])]),
                              uzak: D(["hives": .dizi([rec("h", 20, ["num": .metin("uzak")])])]))
        XCTAssertEqual(r.birlesik.koleksiyon("hives")[0]["num"], .metin("uzak"))
    }
    func test_esitUpUzakKazanir() {
        let r = veriBirlestir(yerel: D(["hives": .dizi([rec("h", 10, ["num": .metin("yerel")])])]),
                              uzak: D(["hives": .dizi([rec("h", 10, ["num": .metin("uzak")])])]))
        XCTAssertEqual(r.birlesik.koleksiyon("hives")[0]["num"], .metin("uzak"))
    }
    func test_legacyUpsuzRemoteKazanir() {
        let r = veriBirlestir(yerel: D(["hives": .dizi([.nesne(["id": .metin("h"), "num": .metin("yerel")])])]),
                              uzak: D(["hives": .dizi([.nesne(["id": .metin("h"), "num": .metin("uzak")])])]))
        XCTAssertEqual(r.birlesik.koleksiyon("hives")[0]["num"], .metin("uzak"))
    }
    // ---- tombstone
    func test_silmeYeniyseKayitGider() {
        let r = veriBirlestir(yerel: D(["deleted": .dizi([mezar("x", "sales", 30)])]),
                              uzak: D(["sales": .dizi([rec("x", 10)])]))
        XCTAssertEqual(r.birlesik.koleksiyon("sales").count, 0)
        XCTAssertEqual(r.birlesik.koleksiyon("deleted").count, 1)
    }
    func test_silmedenSonraDuzenlenenDirilir() {
        let r = veriBirlestir(yerel: D(["deleted": .dizi([mezar("x", "sales", 30)])]),
                              uzak: D(["sales": .dizi([rec("x", 40)])]))
        XCTAssertEqual(r.birlesik.koleksiyon("sales").count, 1)
        XCTAssertEqual(r.birlesik.koleksiyon("deleted").count, 0)
    }
    func test_mezarBirlesimiBuyukTs() {
        let r = veriBirlestir(yerel: D(["deleted": .dizi([mezar("x", "sales", 10)])]),
                              uzak: D(["deleted": .dizi([mezar("x", "sales", 20)])]))
        XCTAssertEqual(r.birlesik.koleksiyon("deleted").count, 1)
        XCTAssertEqual(r.birlesik.koleksiyon("deleted")[0]["ts"], .tam(20))
    }
    // ---- bayraklar ve bloblar
    func test_ayniVeriKirliDegil() {
        let r = veriBirlestir(yerel: D(["sales": .dizi([rec("a", 5)])]), uzak: D(["sales": .dizi([rec("a", 5)])]))
        XCTAssertFalse(r.yerelKirli)
        XCTAssertFalse(r.uzakKirli)
    }
    func test_araziLayoutBuyukUp() {
        let r = veriBirlestir(
            yerel: D(["araziLayout": .nesne(["_up": .tam(10), "positions": .nesne(["a": .tam(1)])])]),
            uzak: D(["araziLayout": .nesne(["_up": .tam(20), "positions": .nesne(["a": .tam(2)])])]))
        XCTAssertEqual(r.birlesik.araziLayout?["positions"]?["a"], .tam(2))
    }
    // ---- budama
    func test_90GundenEskiMezarBudanir() {
        let simdi: Int64 = 1_800_000_000_000
        let gun: Int64 = 86_400_000
        let out = mezarlariBuda([["id": .metin("a"), "c": .metin("sales"), "ts": .tam(simdi - 91 * gun)],
                                 ["id": .metin("b"), "c": .metin("sales"), "ts": .tam(simdi - 10 * gun)]], simdi: simdi)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].id, "b")
    }
    // ---- fark ve damga
    func test_yeniKayitDamgalanir() {
        var d = D(["sales": .dizi([.nesne(["id": .metin("n1"), "total": .tam(100)])])])
        _ = farkVeDamga(&d, onceki: anlikOlustur(D()), simdi: 999)
        XCTAssertEqual(d.koleksiyon("sales")[0].up, 999)
    }
    func test_degisenKayitDamgalanir() {
        let snap = anlikOlustur(D(["sales": .dizi([rec("a", 5, ["total": .tam(100)])])]))
        var d = D(["sales": .dizi([rec("a", 5, ["total": .tam(200)])])])
        _ = farkVeDamga(&d, onceki: snap, simdi: 999)
        XCTAssertEqual(d.koleksiyon("sales")[0].up, 999)
    }
    func test_degismeyenDamgalanmaz() {
        var d = D(["sales": .dizi([rec("a", 5, ["total": .tam(100)])])])
        let snap = anlikOlustur(d)
        _ = farkVeDamga(&d, onceki: snap, simdi: 999)
        XCTAssertEqual(d.koleksiyon("sales")[0].up, 5)
    }
    func test_silinenMezarOlur() {
        let snap = anlikOlustur(D(["sales": .dizi([rec("a", 5)])]))
        var d = D()
        _ = farkVeDamga(&d, onceki: snap, simdi: 999)
        XCTAssertEqual(d.koleksiyon("deleted"), [["id": .metin("a"), "c": .metin("sales"), "ts": .tam(999)]])
    }
    // ---- ayarlar
    func test_ayarBuyukUpKazanir() {
        XCTAssertEqual(ayarBirlestir(yerel: Ayarlar(ham: ["_up": .tam(10), "city": .metin("Ankara")]),
                                     uzak: Ayarlar(ham: ["_up": .tam(20), "city": .metin("Bolu")])).city, "Bolu")
        XCTAssertEqual(ayarBirlestir(yerel: Ayarlar(ham: ["_up": .tam(30), "city": .metin("Ankara")]),
                                     uzak: Ayarlar(ham: ["_up": .tam(20), "city": .metin("Bolu")])).city, "Ankara")
    }
    func test_ayarEsitUpAlanBazli() {
        let s = ayarBirlestir(yerel: Ayarlar(ham: ["city": .metin("Ankara"), "fontSize": .tam(16)]),
                              uzak: Ayarlar(ham: ["city": .metin("Bolu")]))
        XCTAssertEqual(s.city, "Bolu")
        XCTAssertEqual(s.ham["fontSize"], .tam(16))
    }
    // ---- iOS ekleri
    func test_bilinmeyenUstAnahtarUzakKazanir() {
        let r = veriBirlestir(yerel: D(["yeni": .metin("y"), "sadeceYerel": .tam(1)]), uzak: D(["yeni": .metin("u")]))
        XCTAssertEqual(r.birlesik.ham["yeni"], .metin("u"))
        XCTAssertEqual(r.birlesik.ham["sadeceYerel"], .tam(1))
        XCTAssertNil(r.birlesik.ham["_demo"])
    }
    func test_inspectionsDaBirlesir() {
        let r = veriBirlestir(yerel: D(["inspections": .dizi([rec("m1", 5)])]),
                              uzak: D(["inspections": .dizi([rec("m2", 5)])]))
        XCTAssertEqual(Set(r.birlesik.koleksiyon("inspections").compactMap(\.id)), ["m1", "m2"])
    }
    func test_nilTaraflar() {
        let r = veriBirlestir(yerel: nil, uzak: D(["sales": .dizi([rec("a", 1)])]))
        XCTAssertEqual(r.birlesik.koleksiyon("sales").count, 1)
        XCTAssertEqual(ayarBirlestir(yerel: nil, uzak: nil), Ayarlar())
    }
}
