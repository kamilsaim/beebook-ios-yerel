import XCTest
@testable import AriCekirdek

/// Android ViziltiTests ile aynı cümleler.
final class ViziltiTests: XCTestCase {

    func test_kilavuzOrnegi1() {
        let s = viziltiAyristir("3 numaralı kovan bakım. 5 çerçeve, ana görüldü, yumurta var, durumu güçlü.")
        XCTAssertEqual(s.niyet, .muayene)
        XCTAssertEqual(s.kovanNo, "3")
        XCTAssertEqual(s.cerceve, 5)
        XCTAssertEqual(s.anaGoruldu, true)
        XCTAssertFalse(s.anaYok)
        XCTAssertEqual(s.yumurta, true)
        XCTAssertEqual(s.guc, 4)
        XCTAssertNil(s.yavru); XCTAssertNil(s.besleme); XCTAssertNil(s.not)
    }

    func test_kilavuzOrnegi2() {
        let s = viziltiAyristir("7 numaralı kovan. Ana görülmedi, yavru seyrek, zayıf. Bir litre şurup verdim. Üç gün sonra bakacağım.")
        XCTAssertEqual(s.kovanNo, "7")
        XCTAssertEqual(s.anaGoruldu, false)
        XCTAssertFalse(s.anaYok)
        XCTAssertEqual(s.yavru, "seyrek")
        XCTAssertEqual(s.guc, 2)
        XCTAssertEqual(s.besleme, "1 litre şurup")
        XCTAssertEqual(s.gunSonra, 3)
        XCTAssertNil(s.yumurta); XCTAssertNil(s.not)
    }

    func test_noktalamasizVeYaziylaSayilar() {
        let s = viziltiAyristir("on iki nolu kovan ana var yumurta yok yavru düzenli çok güçlü iki buçuk kilo kek verdim")
        XCTAssertEqual(s.kovanNo, "12")
        XCTAssertEqual(s.anaGoruldu, true)
        XCTAssertEqual(s.yumurta, false)
        XCTAssertEqual(s.yavru, "duzenli")
        XCTAssertEqual(s.guc, 5)
        XCTAssertEqual(s.besleme, "2,5 kilo kek")
    }

    func test_kovanNumarasiBicimleri() {
        XCTAssertEqual(viziltiAyristir("kovan 4 ana görüldü").kovanNo, "4")
        XCTAssertEqual(viziltiAyristir("15 no'lu kovanda ana yok").kovanNo, "15")
        XCTAssertEqual(viziltiAyristir("dokuzuncu değil 9. kovan güçlü").kovanNo, "9")
        XCTAssertEqual(viziltiAyristir("yirmi bir numaralı kovan orta").kovanNo, "21")
        XCTAssertEqual(viziltiAyristir("kovan numarası altı zayıf").kovanNo, "6")
    }

    func test_anaYokAyriTutulur() {
        let s = viziltiAyristir("5 nolu kovan ana yok")
        XCTAssertEqual(s.anaGoruldu, false)
        XCTAssertTrue(s.anaYok)
    }

    func test_anlasilmayanNotaGider() {
        let s = viziltiAyristir("3 numaralı kovan ana görüldü kapakta biraz rutubet var")
        XCTAssertEqual(s.anaGoruldu, true)
        XCTAssertEqual(s.not, "Kapakta biraz rutubet var")
    }

    func test_anlasilmayanAlanBosKalir() {
        let s = viziltiAyristir("8 numaralı kovan")
        XCTAssertEqual(s.niyet, .muayene)
        XCTAssertNil(s.anaGoruldu); XCTAssertNil(s.yumurta); XCTAssertNil(s.yavru); XCTAssertNil(s.guc); XCTAssertNil(s.cerceve)
    }

    func test_hicbirSeyAnlasilmazsa() {
        let s = viziltiAyristir("bugün hava çok güzel")
        XCTAssertEqual(s.niyet, .bilinmiyor)
        XCTAssertEqual(s.not, "Hava çok güzel")
    }

