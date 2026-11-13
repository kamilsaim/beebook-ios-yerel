import XCTest
@testable import AriCekirdek

func ornekVeri(_ ad: String) throws -> Data {
    let url = try XCTUnwrap(Bundle.module.url(forResource: ad, withExtension: "json", subdirectory: "Ornekler"))
    return try Data(contentsOf: url)
}

func cozJSON(_ s: String) throws -> JSONDeger {
    try JSONDecoder().decode(JSONDeger.self, from: Data(s.utf8))
}

final class JSONDegerTests: XCTestCase {
    func test_sayisalMetinSayiOkunur() {
        XCTAssertEqual(JSONDeger.metin("15").sayi, 15)
        XCTAssertEqual(JSONDeger.metin(" 2,5 ").sayi, nil) // web Number("2,5") = NaN
        XCTAssertEqual(JSONDeger.metin("2.5").sayi, 2.5)
        XCTAssertNil(JSONDeger.metin("").sayi)
        XCTAssertNil(JSONDeger.metin("abc").sayi)
        XCTAssertEqual(JSONDeger.tam(5).sayi, 5)
        XCTAssertEqual(JSONDeger.ondalik(0.5).sayi, 0.5)
        XCTAssertNil(JSONDeger.yok.sayi)
    }

    func test_kararliMetinSiraBagimsiz() throws {
        let a = try cozJSON(#"{"b":1,"a":2}"#)
        let b = try cozJSON(#"{"a":2,"b":1}"#)
        XCTAssertEqual(kararliMetin(a), kararliMetin(b))
        XCTAssertEqual(kararliMetin(a), #"{"a":2,"b":1}"#)
        XCTAssertEqual(kararliMetin(.ondalik(0.5)), "0.5")
        XCTAssertEqual(kararliMetin(.ondalik(5.0)), "5")
        XCTAssertEqual(kararliMetin(.metin("ç\"")), #""ç\"""#)
        XCTAssertEqual(kararliMetin(.dizi([.yok, .bool(true)])), "[null,true]")
    }

    func test_tamSayiGidisDonusteKorunur() throws {
        let j = try cozJSON(#"{"qty":15,"price":12.5,"ok":true,"n":null}"#)
        let geri = try JSONDecoder().decode(JSONDeger.self, from: JSONEncoder().encode(j))
        XCTAssertEqual(j, geri)
        XCTAssertEqual(j["qty"], .tam(15))
        XCTAssertEqual(j["price"], .ondalik(12.5))
        XCTAssertEqual(j["ok"], .bool(true))
        XCTAssertEqual(j["n"], .yok)
    }
}

final class VeriTests: XCTestCase {
    func test_bilinmeyenAlanKorunur() throws {
        let girdi = #"{"hives":[{"id":"a","num":"1","gelecekAlan":{"x":[1,2]}}],"yeniKoleksiyon":[1]}"#
        var v = try JSONDecoder().decode(BBVeri.self, from: Data(girdi.utf8))
        var kovanlar = v.kovanlar
        kovanlar[0].num = "2"
        v.kovanlar = kovanlar
        let cikti = try JSONDecoder().decode(JSONDeger.self, from: JSONEncoder().encode(v))
        XCTAssertEqual(cikti["hives"]?.diziDegeri?.first?["gelecekAlan"], try cozJSON(#"{"x":[1,2]}"#))
        XCTAssertEqual(cikti["hives"]?.diziDegeri?.first?["num"], .metin("2"))
        XCTAssertEqual(cikti["yeniKoleksiyon"], .dizi([.tam(1)]))
    }

    func test_webDemoGidisDonus() throws {
        let ham = try cozJSON(String(decoding: try ornekVeri("web-demo"), as: UTF8.self))
        let veriJSON = try XCTUnwrap(ham["data"])
        let v = try JSONDecoder().decode(BBVeri.self, from: JSONEncoder().encode(veriJSON))
        let geri = try JSONDecoder().decode(JSONDeger.self, from: JSONEncoder().encode(v))
        XCTAssertEqual(kararliMetin(veriJSON), kararliMetin(geri))
        XCTAssertEqual(v.kovanlar.count, 6)
        XCTAssertEqual(v.koleksiyon("sales").count, 4)
    }

    func test_tipliGorunumAlanlari() throws {
        let j = #"{"sales":[{"id":"s1","customer":"Ali","qty":"15","total":5250,"payment":"partial","paidAmount":"2000","unit":"kg","honeyType":"suzme_bal","type":"honey","date":"2026-11-11"}]}"#
        let v = try JSONDecoder().decode(BBVeri.self, from: Data(j.utf8))
        let s = try XCTUnwrap(v.satislar.first)
        XCTAssertEqual(s.id, "s1")
        XCTAssertEqual(s.customer, "Ali")
        XCTAssertEqual(s.qty, 15)
        XCTAssertEqual(s.total, 5250)
        XCTAssertEqual(s.paidAmount, 2000)
        XCTAssertEqual(s.payment, "partial")
        XCTAssertNil(s.product)
    }

    func test_bosVeriKoleksiyonlarBos() throws {
        let v = try JSONDecoder().decode(BBVeri.self, from: Data("{}".utf8))
        for c in BBVeri.esitlenenler { XCTAssertEqual(v.koleksiyon(c).count, 0, c) }
        XCTAssertTrue(BBVeri.esitlenenler.contains("inspections"))
    }

    func test_ayarlarTipliVeKorunur() throws {
        let j = #"{"city":"Muğla","stockPrices":{"suzme_bal":350,"ari_sutu":"12"},"stockTypes":[{"v":"suzme_bal","l":"🍯 Süzme Bal","unit":"kg","bilinmeyen":1}],"_up":5,"fazla":"x"}"#
        var a = try JSONDecoder().decode(Ayarlar.self, from: Data(j.utf8))
        XCTAssertEqual(a.city, "Muğla")
        XCTAssertEqual(a.stockPrices["ari_sutu"], 12)
        XCTAssertEqual(a.stockTypes.first?.unit, "kg")
        a.city = "Aydın"
        let geri = try JSONDecoder().decode(JSONDeger.self, from: JSONEncoder().encode(a))
        XCTAssertEqual(geri["fazla"], .metin("x"))
        XCTAssertEqual(geri["stockTypes"]?.diziDegeri?.first?["bilinmeyen"], .tam(1))
        XCTAssertEqual(geri["city"], .metin("Aydın"))
    }
}
