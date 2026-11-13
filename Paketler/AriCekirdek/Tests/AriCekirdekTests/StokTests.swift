import XCTest
@testable import AriCekirdek

private func stok(_ p: String, _ a: String, _ m: JSONDeger, saleId: String? = nil) -> JSONDeger {
    var k: Kayit = ["id": .metin(yeniKimlik()), "product": .metin(p), "action": .metin(a), "amount": m, "unit": .metin("kg")]
    if let saleId { k["saleId"] = .metin(saleId) }
    return .nesne(k)
}
private func veri(_ stoklar: [JSONDeger]) -> BBVeri { BBVeri(ham: ["stock": .dizi(stoklar)]) }
private func satis(_ ek: Kayit) -> Satis {
    var k: Kayit = ["id": .metin("s1"), "customer": .metin("Ali"), "date": .metin("2026-11-13"), "payment": .metin("paid")]
    for (a, b) in ek { k[a] = b }
    return Satis(k)
}
private var sayac = 0
private func kimlik() -> String { sayac += 1; return "k\(sayac)" }

final class BirimTests: XCTestCase {
    func test_uyumlular() {
        XCTAssertEqual(Birim.uyumlular(.kg), [.kg, .gr])
        XCTAssertEqual(Birim.uyumlular(.lt), [.lt, .ml])
        XCTAssertEqual(Birim.uyumlular(.adet), [.adet])
    }
    func test_cevir() {
        XCTAssertEqual(Birim.cevir(500, .gr, .kg), 0.5)
        XCTAssertEqual(Birim.cevir(1.5, .lt, .ml), 1500)
        XCTAssertEqual(Birim.cevir(3, .kg, .kg), 3)
    }
    func test_uyumsuzBirimNil() {
        XCTAssertNil(Birim.cevir(1, .lt, .kg))
        XCTAssertNil(Birim.cevir(1, .adet, .gr))
    }
}