    func test_balSagimi() {
        let s = viziltiAyristir("3 numaralı kovandan 10 çerçeve bal aldım")
        XCTAssertEqual(s.niyet, .balSagimi)
        XCTAssertEqual(s.kovanNo, "3")
        XCTAssertEqual(s.balCerceve, 10)
        XCTAssertNil(s.cerceve)
        let k = viziltiAyristir("12 numaralı kovandan dört kilo bal aldım")
        XCTAssertEqual(k.niyet, .balSagimi)
        XCTAssertEqual(k.balKg, 4.0)
        XCTAssertNil(k.not)
    }

    func test_hatirlatmaBicimleri() {
        XCTAssertEqual(viziltiAyristir("2 hafta sonra bak").gunSonra, 14)
        XCTAssertEqual(viziltiAyristir("haftaya bakarım").gunSonra, 7)
        XCTAssertEqual(viziltiAyristir("yarın tekrar bak").gunSonra, 1)
    }

    func test_cerceveSayisiYazili() {
        XCTAssertEqual(viziltiAyristir("çerçeve sayısı sekiz").cerceve, 8)
        XCTAssertEqual(viziltiAyristir("on sekiz çerçeve var").cerceve, 18)
    }

    func test_cerceveVeHatirlatmaYanYana() {
        let s = viziltiAyristir("7 numaralı kovan ana görülmedi yavru seyrek zayıf bir litre şurup verdim 12 çerçeve üç gün sonra bakacağım kapakta rutubet var")
        XCTAssertEqual(s.cerceve, 12)
        XCTAssertEqual(s.gunSonra, 3)
        XCTAssertEqual(s.besleme, "1 litre şurup")
        XCTAssertEqual(s.not, "Kapakta rutubet var")
    }

    func test_varroaSeritTakma() {
        let s = viziltiAyristir("3 numaralı kovan varroa şeridi taktım 12 akar düştü")
        XCTAssertEqual(s.niyet, .muayene)
        XCTAssertEqual(s.varroaIslem, "takildi")
        XCTAssertEqual(s.varroaSayi, 12)
        XCTAssertNil(s.varroaIlac); XCTAssertNil(s.not)
    }

    func test_varroaIlacAdiyla() {
        let a = viziltiAyristir("5 nolu kovan amitraz şerit taktım")
        XCTAssertEqual(a.varroaIlac, "Amitraz"); XCTAssertEqual(a.varroaIslem, "takildi")
        let o = viziltiAyristir("kovan 8 oksalik asit damlattım ana görüldü")
        XCTAssertEqual(o.varroaIlac, "Oksalik asit"); XCTAssertEqual(o.varroaIslem, "uygulandi"); XCTAssertEqual(o.anaGoruldu, true)
        let c = viziltiAyristir("7 numaralı kovan şeridi çıkardım varroa yok")
        XCTAssertEqual(c.varroaIslem, "cikarildi"); XCTAssertEqual(c.varroaSayi, 0)
        let k = viziltiAyristir("2 numaralı kovan akar sayısı beş")
        XCTAssertEqual(k.varroaSayi, 5); XCTAssertNil(k.cerceve)
    }

    func test_acikKapaliYavru() {
        let s = viziltiAyristir("4 numaralı kovan ana görüldü açık yavru var kapalı yavru yok")
        XCTAssertEqual(s.acikYavru, true); XCTAssertEqual(s.kapaliYavru, false); XCTAssertNil(s.yavru); XCTAssertNil(s.not)
        let b = viziltiAyristir("kovan 2 açık ve kapalı yavru var yavru düzenli")
        XCTAssertEqual(b.acikYavru, true); XCTAssertEqual(b.kapaliYavru, true); XCTAssertEqual(b.yavru, "duzenli")
        XCTAssertEqual(viziltiAyristir("kovan 3 kapalı yavru seyrek").yavru, "seyrek")
    }

