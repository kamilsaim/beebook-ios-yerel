import Foundation

// Web openStockReportModal / showZekatModal / openSaleReportModal / openExpenseReportModal hesapları.

public struct UrunRaporSatiri: Equatable, Sendable {
    public let urun: String
    public let giris: Double
    public let satisMiktar: Double
    public let satisTutar: Double
    public let hediye: Double
    public let zekat: Double
    public let mevcut: Double
}

/// Yalnız en az bir giriş (in) kaydı olan ürünler. Satış/hediye/zekat `sales`'ten (silinmiş satış kalıntısı yok).
public func stokRaporu(_ v: BBVeri, urunler: [UrunTanimi]) -> [UrunRaporSatiri] {
    let satislar = v.satislar
    return urunler.compactMap { u in
        let girisler = v.stokKayitlari.filter { $0.product == u.v && $0.action == "in" }
        guard !girisler.isEmpty else { return nil }
        let ilgili = satislar.filter { satisStokUrunu($0) == u.v }
        let satilan = ilgili.filter { $0.payment != "hediye" && $0.payment != "zekat" }
        return UrunRaporSatiri(
            urun: u.v,
            giris: girisler.reduce(0) { $0 + ($1.amount ?? 0) },
            satisMiktar: satilan.reduce(0) { $0 + ($1.qty ?? 0) },
            satisTutar: satilan.reduce(0) { $0 + ($1.total ?? 0) },
            hediye: ilgili.filter { $0.payment == "hediye" }.reduce(0) { $0 + ($1.qty ?? 0) },
            zekat: ilgili.filter { $0.payment == "zekat" }.reduce(0) { $0 + ($1.qty ?? 0) },
            mevcut: stokSeviyesi(v, urun: u.v)
        )
    }
}

/// Zekat: mevcut stoğun %10'u.
public func zekatMiktari(_ mevcut: Double) -> Double { mevcut * 0.1 }

public struct SatisRaporGrubu: Equatable, Sendable {
    /// "urun_<stok ürün id>" ya da "tur_<satış türü>"
    public let anahtar: String
    public var unit: String?
    public var satis: Double = 0
    public var satisTl: Double = 0
    public var hediye: Double = 0
    public var zekat: Double = 0
    public var satisAdet: Int = 0
}

public func satisRaporu(_ satislar: [Satis]) -> [SatisRaporGrubu] {
    var sira: [String] = []
    var gruplar: [String: SatisRaporGrubu] = [:]
    for s in satislar {
        let anahtar = satisStokUrunu(s).map { "urun_\($0)" } ?? "tur_\(s.type ?? "other")"
        if gruplar[anahtar] == nil { gruplar[anahtar] = SatisRaporGrubu(anahtar: anahtar); sira.append(anahtar) }
        var g = gruplar[anahtar]!
        g.unit = s.unit
        let q = s.qty ?? 0
        switch s.payment {
        case "hediye": g.hediye += q
        case "zekat": g.zekat += q
        default: g.satis += q; g.satisTl += s.total ?? 0; g.satisAdet += 1
        }
        gruplar[anahtar] = g
    }
    return sira.map { gruplar[$0]! }
}

public struct GiderRaporSatiri: Equatable, Sendable {
    public let tur: String
    public let adet: Int
    public let toplam: Double
}

/// Türler listesindeki sırayla; listede olmayan türler sona, ilk görülme sırasıyla. Kaydı olmayan tür yok.
public func giderRaporu(_ giderler: [Gider], turler: [String]) -> [GiderRaporSatiri] {
    var sira = turler
    for g in giderler { if let t = g.type, !sira.contains(t) { sira.append(t) } }
    return sira.compactMap { t in
        let k = giderler.filter { $0.type == t }
        guard !k.isEmpty else { return nil }
        return GiderRaporSatiri(tur: t, adet: k.count, toplam: k.reduce(0) { $0 + ($1.amount ?? 0) })
    }
}
