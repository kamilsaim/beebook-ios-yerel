import XCTest
@testable import AriCekirdek

final class DepoTests: XCTestCase {
    private func kovanEkle(_ d: inout DepoDurumu, _ id: String, _ num: String, simdi: Int64) {
        d.degistir(simdi: simdi) { v in
            var k = v.kovanlar
            k.append(Kovan(["id": .metin(id), "num": .metin(num)]))
            v.kovanlar = k
        }
    }

    func test_degisiklikDamgalarVeBekletir() {
        var d = DepoDurumu()
        kovanEkle(&d, "h1", "1", simdi: 100)
        XCTAssertEqual(d.veri.koleksiyon("hives").first?.up, 100)
        XCTAssertTrue(d.bekleyen)
        d.gonderildi()
        XCTAssertFalse(d.bekleyen)
        d.degistir(simdi: 200) { v in var k = v.kovanlar; k[0].num = "9"; v.kovanlar = k }
        XCTAssertEqual(d.veri.koleksiyon("hives").first?.up, 200)
        d.degistir(simdi: 300) { v in v.kovanlar = [] }
        XCTAssertEqual(d.veri.koleksiyon("deleted").first?.id, "h1")
    }

    func test_bekleyenDegisiklikOnbellektenGeriYuklenir() throws {
        var d = DepoDurumu()
        kovanEkle(&d, "h1", "1", simdi: 100)
        let geri = try DepoDurumu.coz(try d.kodla())
        XCTAssertTrue(geri.bekleyen)
        XCTAssertEqual(geri.veri.kovanlar.first?.num, "1")
        XCTAssertEqual(geri, d)
        // geri yüklenen anlık görüntüyle değişmeyen kayıt yeniden damgalanmaz
        var g2 = geri
        g2.degistir(simdi: 500) { _ in }
        XCTAssertEqual(g2.veri.koleksiyon("hives").first?.up, 100)
    }

    func test_uzakBirlesinceYerelFazlasiGonderilir() {
        var d = DepoDurumu()
        kovanEkle(&d, "yerel", "1", simdi: 100)
        let uzak = BBVeri(ham: ["hives": .dizi([.nesne(["id": .metin("uzak"), "num": .metin("2"), "_up": .tam(50)])])])
        let r = d.uzakIleBirlestir(uzak, nil)
        XCTAssertTrue(r.uzakKirli)
        XCTAssertTrue(r.yerelKirli)
        XCTAssertTrue(d.bekleyen)
        XCTAssertEqual(Set(d.veri.kovanlar.map(\.id)), ["yerel", "uzak"])
    }

    func test_uzakAyniysaBekleyenTemizlenir() {
        var d = DepoDurumu()
        kovanEkle(&d, "h1", "1", simdi: 100)
        let ayni = d.veri
        let r = d.uzakIleBirlestir(ayni, d.ayarlar)
        XCTAssertFalse(r.uzakKirli)
        XCTAssertFalse(d.bekleyen)
    }

    func test_ayarDegisikligiUpDamgalar() {
        var d = DepoDurumu()
        d.ayarDegistir(simdi: 777) { $0.city = "Muğla" }
        XCTAssertEqual(d.ayarlar.ham.up, 777)
        XCTAssertEqual(d.ayarlar.city, "Muğla")
        XCTAssertTrue(d.bekleyen)
    }

    func test_kovanDuzenleBilinmeyeniKorur() {
        var d = DepoDurumu(veri: BBVeri(ham: ["hives": .dizi([.nesne(["id": .metin("a"), "num": .metin("1"), "webAlani": .metin("x")])])]))
        d.degistir(simdi: 10) { v in var k = v.kovanlar; k[0].num = "2"; k[0].race = "Kafkas"; v.kovanlar = k }
        let h = d.veri.koleksiyon("hives")[0]
        XCTAssertEqual(h["webAlani"], .metin("x"))
        XCTAssertEqual(h["race"], .metin("Kafkas"))
    }

    func test_demoVeriUzakGelinceAtilir() {
        var d = DepoDurumu(veri: BBVeri(ham: ["_demo": .bool(true), "hives": .dizi([.nesne(["id": .metin("demo1"), "num": .metin("1")])])]))
        let uzak = BBVeri(ham: ["hives": .dizi([.nesne(["id": .metin("gercek"), "num": .metin("5"), "_up": .tam(1)])])])
        _ = d.uzakIleBirlestir(uzak, Ayarlar(ham: ["city": .metin("Aydın")]))
        XCTAssertEqual(d.veri.kovanlar.map(\.id), ["gercek"])
        XCTAssertFalse(d.veri.demo)
        XCTAssertEqual(d.ayarlar.city, "Aydın")
    }

    func test_ilkSezonBirKezOlusur() {
        var d = DepoDurumu()
        XCTAssertTrue(d.sezonYoksaOlustur(buYil: 2026, simdi: 1))
        XCTAssertFalse(d.sezonYoksaOlustur(buYil: 2026, simdi: 2))
        XCTAssertEqual(d.veri.sezonlar.count, 1)
        XCTAssertEqual(d.veri.sezonlar[0].name, "2026 Sezonu")
        XCTAssertEqual(d.ayarlar.activeSeason, d.veri.sezonlar[0].id)
    }
}
