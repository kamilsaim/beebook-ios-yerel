import XCTest
@testable import AriCekirdek

private func sezon(_ id: String, _ start: String?, year: Int) -> JSONDeger {
    var k: Kayit = ["id": .metin(id), "year": .tam(Int64(year)), "name": .metin("\(year) Sezonu")]
    if let start { k["start"] = .metin(start) }
    return .nesne(k)
}
private func kovan(_ id: String, _ num: String, _ tip: String = "Langstroth") -> JSONDeger {
    .nesne(["id": .metin(id), "num": .metin(num), "type": .metin(tip)])
}
private func satisK(_ ek: Kayit) -> Satis {
    var k: Kayit = ["id": .metin(yeniKimlik()), "date": .metin("2026-11-01"), "payment": .metin("paid")]
    for (a, b) in ek { k[a] = b }
    return Satis(k)
}

final class SezonTests: XCTestCase {
    func test_sezonBaslangiciVarsayilan() {
        XCTAssertEqual(sezonBaslangici(Sezon(["year": .tam(2025)])), "2025-01-01")
        XCTAssertEqual(sezonBaslangici(Sezon(["year": .tam(2025), "start": .metin("2025-03-01")])), "2025-03-01")
    }
    func test_tekSezondaFiltreYok() {
        let v = BBVeri(ham: ["seasons": .dizi([sezon("a", nil, year: 2026)])])
        XCTAssertNil(aktifSezonAraligi(v, aktif: "a"))
        XCTAssertTrue(sezonda("1999-01-01", nil))
    }
    func test_aktifSezonAraligi() {
        let v = BBVeri(ham: ["seasons": .dizi([sezon("s25", "2025-01-01", year: 2025), sezon("s26", "2026-03-01", year: 2026)])])
        XCTAssertEqual(aktifSezonAraligi(v, aktif: "s26"), SezonAraligi(baslangic: "2026-03-01", bitis: nil))
        XCTAssertEqual(aktifSezonAraligi(v, aktif: "s25"), SezonAraligi(baslangic: nil, bitis: "2026-03-01"))
        XCTAssertNil(aktifSezonAraligi(v, aktif: "yok"))
    }
    func test_sezondaSinirlar() {
        let a = SezonAraligi(baslangic: "2026-03-01", bitis: "2027-03-01")
        XCTAssertTrue(sezonda("2026-03-01", a))
        XCTAssertFalse(sezonda("2027-03-01", a))
        XCTAssertFalse(sezonda("2026-02-28", a))
        XCTAssertTrue(sezonda("2026-05-05T10:00", a))
        XCTAssertTrue(sezonda(nil, a))
        let k: [Kayit] = [["date": .metin("2026-04-01")], ["date": .metin("2025-04-01")]]
        XCTAssertEqual(sezonaGore(k, a).count, 1)
    }
}

final class OdemeTests: XCTestCase {
    func test_kismiKalan() {
        let s = satisK(["total": .tam(800), "payment": .metin("partial"), "paidAmount": .tam(500)])
        XCTAssertEqual(odenen(s.ham), 500)
        XCTAssertEqual(kalan(s.ham), 300)
    }
    func test_odenmisVeBekleyen() {
        XCTAssertEqual(kalan(satisK(["total": .tam(800)]).ham), 0)
        XCTAssertEqual(odenen(satisK(["total": .tam(800)]).ham), 800)
        XCTAssertEqual(kalan(satisK(["total": .metin("800"), "payment": .metin("pending")]).ham), 800)
        // gider: payment yoksa ödenmiş sayılır
        XCTAssertEqual(kalan(["amount": .tam(100)]), 0)
        XCTAssertEqual(kalan(["amount": .tam(100), "payment": .metin("pending")]), 100)
    }
    func test_hediyeKalanSifir() {
        XCTAssertEqual(kalan(satisK(["total": .tam(0), "payment": .metin("hediye")]).ham), 0)
        XCTAssertEqual(odenen(satisK(["total": .tam(0), "payment": .metin("zekat")]).ham), 0)
    }
    func test_bekleyenToplam() {
        let s = [satisK(["total": .tam(800), "payment": .metin("partial"), "paidAmount": .tam(500)]),
                 satisK(["total": .tam(200), "payment": .metin("pending")]),
                 satisK(["total": .tam(999)])]
        XCTAssertEqual(bekleyenToplam(satislar: s), 500)
    }
}

