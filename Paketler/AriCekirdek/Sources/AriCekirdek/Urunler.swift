import Foundation

/// Özel ürün sınırı (Kamil kararı, 2026-11-13): hazır 4 ürün dışında en fazla 20.
public let ozelUrunSiniri = 20

/// Web `DEFAULT_STOCK_TYPES`.
public let hazirUrunler: [UrunTanimi] = [
    UrunTanimi(["v": .metin("suzme_bal"), "l": .metin("🍯 Süzme Bal"), "unit": .metin("kg")]),
    UrunTanimi(["v": .metin("petek_bal"), "l": .metin("🍯 Petek Bal"), "unit": .metin("kg")]),
    UrunTanimi(["v": .metin("ari_sutu"), "l": .metin("🥛 Arı Sütü"), "unit": .metin("gr")]),
    UrunTanimi(["v": .metin("karakovan_bal"), "l": .metin("🫙 Karakovan Bal"), "unit": .metin("kg")]),
]

private let hazirIdler = Set(hazirUrunler.map(\.v))

public func ozelUrunSayisi(_ a: Ayarlar) -> Int {
    a.stockTypes.filter { !hazirIdler.contains($0.v) }.count
}

public func urunEklenebilir(_ a: Ayarlar) -> Bool { ozelUrunSayisi(a) < ozelUrunSiniri }

/// Web addStockTypeItem slug kuralı (küçük harf, boşluk → _, [^a-z0-9çğışöü_] atılır);
/// çakışmada `_2`, `_3`… (web'de çakışma koruması yok).
public func urunKimligi(ad: String, mevcut: [String], simdi: Date = Date()) -> String {
    let izinli = Set("abcdefghijklmnopqrstuvwxyz0123456789çğışöü_")
    var v = ad.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    v = v.replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
    v = String(v.filter { izinli.contains($0) })
    if v.isEmpty { v = "stock_\(Int64(simdi.timeIntervalSince1970 * 1000))" }
    let m = Set(mevcut)
    guard m.contains(v) else { return v }
    var n = 2
    while m.contains("\(v)_\(n)") { n += 1 }
    return "\(v)_\(n)"
}
