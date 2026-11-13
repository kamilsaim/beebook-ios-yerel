import Foundation

/// Uluslararası ana arı renk kodu (web aricilik.html: 1/6 beyaz, 2/7 sarı, 3/8 kırmızı, 4/9 yeşil, 5/0 mavi).
public func anaRengi(yil: Int) -> String {
    switch ((yil % 10) + 10) % 10 {
    case 1, 6: return "white"
    case 2, 7: return "yellow"
    case 3, 8: return "red"
    case 4, 9: return "green"
    default: return "blue"
    }
}

public func anaYasi(yil: Int, buYil: Int) -> Int { buYil - yil }

public struct GelisimAdimi: Equatable, Sendable {
    public let ad: String
    public let gun: Int
    /// YYYY-MM-DD
    public let tarih: String
}

private let adimlar: [(String, Int)] = [("Transfer", 0), ("Kapanma", 4), ("Pupa", 6), ("Dağıtım", 10), ("Çıkım", 12)]

private var utcTakvim: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}

/// "YYYY-MM-DD" + n gün.
public func gunEkle(_ iso: String, _ n: Int) -> String? {
    let p = iso.prefix(10).split(separator: "-").compactMap { Int($0) }
    guard p.count == 3, let d = utcTakvim.date(from: DateComponents(year: p[0], month: p[1], day: p[2])),
          let s = utcTakvim.date(byAdding: .day, value: n, to: d) else { return nil }
    let c = utcTakvim.dateComponents([.year, .month, .day], from: s)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
}

/// Transfer tarihinden (larvanın 4. günü kabulü) gelişim adımları: +0, +4, +6, +10, +12.
public func gelisimTakvimi(transfer: String) -> [GelisimAdimi] {
    adimlar.compactMap { ad, gun in gunEkle(transfer, gun).map { GelisimAdimi(ad: ad, gun: gun, tarih: $0) } }
}

/// Bugün itibarıyla ulaşılmış son adımın indeksi; transferden önceyse -1.
public func aktifAdimIndeksi(transfer: String, bugun: String) -> Int {
    let b = String(bugun.prefix(10))
    return (gelisimTakvimi(transfer: transfer).lastIndex { $0.tarih <= b }) ?? -1
}