final class AnaAriTests: XCTestCase {
    func test_anaRengiTablosu() {
        XCTAssertEqual(anaRengi(yil: 2026), "white")
        XCTAssertEqual(anaRengi(yil: 2025), "blue")
        XCTAssertEqual(anaRengi(yil: 2024), "green")
        XCTAssertEqual(anaRengi(yil: 2023), "red")
        XCTAssertEqual(anaRengi(yil: 2022), "yellow")
        XCTAssertEqual(anaRengi(yil: 2021), "white")
        XCTAssertEqual(anaRengi(yil: 2020), "blue")
    }
    func test_anaYasi() {
        XCTAssertEqual(anaYasi(yil: 2024, buYil: 2026), 2)
    }
    func test_gelisimTakvimiGunleri() {
        let t = gelisimTakvimi(transfer: "2026-11-04")
        XCTAssertEqual(t.map(\.ad), ["Transfer", "Kapanma", "Pupa", "Dağıtım", "Çıkım"])
        XCTAssertEqual(t.map(\.gun), [0, 4, 6, 10, 12])
        XCTAssertEqual(t.map(\.tarih), ["2026-11-04", "2026-11-08", "2026-11-10", "2026-11-14", "2026-11-16"])
        XCTAssertEqual(gelisimTakvimi(transfer: "2026-12-28").last?.tarih, "2027-01-09")
    }
    func test_aktifAdim() {
        XCTAssertEqual(aktifAdimIndeksi(transfer: "2026-11-04", bugun: "2026-11-10"), 2)
        XCTAssertEqual(aktifAdimIndeksi(transfer: "2026-11-04", bugun: "2026-11-09"), 1)
        XCTAssertEqual(aktifAdimIndeksi(transfer: "2026-11-04", bugun: "2026-11-20"), 4)
        XCTAssertEqual(aktifAdimIndeksi(transfer: "2026-11-04", bugun: "2026-11-01"), -1)
    }
}

final class TopluIsTests: XCTestCase {
    private var kovanlar: [Kovan] {
        let v = BBVeri(ham: ["hives": .dizi((1...20).map { kovan("h\($0)", "\($0)", $0 % 2 == 0 ? "Dadant" : "Langstroth") })])
        return v.kovanlar
    }
    func test_topluIsAralik() {
        XCTAssertEqual(topluIsKovanlari("12-18", kovanlar: kovanlar), (12...18).map { "h\($0)" })
    }
    func test_topluIsListe() {
        XCTAssertEqual(topluIsKovanlari("1,3, 5", kovanlar: kovanlar), ["h1", "h3", "h5"])
        XCTAssertEqual(topluIsKovanlari("1-3, 7", kovanlar: kovanlar), ["h1", "h2", "h3", "h7"])
        XCTAssertEqual(topluIsKovanlari("5,3,5", kovanlar: kovanlar), ["h3", "h5"])
    }
    func test_topluIsTumTip() {
        XCTAssertEqual(topluIsKovanlari("Tüm Langstroth", kovanlar: kovanlar).count, 10)
        XCTAssertEqual(topluIsKovanlari("tüm dadant", kovanlar: kovanlar).count, 10)
        XCTAssertEqual(topluIsKovanlari("Tümü", kovanlar: kovanlar).count, 20)
        XCTAssertEqual(topluIsKovanlari("tüm", kovanlar: kovanlar).count, 20)
    }
    func test_topluIsHataliGiris() {
        XCTAssertEqual(topluIsKovanlari("18-12", kovanlar: kovanlar).count, 7)
        XCTAssertEqual(topluIsKovanlari("1,,3", kovanlar: kovanlar), ["h1", "h3"])
        XCTAssertEqual(topluIsKovanlari("12-", kovanlar: kovanlar), [])
        XCTAssertEqual(topluIsKovanlari("999", kovanlar: kovanlar), [])
        XCTAssertEqual(topluIsKovanlari("", kovanlar: kovanlar), [])
        XCTAssertEqual(topluIsKovanlari("şurup ver", kovanlar: kovanlar), [])
        XCTAssertEqual(topluIsKovanlari("1-100000000", kovanlar: kovanlar).count, 20)
    }
}

