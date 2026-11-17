import XCTest
@testable import AriCekirdek

// Android cekirdek BalDefterimAktarimTests ile aynı senaryolar.

private let yedekMetni = """
{"sezonlar":[{"id":"s25","ad":"2025 Sezonu"},{"id":"s26","ad":"2026 Sezonu"}],
 "aktifSezon":"s26","fiyatlar":{"suzme":650,"polen":900},
 "urunler":[{"id":"suzme","ad":"Süzme Bal","ikon":"🍯","birim":"kg"},
            {"id":"polen","ad":"Polen","ikon":"🌼","birim":"kg"},
            {"id":"ana-ari","ad":"Ana Arı","ikon":"👑","birim":"adet","zekat":false}],
 "hasatlar":[{"id":"h1","sezon_id":"s26","urun":"suzme","miktar":100,"tarih":"2026-07-01","tip":"hasat"},
             {"id":"h2","sezon_id":"s26","urun":"suzme","miktar":20,"tarih":"2026-01-02","tip":"devir"},
             {"id":"h3","sezon_id":"s26","urun":"polen","miktar":5,"tarih":"2026-07-03"}],
 "siparisler":[{"id":"o1","sezon_id":"s26","musteri":"Ali","tel":"0555","urun":"suzme","miktar":3,"fiyat":650,"tarih":"2026-08-01","hediye":false,"teslim":true,"odendi":true},
               {"id":"o2","sezon_id":"s26","musteri":"Veli","urun":"suzme","miktar":2,"fiyat":650,"tutar":1200,"tarih":"2026-08-02","hediye":false,"teslim":false,"odendi":false,"odenen":500},
               {"id":"o3","sezon_id":"s26","musteri":"Ayşe","urun":"polen","miktar":1,"fiyat":900,"tarih":"2026-08-03","hediye":true,"teslim":true,"odendi":false}],
 "zekatlar":[{"id":"z1","sezon_id":"s26","urun":"suzme","miktar":4,"tarih":"2026-09-01"}]}
"""

final class BalDefterimAktarimTests: XCTestCase {
    private func yedek() throws -> JSONDeger { try JSONDecoder().decode(JSONDeger.self, from: Data(yedekMetni.utf8)) }

    private func bosVeri() -> BBVeri {
        var v = BBVeri()
        var s = Sezon(["id": .metin("bb26")]); s.year = 2026; s.name = "2026 Sezonu"
        v.sezonlar = [s]
        return v
    }

    @discardableResult
    private func aktar(_ v: inout BBVeri, _ a: inout Ayarlar) throws -> BalAktarim {
        let t = balDefterimAktarimi(try yedek(), veri: v, ayarlar: a)
        t.ayarlaraUygula(&a)
        let urunler = a.stockTypesTanimli ? a.stockTypes : hazirUrunler
        t.veriyeUygula(&v) { u in urunler.first { $0.v == u }.flatMap { Birim(rawValue: $0.unit) } }
        return t
    }

    func test_yedekTaninir() throws {
        XCTAssertTrue(balDefterimYedegiMi(try yedek()))
        XCTAssertFalse(balDefterimYedegiMi(.nesne(["data": .nesne([:]), "settings": .nesne([:])])))
    }

    func test_urunlerEslenirVeEklenir() throws {
        var v = bosVeri(); var a = Ayarlar()
        let t = try aktar(&v, &a)
        XCTAssertEqual(t.urunEsleme["suzme"], "suzme_bal")
        XCTAssertEqual(t.yeniUrunler.map(\.v), ["polen", "ana_ari"])
        XCTAssertEqual(a.stockTypes.first { $0.v == "ana_ari" }?.zakat, false)
        XCTAssertEqual(a.stockPrices["suzme_bal"], 650)
        XCTAssertEqual(a.stockPrices["polen"], 900)
    }

    func test_kayitlarVeStok() throws {
        var v = bosVeri(); var a = Ayarlar()
        let t = try aktar(&v, &a)
        XCTAssertEqual(t.ozet, "3 sipariş · 3 hasat · 1 zekat · 2 yeni ürün · 1 yeni sezon")
        XCTAssertEqual(v.sezonlar.map(\.name), ["2026 Sezonu", "2025 Sezonu"])
        var s: [String: Satis] = [:]
        for x in v.satislar { s[x.id] = x }
        XCTAssertEqual(s["bd-s-o1"]?.payment, "paid"); XCTAssertEqual(s["bd-s-o1"]?.total, 1950)
        XCTAssertEqual(s["bd-s-o2"]?.payment, "partial"); XCTAssertEqual(s["bd-s-o2"]?.paidAmount, 500); XCTAssertEqual(s["bd-s-o2"]?.total, 1200)
        XCTAssertEqual(s["bd-s-o2"]?.orderStatus, "preorder")
        XCTAssertEqual(s["bd-s-o3"]?.payment, "hediye"); XCTAssertEqual(s["bd-s-o3"]?.total, 0)
        XCTAssertEqual(s["bd-z-z1"]?.payment, "zekat")
        // Süzme: 100 + 20 devir − 3 − 2 − 4 zekat = 111
        XCTAssertEqual(stokSeviyesi(v, urun: "suzme_bal"), 111)
        XCTAssertEqual(stokSeviyesi(v, urun: "polen"), 4)
        // Zekat: devir hariç hasadın %10'u = 10, verilen 4
        let z = zekatDurumu(v, urun: "suzme_bal", urunBirimi: .kg, aralik: nil)
        XCTAssertEqual(z.borc, 10); XCTAssertEqual(z.verilen, 4)
    }

    func test_ikinciYuklemeKopyaYapmaz() throws {
        var v = bosVeri(); var a = Ayarlar()
        try aktar(&v, &a)
        let ikinci = try aktar(&v, &a)
        XCTAssertEqual(ikinci.yeniUrunler.count, 0); XCTAssertEqual(ikinci.yeniSezonlar.count, 0)
        XCTAssertEqual(v.satislar.count, 4)
        XCTAssertEqual(v.stokKayitlari.count, 3 + 4)
        XCTAssertEqual(stokSeviyesi(v, urun: "suzme_bal"), 111)
    }
}
