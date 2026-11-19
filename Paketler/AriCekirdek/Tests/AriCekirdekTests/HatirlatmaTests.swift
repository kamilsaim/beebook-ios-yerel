import XCTest
@testable import AriCekirdek

private func seri(_ id: String, _ ad: String, _ transfer: String, durum: String? = "active") -> JSONDeger {
    var k: Kayit = ["id": .metin(id), "name": .metin(ad), "transfer": .metin(transfer)]
    if let durum { k["status"] = .metin(durum) }
    return .nesne(k)
}
private func isK(_ id: String, _ metin: String, _ tarih: String?, bitti: Bool = false) -> JSONDeger {
    var k: Kayit = ["id": .metin(id), "text": .metin(metin), "done": .bool(bitti)]
    if let tarih { k["dueDate"] = .metin(tarih) }
    return .nesne(k)
}
private func satis(_ musteri: String, _ toplam: Double, _ odeme: String, siparis: String? = nil) -> JSONDeger {
    var k: Kayit = ["id": .metin(yeniKimlik()), "customer": .metin(musteri), "total": .ondalik(toplam), "payment": .metin(odeme)]
    if let siparis { k["orderStatus"] = .metin(siparis) }
    return .nesne(k)
}

/// Android HatirlatmaTests ile aynı durumlar.
final class HatirlatmaTests: XCTestCase {
    let hepsi = HatirlatmaTurleri()

    func test_anaAriAdimGunundeHatirlatir() {
        let v = BBVeri(ham: ["queens": .dizi([seri("s1", "A-26", "2026-11-09"), seri("s2", "Eski", "2026-11-09", durum: "completed")])])
        let l = gunlukHatirlatmalar(v, bugun: "2026-11-19", pazartesi: false, turler: hepsi)
        XCTAssertEqual(l.count, 1)
        XCTAssertEqual(l[0].id, "ana-s1-Dağıtım")
        XCTAssertEqual(l[0].hedef, .anaAri)
        XCTAssertTrue(l[0].baslik.contains("Dağıtım") && l[0].baslik.contains("A-26"))
        XCTAssertEqual(gunlukHatirlatmalar(v, bugun: "2026-11-10", pazartesi: false, turler: hepsi).count, 0)
        XCTAssertEqual(gunlukHatirlatmalar(v, bugun: "2026-11-21", pazartesi: false, turler: hepsi).count, 1)
    }
    func test_durumuOlmayanSeriAktifSayilir() {
        let v = BBVeri(ham: ["queens": .dizi([seri("s1", "B", "2026-11-15", durum: nil)])])
        XCTAssertEqual(gunlukHatirlatmalar(v, bugun: "2026-11-19", pazartesi: false, turler: hepsi).count, 1)
    }
    func test_bugunkuVeGecikenIsler() {
        let v = BBVeri(ham: ["tasks": .dizi([
            isK("1", "Şurup ver", "2026-11-19"), isK("2", "Kat ekle", "2026-11-19"),
            isK("3", "Eski iş", "2026-11-10"), isK("4", "Bitti", "2026-11-19", bitti: true), isK("5", "Tarihsiz", nil),
        ])])
        let l = gunlukHatirlatmalar(v, bugun: "2026-11-19", pazartesi: false, turler: hepsi)
        XCTAssertEqual(l.count, 1)
        XCTAssertEqual(l[0].baslik, "Bugün 2 iş var")
        XCTAssertTrue(l[0].metin.contains("Şurup ver") && l[0].metin.contains("1 iş gecikti"))
    }
    func test_yalnizGecikenIs() {
        let v = BBVeri(ham: ["tasks": .dizi([isK("3", "Eski iş", "2026-11-10")])])
        XCTAssertEqual(gunlukHatirlatmalar(v, bugun: "2026-11-19", pazartesi: false, turler: hepsi).first?.baslik, "1 iş gecikti")
    }
    func test_odemeOzetiYalnizPazartesiVeOnSiparisHaric() {
        let v = BBVeri(ham: ["sales": .dizi([
            satis("Ali", 1000, "pending"), satis("Veli", 500, "pending"), satis("Ali", 200, "pending"),
            satis("Can", 900, "pending", siparis: "preorder"), satis("Deniz", 300, "paid"),
        ])])
        XCTAssertEqual(gunlukHatirlatmalar(v, bugun: "2026-11-18", pazartesi: false, turler: hepsi).count, 0)
        let l = gunlukHatirlatmalar(v, bugun: "2026-11-16", pazartesi: true, turler: hepsi)
        XCTAssertEqual(l.map(\.id), ["odeme"])
        XCTAssertEqual(l.first?.metin, "2 müşteri")
    }
    func test_kapaliTurlerAtlanir() {
        let v = BBVeri(ham: ["queens": .dizi([seri("s1", "A", "2026-11-09")]), "tasks": .dizi([isK("1", "İş", "2026-11-19")])])
        XCTAssertEqual(gunlukHatirlatmalar(v, bugun: "2026-11-19", pazartesi: false, turler: HatirlatmaTurleri(anaAri: false, isler: false, odeme: true)).count, 0)
    }
}