final class RaporTests: XCTestCase {
    func test_stokRaporuYalnizGirisliUrun() {
        let v = BBVeri(ham: [
            "stock": .dizi([
                .nesne(["id": .metin("1"), "product": .metin("suzme_bal"), "action": .metin("in"), "amount": .tam(60)]),
                .nesne(["id": .metin("2"), "product": .metin("suzme_bal"), "action": .metin("out"), "amount": .tam(17), "saleId": .metin("a")])
            ]),
            "sales": .dizi([
                .nesne(["id": .metin("a"), "type": .metin("honey"), "honeyType": .metin("suzme_bal"), "qty": .tam(15), "total": .tam(5250), "payment": .metin("paid")]),
                .nesne(["id": .metin("b"), "type": .metin("honey"), "qty": .tam(2), "total": .tam(0), "payment": .metin("hediye")]),
                .nesne(["id": .metin("c"), "type": .metin("honey"), "product": .metin("petek_bal"), "qty": .tam(1), "total": .tam(400), "payment": .metin("paid")])
            ])
        ])
        let urunler = [UrunTanimi(["v": .metin("suzme_bal"), "l": .metin("🍯 Süzme Bal"), "unit": .metin("kg")]),
                       UrunTanimi(["v": .metin("petek_bal"), "l": .metin("🍯 Petek Bal"), "unit": .metin("kg")])]
        let r = stokRaporu(v, urunler: urunler)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0], UrunRaporSatiri(urun: "suzme_bal", giris: 60, satisMiktar: 15, satisTutar: 5250, hediye: 2, zekat: 0, mevcut: 43))
    }
    func test_zekatYuzde10() {
        XCTAssertEqual(zekatMiktari(43), 4.3, accuracy: 1e-9)
    }
    func test_satisRaporuGruplar() {
        let s = [satisK(["type": .metin("honey"), "honeyType": .metin("suzme_bal"), "qty": .tam(5), "total": .tam(1750), "unit": .metin("kg")]),
                 satisK(["type": .metin("honey"), "qty": .tam(2), "total": .tam(0), "payment": .metin("hediye"), "unit": .metin("kg")]),
                 satisK(["type": .metin("other"), "product": .metin("propolis"), "qty": .tam(1), "total": .tam(4800), "unit": .metin("lt")]),
                 satisK(["type": .metin("queen"), "qty": .tam(3), "total": .tam(2400), "unit": .metin("adet")])]
        let g = satisRaporu(s)
        let bal = g.first { $0.anahtar == "urun_suzme_bal" }
        XCTAssertEqual(bal?.satis, 5); XCTAssertEqual(bal?.hediye, 2); XCTAssertEqual(bal?.satisTl, 1750); XCTAssertEqual(bal?.satisAdet, 1)
        XCTAssertEqual(g.first { $0.anahtar == "urun_propolis" }?.unit, "lt")
        XCTAssertEqual(g.first { $0.anahtar == "tur_queen" }?.satisTl, 2400)
        XCTAssertEqual(g.count, 3)
    }
    func test_giderRaporu() {
        let gid = [Gider(["type": .metin("yem"), "amount": .tam(100)]), Gider(["type": .metin("yem"), "amount": .metin("50")]),
                   Gider(["type": .metin("ilac"), "amount": .tam(30)]), Gider(["type": .metin("bilinmeyen"), "amount": .tam(5)])]
        let r = giderRaporu(gid, turler: ["ilac", "yem", "arac"])
        XCTAssertEqual(r.map(\.tur), ["ilac", "yem", "bilinmeyen"])
        XCTAssertEqual(r[1].adet, 2); XCTAssertEqual(r[1].toplam, 150)
    }
}

final class YedekTests: XCTestCase {
    func test_yedekEksikKoleksiyonTamamlanir() throws {
        let j = try cozJSON(#"{"data":{"hives":[{"id":"a"},{"num":"idsiz"},5],"seasons":[{"id":"s"}],"deleted":"bozuk"},"settings":{"city":"X"}}"#)
        let (v, a) = try yedegiNormallestir(j, buYil: 2026)
        XCTAssertEqual(v.koleksiyon("hives").count, 1)
        XCTAssertEqual(v.koleksiyon("sales").count, 0)
        XCTAssertNotNil(v.ham["inspections"])
        XCTAssertNil(v.ham["deleted"])
        XCTAssertEqual(a?.city, "X")
    }
    func test_yedekListeDegilHata() throws {
        let j = try cozJSON(#"{"data":{"hives":{"a":1}}}"#)
        XCTAssertThrowsError(try yedegiNormallestir(j, buYil: 2026)) { e in
            XCTAssertEqual(e as? YedekHatasi, .listeDegil("hives"))
        }
        XCTAssertThrowsError(try yedegiNormallestir(try cozJSON(#"{"x":1}"#), buYil: 2026)) { e in
            XCTAssertEqual(e as? YedekHatasi, .veriYok)
        }
    }
    func test_yedekSezonYoksaOlusur() throws {
        let (v, a) = try yedegiNormallestir(try cozJSON(#"{"data":{}}"#), buYil: 2026)
        XCTAssertEqual(v.sezonlar.first?.id, "s2026")
        XCTAssertEqual(v.sezonlar.first?.name, "2026 Sezonu")
        XCTAssertEqual(v.sezonlar.first?.active, true)
        XCTAssertNil(a)
    }
}

final class BicimTests: XCTestCase {
    func test_tlBicimi() {
        XCTAssertEqual(tl(86450), "₺86.450")
        XCTAssertEqual(tl(1234567.5), "₺1.234.567,50")
        XCTAssertEqual(tl(0), "₺0")
        XCTAssertEqual(tl(-300), "-₺300")
    }
    func test_miktarBicimi() {
        XCTAssertEqual(miktar(1.5, "lt"), "1,5 lt")
        XCTAssertEqual(miktar(15, "kg"), "15 kg")
        XCTAssertEqual(miktar(0.25, "kg"), "0,25 kg")
        XCTAssertEqual(miktar(1200, "gr"), "1.200 gr")
    }
    func test_kisaTarih() {
        XCTAssertEqual(kisaTarih("2026-11-13"), "13 Kas")
        XCTAssertEqual(kisaTarih("2026-01-05T10:00"), "5 Oca")
        XCTAssertEqual(kisaTarih("bozuk"), "bozuk")
    }
}
