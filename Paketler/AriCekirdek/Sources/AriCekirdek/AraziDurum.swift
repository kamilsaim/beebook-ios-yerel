import Foundation

/// Arazi haritasında kovanın üstündeki işaretler (durum katmanı) — Android `AraziDurum.kt` ile aynı.
public enum AraziIsaret: Int, CaseIterable, Sendable, Comparable {
    /// Ana yok
    case anasiz
    /// Bugün ya da gecikmiş, bu kovana bağlı açık iş
    case is_
    /// Son muayenesi `araziGecikmeGun` günden eski
    case gecikmis
    /// Varroa şeridi takılı (son şerit işlemi "takildi")
    case serit
    /// Koloni zayıf (güç ≤ 2)
    case zayif

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// Bu kadar gündür bakılmayan kovan "gecikmiş" sayılır.
public let araziGecikmeGun = 14

/// "Bugün bakılacak" sayılan işaretler (şerit tek başına bugün iş gerektirmez).
public let bugunIsaretleri: Set<AraziIsaret> = [.anasiz, .is_, .gecikmis, .zayif]

private func gunOncesi(_ iso: String, _ gun: Int) -> String? {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd"
    guard let d = f.date(from: iso), let o = Calendar(identifier: .gregorian).date(byAdding: .day, value: -gun, to: d) else { return nil }
    return f.string(from: o)
}

/// Her kovanın işaretleri. Arısız kovanlar hiç işaret almaz.
/// Gecikme yalnız en az bir muayenesi olan kovanda sayılır.
public func araziDurumlari(_ veri: BBVeri, bugun: String, gecikmeGun: Int = araziGecikmeGun) -> [String: Set<AraziIsaret>] {
    let sinir = gunOncesi(bugun, gecikmeGun)
    var muayeneler: [String: [Muayene]] = [:]
    for m in veri.muayeneler { if let h = m.hiveId { muayeneler[h, default: []].append(m) } }
    let isler = veri.isler.filter { !$0.done && !($0.dueDate ?? "").isEmpty && ($0.dueDate ?? "") <= bugun }
    var sonuc: [String: Set<AraziIsaret>] = [:]
    for k in veri.kovanlar where k.queenStatus != "empty" {
        var s = Set<AraziIsaret>()
        if k.queenStatus == "no" { s.insert(.anasiz) }
        if isler.contains(where: { ($0.hiveIds ?? []).contains(k.id) }) { s.insert(.is_) }
        let m = (muayeneler[k.id] ?? []).sorted { ($0.date ?? "") < ($1.date ?? "") }
        if let son = m.last?.date, let sinir, son < sinir { s.insert(.gecikmis) }
        if m.last(where: { $0.varroaAction == "takildi" || $0.varroaAction == "cikarildi" })?.varroaAction == "takildi" { s.insert(.serit) }
        if let g = Int((m.last?.strength ?? k.strength ?? "").trimmingCharacters(in: .whitespaces)), g <= 2 { s.insert(.zayif) }
        if !s.isEmpty { sonuc[k.id] = s }
    }
    return sonuc
}

/// Arazide yürüyüş sırası: dikey konuma göre sıralar ([sirAraligi] birimden yakınlar aynı sıra),
/// yukarıdan aşağı, her sıra yılan gibi bir soldan sağa bir sağdan sola.
public func araziTurSirasi(_ konumlar: [String: (x: Double, y: Double)], sirAraligi: Double = 60) -> [String] {
    let l = konumlar.sorted { ($0.value.y, $0.value.x) < ($1.value.y, $1.value.x) }
    var siralar: [[(String, Double)]] = []
    var bas = -Double.infinity
    for e in l {
        if siralar.isEmpty || e.value.y - bas > sirAraligi { siralar.append([]); bas = e.value.y }
        siralar[siralar.count - 1].append((e.key, e.value.x))
    }
    return siralar.enumerated().flatMap { i, s -> [String] in
        let x = s.sorted { $0.1 < $1.1 }.map(\.0)
        return i % 2 == 0 ? x : x.reversed()
    }
}
