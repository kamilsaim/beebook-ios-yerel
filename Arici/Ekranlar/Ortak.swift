import AriCekirdek
import SwiftUI

// Ekranlar arası ortak görünüm yardımcıları.

extension Kovan {
    /// Web queenStatus etiketleri (eski veride `new` = bakire).
    var anaDurumMetni: String {
        switch queenStatus {
        case "yes": return "Ana var"
        case "no": return "Ana yok"
        case "bakire", "new": return "Bakire ana"
        case "meme": return "Meme var"
        case "empty": return "Arısız"
        default: return "Bilinmiyor"
        }
    }
    var anaRozetTuru: RozetTuru {
        switch queenStatus {
        case "yes": return .iyi
        case "no": return .kotu
        case "bakire", "new": return .bilgi
        case "meme": return .mor
        default: return .notr
        }
    }
    /// Renk noktası yalnız ana olan/olacak kovanlarda (web showQDot).
    var anaNoktasiGoster: Bool { ["yes", "bakire", "new", "meme"].contains(queenStatus ?? "") }
    var sorunlu: Bool { queenStatus == "no" }
    var numara: Int { Int(num.trimmingCharacters(in: .whitespaces)) ?? Int.max }
    var katSayisi: Int { max(1, min(4, Int(floors ?? 1))) }

    /// Web güç 1–5 → metin.
    var gucMetni: String? {
        guard let g = strength.flatMap({ Int($0) }) else { return nil }
        return g >= 4 ? "Güçlü" : g == 3 ? "Orta" : "Zayıf"
    }
    var anaYili: Int? { year.flatMap { Int($0) } }
    var yasliAna: Bool {
        guard queenStatus == "yes", let y = anaYili else { return false }
        return Calendar.current.component(.year, from: Date()) - y >= 2
    }
    var gorselAdi: String { kovanGorselAdi(tip: type ?? "", kat: katSayisi) }
}

/// Kovan tipi + kat → görsel. Langstroth/Dadant kat sayısına göre, Yerli → karakovan.
func kovanGorselAdi(tip: String, kat: Int) -> String {
    let t = tip.lowercased()
    if t.contains("dadant") { return kat >= 3 ? "Kovan4Kat" : "Kovan\(kat)Kat" }
    if t.contains("yerli") || t.contains("karakovan") { return "Karakovan" }
    if t.contains("ana arı") || t.contains("ana ari") { return "AnaAriKutusu" }
    if t.contains("nükleus") || t.contains("ruşet") || t.contains("ruset") || t.contains("nuc") { return "Ruset" }
    if t.contains("çerçeveli") { return "Kovan\(min(kat, 3))Kat" }
    return "Langstroth\(kat)"
}

extension Satis {
    /// "3 lt Bal Sirkesi" gibi okunur etiket.
    func etiket(urunler: [UrunTanimi]) -> String {
        let ad = urunAdi(urunler: urunler)
        return miktar(qty ?? 0, unit ?? "") + " " + ad
    }
    func urunAdi(urunler: [UrunTanimi]) -> String {
        if let p = satisStokUrunu(self), let u = urunler.first(where: { $0.v == p }) { return u.temizAd }
        switch type {
        case "queen": return "Ana Arı"
        case "bee": return "Arı Satışı"
        case "milk": return "Arı Sütü"
        default: return "Ürün"
        }
    }
}

extension UrunTanimi {
    /// Baştaki emojiyi atar ("🍯 Süzme Bal" → "Süzme Bal").
    var temizAd: String {
        let a = String(l.drop { !$0.isLetter && !$0.isNumber }).trimmingCharacters(in: .whitespaces)
        return a.isEmpty ? l : a
    }
}

/// Ürünlerin varsayılan listesi (web DEFAULT_STOCK_TYPES) — ayarlarda tanımlı değilse.
func urunListesi(_ a: Ayarlar) -> [UrunTanimi] {
    if a.stockTypesTanimli { return a.stockTypes }
    return [
        UrunTanimi(["v": .metin("suzme_bal"), "l": .metin("🍯 Süzme Bal"), "unit": .metin("kg")]),
        UrunTanimi(["v": .metin("petek_bal"), "l": .metin("🍯 Petek Bal"), "unit": .metin("kg")]),
        UrunTanimi(["v": .metin("ari_sutu"), "l": .metin("🥛 Arı Sütü"), "unit": .metin("gr")]),
        UrunTanimi(["v": .metin("karakovan_bal"), "l": .metin("🫙 Karakovan Bal"), "unit": .metin("kg")]),
    ]
}

/// Bugün (yerel) YYYY-MM-DD.
func bugunISO(_ d: Date = Date()) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
}

func isoTarih(_ s: String?) -> Date? {
    guard let s else { return nil }
    let p = s.prefix(10).split(separator: "-").compactMap { Int($0) }
    guard p.count == 3 else { return nil }
    return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
}

extension VeriDeposu {
    var aktifAralik: SezonAraligi? { aktifSezonAraligi(veri, aktif: ayarlar.activeSeason) }
    var urunler: [UrunTanimi] { urunListesi(ayarlar) }
    func sezonda<T: HamKayitli>(_ k: [T]) -> [T] {
        let a = aktifAralik
        return k.filter { AriCekirdek.sezonda($0.ham["date"]?.metinDegeri, a) }
    }
}
