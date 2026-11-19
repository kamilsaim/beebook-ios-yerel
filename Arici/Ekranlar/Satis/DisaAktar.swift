import AriCekirdek
import SwiftUI

/// Bal Defterim'deki Excel raporu ve paylaşılabilir rapor metni.
/// Excel: 4 CSV dosyası (Stok, Satışlar, Hasat, Zekat) — `;` ayraç, virgüllü ondalık, UTF-8 BOM
/// (Türkçe Excel doğrudan açar).
@MainActor
enum DisaAktar {
    static func excelDosyalari(_ depo: VeriDeposu) -> [URL] {
        let klasor = FileManager.default.temporaryDirectory.appendingPathComponent("BeeBook-Rapor", isDirectory: true)
        try? FileManager.default.removeItem(at: klasor)
        try? FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
        let v = depo.veri
        let urunler = depo.urunler
        let ad: (String?) -> String = { p in urunler.first { $0.v == p }?.temizAd ?? (p ?? "") }
        let aralik = depo.aktifAralik

        var stok = [["Ürün", "Birim", "Toplam giriş", "Satış", "Satış tutarı (₺)", "Hediye", "Zekat", "Satılabilir", "Rezerve (ön sipariş)", "Birim fiyat (₺)", "Stok değeri (₺)"]]
        for r in stokRaporu(v, urunler: urunler) {
            let u = urunler.first { $0.v == r.urun }
            let birim = Birim(rawValue: u?.unit ?? "")
            let fiyat = depo.ayarlar.stockPrices[r.urun] ?? 0
            stok.append([ad(r.urun), u?.unit ?? "", sayi(r.giris), sayi(r.satisMiktar), sayi(r.satisTutar), sayi(r.hediye), sayi(r.zekat),
                         sayi(r.mevcut), sayi(rezerveMiktar(v, urun: r.urun, urunBirimi: birim)), sayi(fiyat), sayi(max(0, r.mevcut) * fiyat)])
        }

        var satis = [["Tarih", "Müşteri", "Telefon", "Ürün", "Miktar", "Birim", "Tutar (₺)", "Ödeme", "Kalan (₺)", "Durum", "Not"]]
        for s in depo.sezonda(v.satislar).sorted(by: { ($0.date ?? "") > ($1.date ?? "") }) {
            satis.append([s.date ?? "", s.customer ?? "", s.phone ?? "", s.urunAdi(urunler: urunler), sayi(s.qty ?? 0), s.unit ?? "",
                          sayi(s.total ?? 0), odemeAdi(s.payment), sayi(kalan(s.ham)), s.orderStatus == "preorder" ? "Ön sipariş" : "Teslim edildi", s.note ?? ""])
        }

        var hasat = [["Tarih", "Ürün", "Miktar", "Birim", "Not"]]
        for k in v.stokKayitlari.filter({ $0.action == "in" && sezonda($0.date, aralik) }).sorted(by: { ($0.date ?? "") > ($1.date ?? "") }) {
            hasat.append([k.date ?? "", ad(k.product), sayi(k.amount ?? 0), k.unit ?? "", k.note ?? ""])
        }

        var zekat = [["Ürün", "Birim", "Sezon hasadı", "Zekat (%10)", "Verilen", "Kalan"]]
        for u in urunler where u.zakat != false {
            guard let b = Birim(rawValue: u.unit) else { continue }
            let z = zekatDurumu(v, urun: u.v, urunBirimi: b, aralik: aralik)
            if z.hasat == 0 && z.verilen == 0 { continue }
            zekat.append([u.temizAd, u.unit, sayi(z.hasat), sayi(z.borc), sayi(z.verilen), sayi(z.kalan)])
        }

        return [("Stok", stok), ("Satislar", satis), ("Hasat", hasat), ("Zekat", zekat)].compactMap { ad, satirlar in
            let url = klasor.appendingPathComponent("BeeBook-\(ad).csv")
            let metin = "\u{FEFF}" + satirlar.map { $0.map(hucre).joined(separator: ";") }.joined(separator: "\r\n")
            return (try? metin.write(to: url, atomically: true, encoding: .utf8)) != nil ? url : nil
        }
    }

    /// Sezon satış raporu, mesajla paylaşılacak düz metin.
    static func raporMetni(_ depo: VeriDeposu) -> String {
        let satislar = depo.sezonda(depo.veri.satislar)
        let ucretli = satislar.filter { !["hediye", "zekat"].contains($0.payment ?? "") }
        let toplam = ucretli.reduce(0) { $0 + ($1.total ?? 0) }
        let bekleyen = bekleyenToplam(satislar: satislar)
        let sezon = depo.veri.sezonlar.first { $0.id == depo.ayarlar.activeSeason }?.name ?? "Sezon"
        var l = ["🐝 BeeBook — \(sezon) satış raporu", "",
                 "Satış: \(tl(toplam))", "Tahsil edilen: \(tl(ucretli.reduce(0) { $0 + odenen($1.ham) }))", "Alacak: \(tl(bekleyen))", ""]
        for g in satisRaporu(satislar) {
            let ad = g.anahtar.hasPrefix("urun_") ? (depo.urunler.first { $0.v == String(g.anahtar.dropFirst(5)) }?.temizAd ?? String(g.anahtar.dropFirst(5)))
                : ["tur_queen": "Ana Arı", "tur_bee": "Arı Satışı", "tur_milk": "Arı Sütü"][g.anahtar] ?? "Diğer"
            var s = "• \(ad): \(miktar(g.satis, g.unit ?? "")) · \(tl(g.satisTl))"
            if g.hediye > 0 { s += " · hediye \(miktar(g.hediye, g.unit ?? ""))" }
            if g.zekat > 0 { s += " · zekat \(miktar(g.zekat, g.unit ?? ""))" }
            l.append(s)
        }
        return l.joined(separator: "\n")
    }

    private static func sayi(_ x: Double) -> String {
        let r = (x * 100).rounded() / 100
        return r == r.rounded() ? String(Int(r)) : String(format: "%.2f", r).replacingOccurrences(of: ".", with: ",")
    }

    private static func hucre(_ s: String) -> String {
        s.contains(";") || s.contains("\"") || s.contains("\n") ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
    }

    private static func odemeAdi(_ p: String?) -> String {
        ["paid": "Ödendi", "pending": "Bekliyor", "partial": "Kısmi", "hediye": "Hediye", "zekat": "Zekat"][p ?? "paid"] ?? (p ?? "")
    }
}

/// Rapor sayfalarının araç çubuğuna: metin paylaş + Excel (CSV) dışa aktar.
struct RaporPaylasDugmesi: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var dosyalar: [URL] = []
    var body: some View {
        Menu {
            ShareLink(item: DisaAktar.raporMetni(depo)) { Label("Raporu metin olarak paylaş", systemImage: "text.bubble") }
            if !dosyalar.isEmpty {
                ShareLink(items: dosyalar) { Label("Excel'e aktar (4 dosya)", systemImage: "tablecells") }
            }
        } label: { Image(systemName: "square.and.arrow.up") }
        .accessibilityLabel("Paylaş ve dışa aktar")
        .task { dosyalar = DisaAktar.excelDosyalari(depo) }
    }
}
