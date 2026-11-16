import XCTest
@testable import AriCekirdek

// Bal Defterim kuralları: zekat (öşür) hasadın %10'u, devir/başlangıç stoğu hariç; verilen zekat düşülür.
// Ön sipariş stoğu rezerve gösterilir.

private func giris(_ p: String, _ m: Double, _ birim: String = "kg", tarih: String = "2026-06-10", not: String? = nil) -> JSONDeger {
    var k: Kayit = ["id": .metin(yeniKimlik()), "product": .metin(p), "action": .metin("in"), "amount": .sayidan(m), "unit": .metin(birim), "date": .metin(tarih)]
    if let not { k["note"] = .metin(not) }
    return .nesne(k)
}
private func satisK(_ p: String, _ m: Double, _ birim: String = "kg", odeme: String = "paid", durum: String? = nil, tarih: String = "2026-07-01", musteri: String = "Ali") -> JSONDeger {
    var k: Kayit = ["id": .metin(yeniKimlik()), "type": .metin("honey"), "product": .metin(p), "qty": .sayidan(m), "unit": .metin(birim),
                    "payment": .metin(odeme), "date": .metin(tarih), "customer": .metin(musteri), "total": .sayidan(m * 100)]
    if let durum { k["orderStatus"] = .metin(durum) }
    return .nesne(k)
}
private let sezon = SezonAraligi(baslangic: "2026-01-01", bitis: nil)

final class ZekatTests: XCTestCase {
    func test_hasadinYuzdeOnu_devirVeBaslangicHaric_birimCevrilir() {
        let v = BBVeri(ham: ["stock": .dizi([
            giris("suzme_bal", 100),
            giris("suzme_bal", 1000, "gr"),
            giris("suzme_bal", 50, not: "Başlangıç stoğu"),
            giris("suzme_bal", 30, not: "2025 sezonu devri"),
            giris("suzme_bal", 40, tarih: "2025-08-01"),
            giris("petek_bal", 20),
        ])])
        let z = zekatDurumu(v, urun: "suzme_bal", urunBirimi: .kg, aralik: sezon)
        XCTAssertEqual(z.hasat, 101, accuracy: 0.0001)
        XCTAssertEqual(z.borc, 10.1, accuracy: 0.0001)
        XCTAssertEqual(z.verilen, 0)
        XCTAssertEqual(z.kalan, 10.1, accuracy: 0.0001)
    }

    func test_verilenZekatDusulur_eksiyeInmez() {
        let v = BBVeri(ham: [
            "stock": .dizi([giris("suzme_bal", 100)]),
            "sales": .dizi([satisK("suzme_bal", 5, odeme: "zekat"), satisK("suzme_bal", 2000, "gr", odeme: "zekat"),
                            satisK("suzme_bal", 30), satisK("petek_bal", 4, odeme: "zekat"),
                            satisK("suzme_bal", 9, odeme: "zekat", tarih: "2025-09-01")]),
        ])
        let z = zekatDurumu(v, urun: "suzme_bal", urunBirimi: .kg, aralik: sezon)
        XCTAssertEqual(z.verilen, 7, accuracy: 0.0001)
        XCTAssertEqual(z.kalan, 3, accuracy: 0.0001)

        let fazla = BBVeri(ham: ["stock": .dizi([giris("suzme_bal", 10)]), "sales": .dizi([satisK("suzme_bal", 5, odeme: "zekat")])])
        XCTAssertEqual(zekatDurumu(fazla, urun: "suzme_bal", urunBirimi: .kg, aralik: sezon).kalan, 0)
    }
}

final class RezerveTests: XCTestCase {
    func test_onSiparisRezerve_teslimEdilenSayilmaz() {
        let v = BBVeri(ham: ["sales": .dizi([
            satisK("suzme_bal", 3, durum: "preorder"),
            satisK("suzme_bal", 500, "gr", durum: "preorder"),
            satisK("suzme_bal", 10, durum: "delivered"),
            satisK("suzme_bal", 4),
            satisK("petek_bal", 2, durum: "preorder"),
        ])])
        XCTAssertEqual(rezerveMiktar(v, urun: "suzme_bal", urunBirimi: .kg), 3.5, accuracy: 0.0001)
        XCTAssertEqual(rezerveMiktar(v, urun: "petek_bal", urunBirimi: .kg), 2, accuracy: 0.0001)
        XCTAssertEqual(rezerveMiktar(v, urun: "polen", urunBirimi: .kg), 0)
    }
}

final class MusteriGecmisiTests: XCTestCase {
    func test_tumSezonlar_adBuyukKucukVeBoslukDuyarsiz_yeniOnce() {
        let s = BBVeri(ham: ["sales": .dizi([
            satisK("suzme_bal", 1, tarih: "2025-05-01", musteri: "Ayşe Demir"),
            satisK("suzme_bal", 2, tarih: "2026-07-01", musteri: " ayşe demir "),
            satisK("suzme_bal", 3, tarih: "2026-07-02", musteri: "AYŞE DEMİR"),
            satisK("suzme_bal", 4, tarih: "2026-07-03", musteri: "Ali"),
        ])]).satislar
        let g = musteriGecmisi(s, musteri: "Ayşe Demir")
        XCTAssertEqual(g.map(\.qty), [3, 2, 1])
    }
}
