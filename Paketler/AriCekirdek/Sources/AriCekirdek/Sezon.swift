import Foundation

// Web seasonStartOf / getActiveSeasonRange / inSeason / bySeason karşılıkları.

public struct SezonAraligi: Equatable, Sendable {
    public let baslangic: String?
    public let bitis: String?
    public init(baslangic: String?, bitis: String?) { self.baslangic = baslangic; self.bitis = bitis }
}

public func sezonBaslangici(_ s: Sezon) -> String {
    if let st = s.start, !st.isEmpty { return st }
    return "\(s.year ?? 0)-01-01"
}

/// Tek sezon varsa ya da aktif sezon bulunamazsa nil (filtre yok). En eski sezonun başlangıcı yok,
/// en yeni sezonun bitişi yok.
public func aktifSezonAraligi(_ v: BBVeri, aktif: String?) -> SezonAraligi? {
    let sezonlar = v.sezonlar
    guard sezonlar.count >= 2, let act = sezonlar.first(where: { $0.id == aktif }) else { return nil }
    let baslangiclar = sezonlar.map(sezonBaslangici).sorted()
    let benim = sezonBaslangici(act)
    let sonraki = baslangiclar.first { $0 > benim }
    return SezonAraligi(baslangic: benim == baslangiclar.first ? nil : benim, bitis: sonraki)
}

public func sezonda(_ tarih: String?, _ a: SezonAraligi?) -> Bool {
    guard let a else { return true }
    let d = String((tarih ?? "").prefix(10))
    if d.isEmpty { return true }
    if let b = a.baslangic, d < b { return false }
    if let e = a.bitis, d >= e { return false }
    return true
}

public func sezonaGore(_ k: [Kayit], _ a: SezonAraligi?) -> [Kayit] {
    k.filter { sezonda($0["date"]?.metinDegeri, a) }
}