final class StokTests: XCTestCase {
    func test_stokSeviyesi() {
        let v = veri([stok("suzme_bal", "in", .tam(60)), stok("suzme_bal", "out", .tam(15)), stok("suzme_bal", "out", .tam(30)), stok("petek_bal", "in", .tam(9))])
        XCTAssertEqual(stokSeviyesi(v, urun: "suzme_bal"), 15)
    }
    func test_stokNegatifOlmaz() {
        XCTAssertEqual(stokSeviyesi(veri([stok("x", "in", .tam(1)), stok("x", "out", .tam(5))]), urun: "x"), 0)
    }
    func test_stokMetinMiktar() {
        XCTAssertEqual(stokSeviyesi(veri([stok("x", "in", .metin("10")), stok("x", "out", .metin("2.5"))]), urun: "x"), 7.5)
    }
    func test_satisUrunuOnceProduct() {
        XCTAssertEqual(satisStokUrunu(satis(["product": .metin("propolis"), "type": .metin("other")])), "propolis")
        XCTAssertEqual(satisStokUrunu(satis(["product": .metin("propolis"), "type": .metin("honey"), "honeyType": .metin("petek_bal")])), "propolis")
    }
    func test_satisUrunuEskiKural() {
        XCTAssertEqual(satisStokUrunu(satis(["type": .metin("milk")])), "ari_sutu")
        XCTAssertEqual(satisStokUrunu(satis(["type": .metin("honey")])), "suzme_bal")
        XCTAssertEqual(satisStokUrunu(satis(["type": .metin("honey"), "honeyType": .metin("petek_bal")])), "petek_bal")
        XCTAssertNil(satisStokUrunu(satis(["type": .metin("queen")])))
    }
    func test_grSatisKgStoktanDuser() {
        var v = veri([stok("suzme_bal", "in", .tam(10))])
        satisStokunuYaz(&v, satis: satis(["product": .metin("suzme_bal"), "qty": .tam(500), "unit": .metin("gr")]), onceki: nil, urunBirimi: .kg, kimlik: kimlik)
        let out = v.stokKayitlari.first { $0.action == "out" }
        XCTAssertEqual(out?.amount, 0.5)
        XCTAssertEqual(out?.unit, "kg")
        XCTAssertEqual(out?.saleId, "s1")
        XCTAssertEqual(stokSeviyesi(v, urun: "suzme_bal"), 9.5)
    }
    func test_uyumsuzBirimdeHamMiktar() {
        var v = veri([])
        satisStokunuYaz(&v, satis: satis(["product": .metin("x"), "qty": .tam(2), "unit": .metin("lt")]), onceki: nil, urunBirimi: .kg, kimlik: kimlik)
        XCTAssertEqual(v.stokKayitlari.first?.amount, 2)
        XCTAssertEqual(v.stokKayitlari.first?.unit, "lt")
    }
    func test_satisDuzenlemeAyniKaydiGunceller() {
        var v = veri([])
        let s1 = satis(["type": .metin("honey"), "qty": .tam(5), "unit": .metin("kg")])
        satisStokunuYaz(&v, satis: s1, onceki: nil, urunBirimi: .kg, kimlik: kimlik)
        let ilkId = v.stokKayitlari[0].id
        var s2 = s1; s2.qty = 8
        satisStokunuYaz(&v, satis: s2, onceki: s1, urunBirimi: .kg, kimlik: kimlik)
        XCTAssertEqual(v.stokKayitlari.count, 1)
        XCTAssertEqual(v.stokKayitlari[0].id, ilkId)
        XCTAssertEqual(v.stokKayitlari[0].amount, 8)
    }
    func test_hediyeNotu() {
        var v = veri([])
        satisStokunuYaz(&v, satis: satis(["type": .metin("honey"), "qty": .tam(1), "payment": .metin("hediye")]), onceki: nil, urunBirimi: .kg, kimlik: kimlik)
        XCTAssertEqual(v.stokKayitlari[0].note, "Hediye: Ali")
        satisStokunuYaz(&v, satis: satis(["type": .metin("honey"), "qty": .tam(1), "payment": .metin("zekat"), "customer": .yok]), onceki: nil, urunBirimi: .kg, kimlik: kimlik)
        XCTAssertEqual(v.stokKayitlari[0].note, "Zekat: Müşteri")
    }
    func test_urunsuzSatisBagliKaydiSiler() {
        var v = veri([stok("suzme_bal", "out", .tam(3), saleId: "s1")])
        satisStokunuYaz(&v, satis: satis(["type": .metin("queen"), "qty": .tam(1)]), onceki: satis(["type": .metin("honey")]), urunBirimi: nil, kimlik: kimlik)
        XCTAssertTrue(v.stokKayitlari.isEmpty)
    }
    func test_saleIdsizEskiSatisYeniStokAcmaz() {
        var v = veri([stok("suzme_bal", "in", .tam(10))])
        let eski = satis(["type": .metin("honey"), "qty": .tam(2)])
        var yeni = eski; yeni.qty = 3
        satisStokunuYaz(&v, satis: yeni, onceki: eski, urunBirimi: .kg, kimlik: kimlik)
        XCTAssertEqual(v.stokKayitlari.count, 1)
        XCTAssertEqual(stokSeviyesi(v, urun: "suzme_bal"), 10)
    }
    func test_eskiSatisStoksuzduysaDuzenlemeStokAcar() {
        var v = veri([])
        let eski = satis(["type": .metin("queen"), "qty": .tam(2)])
        var yeni = eski; yeni.type = "honey"
        satisStokunuYaz(&v, satis: yeni, onceki: eski, urunBirimi: .kg, kimlik: kimlik)
        XCTAssertEqual(v.stokKayitlari.count, 1)
    }
    func test_bagliStokuSil() {
        var v = veri([stok("a", "out", .tam(1), saleId: "s1"), stok("a", "in", .tam(5))])
        bagliStokuSil(&v, saleId: "s1")
        XCTAssertEqual(v.stokKayitlari.count, 1)
    }
    func test_hasatStoguMilkIdli() {
        var v = veri([])
        let h = Hasat(["id": .metin("m1"), "amount": .tam(820), "date": .metin("2026-06-02"), "note": .metin("Seri 2")])
        hasatStokunuYaz(&v, hasat: h, kimlik: kimlik)
        let k = v.stokKayitlari[0]
        XCTAssertEqual(k.product, "ari_sutu")
        XCTAssertEqual(k.unit, "gr")
        XCTAssertEqual(k.action, "in")
        XCTAssertEqual(k.amount, 820)
        XCTAssertEqual(k.milkId, "m1")
        XCTAssertEqual(k.note, "Hasat: Seri 2")
        var h2 = h; h2.amount = 900; h2.note = nil
        hasatStokunuYaz(&v, hasat: h2, kimlik: kimlik)
        XCTAssertEqual(v.stokKayitlari.count, 1)
        XCTAssertEqual(v.stokKayitlari[0].note, "Hasat")
        XCTAssertEqual(v.stokKayitlari[0].amount, 900)
        hasatStokunuSil(&v, milkId: "m1")
        XCTAssertTrue(v.stokKayitlari.isEmpty)
    }
}