    func test_buyukHarfliTurkce() {
        // Konuşma tanıma cümle başını büyük yazar: "İki", "Ilık" (I → ı)
        let s = viziltiAyristir("İki numaralı kovan ANA GÖRÜLDÜ")
        XCTAssertEqual(s.kovanNo, "2"); XCTAssertEqual(s.anaGoruldu, true)
    }

    func test_kovanEslemesi() {
        let l = [Kovan(["id": .metin("a"), "num": .metin("03")]), Kovan(["id": .metin("b"), "num": .metin("12")]), Kovan(["id": .metin("c"), "num": .metin("A5")])]
        XCTAssertEqual(viziltiKovanBul("3", l).map(\.id), ["a"])
        XCTAssertEqual(viziltiKovanBul("12", l).map(\.id), ["b"])
        XCTAssertEqual(viziltiKovanBul("a5", l).map(\.id), ["c"])
        XCTAssertTrue(viziltiKovanBul("7", l).isEmpty)
        XCTAssertTrue(viziltiKovanBul(nil, l).isEmpty)
    }

    func test_otomatikKatKurali() {
        XCTAssertEqual(otomatikKat(0), 1); XCTAssertEqual(otomatikKat(10), 1)
        XCTAssertEqual(otomatikKat(11), 2); XCTAssertEqual(otomatikKat(20), 2)
        XCTAssertEqual(otomatikKat(21), 3); XCTAssertEqual(otomatikKat(30), 3)
        XCTAssertEqual(balKgTahmini(10), 30.0)
        XCTAssertEqual(balKgTahmini(10, 2.5), 25.0)
    }
}

/// Android KovanSirasiTests ile aynı.
final class KovanSirasiTests: XCTestCase {
    private func kv(_ id: String, _ num: String, yildiz: Bool = false) -> Kovan {
        var k: Kayit = ["id": .metin(id), "num": .metin(num)]
        if yildiz { k["starred"] = .bool(true) }
        return Kovan(k)
    }
    private var a: Kovan { kv("a", "1") }
    private var b: Kovan { kv("b", "2") }
    private var c: Kovan { kv("c", "10") }
    private var d: Kovan { kv("d", "3", yildiz: true) }

    func test_siraYokkenNumaraVeYildiz() {
        XCTAssertEqual(KovanSirasi.sirala([c, b, a, d], nil).map(\.id), ["d", "a", "b", "c"])
    }
    func test_elleSiraYildizliOnde() {
        XCTAssertEqual(KovanSirasi.sirala([a, b, c, d], ["c", "d", "a", "b"]).map(\.id), ["d", "c", "a", "b"])
    }
    func test_siradaOlmayanSondaNumarayla() {
        let e = kv("e", "4")
        XCTAssertEqual(KovanSirasi.sirala([a, b, c, d, e], ["b", "a"]).map(\.id), ["d", "b", "a", "e", "c"])
    }
    func test_filtreliYerlestirmeGizlileriKorur() {
        let tum = KovanSirasi.sirala([a, b, c, d], nil)
        XCTAssertEqual(KovanSirasi.yerlestir(tum, ["c", "a"]), ["d", "c", "b", "a"])
    }
    func test_yildizsizYildizliOnuneGecemez() {
        let tum = KovanSirasi.sirala([a, b, c, d], nil)
        XCTAssertEqual(KovanSirasi.yerlestir(tum, ["b", "d", "a", "c"]), ["d", "b", "a", "c"])
    }
    func test_tasi() {
        XCTAssertEqual(KovanSirasi.tasi([1, 2, 3, 4], 0, 2), [2, 3, 1, 4])
        XCTAssertEqual(KovanSirasi.tasi([1, 2, 3, 4], 3, 0), [4, 1, 2, 3])
        XCTAssertEqual(KovanSirasi.tasi([1, 2], 0, 5), [1, 2])
    }
}
