import XCTest
@testable import AriCekirdek

final class UrunlerTests: XCTestCase {
    private func ayar(_ ozel: Int) -> Ayarlar {
        var a = Ayarlar()
        a.stockTypes = hazirUrunler + (0..<ozel).map { UrunTanimi(["v": .metin("ozel\($0)"), "l": .metin("Özel \($0)"), "unit": .metin("lt")]) }
        return a
    }
    func test_hazirUrunlerWebVarsayilani() {
        XCTAssertEqual(hazirUrunler.map(\.v), ["suzme_bal", "petek_bal", "ari_sutu", "karakovan_bal"])
        XCTAssertEqual(hazirUrunler.map(\.unit), ["kg", "kg", "gr", "kg"])
    }
    func test_ozelUrunSayisiHazirlariSaymaz() {
        XCTAssertEqual(ozelUrunSayisi(ayar(3)), 3)
        XCTAssertEqual(ozelUrunSayisi(Ayarlar()), 0)
    }
    func test_21IncıUrunEklenemez() {
        XCTAssertTrue(urunEklenebilir(ayar(19)))
        XCTAssertFalse(urunEklenebilir(ayar(20)))
        XCTAssertEqual(ozelUrunSiniri, 20)
    }
    func test_urunKimligiWebSlug() {
        // web addStockTypeItem: toLowerCase, boşluk→_, [^a-z0-9çğışöü_] atılır
        XCTAssertEqual(urunKimligi(ad: "Bal Sirkesi", mevcut: []), "bal_sirkesi")
        XCTAssertEqual(urunKimligi(ad: "Çam Balı", mevcut: []), "çam_balı")
        XCTAssertEqual(urunKimligi(ad: "Propolis (Damla)", mevcut: []), "propolis_damla")
    }
    func test_urunKimligiCakismadaSonek() {
        XCTAssertEqual(urunKimligi(ad: "Bal Sirkesi", mevcut: ["bal_sirkesi"]), "bal_sirkesi_2")
        XCTAssertEqual(urunKimligi(ad: "Bal Sirkesi", mevcut: ["bal_sirkesi", "bal_sirkesi_2"]), "bal_sirkesi_3")
    }
    func test_urunKimligiBosAd() {
        XCTAssertTrue(urunKimligi(ad: "🍯🍯", mevcut: []).hasPrefix("stock_"))
    }
}
