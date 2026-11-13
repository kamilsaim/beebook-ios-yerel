import Foundation

// tr_TR biçimleri — yerel ayar verisinden bağımsız (Linux'ta da aynı sonuç).

private func binlik(_ n: Int64) -> String {
    let s = String(n)
    var o = ""
    for (i, ch) in s.reversed().enumerated() {
        if i > 0 && i % 3 == 0 { o.append(".") }
        o.append(ch)
    }
    return String(o.reversed())
}

/// "₺86.450", kuruş varsa "₺1.234.567,50".
public func tl(_ x: Double) -> String {
    let isaret = x < 0 ? "-" : ""
    let kurus = Int64((abs(x) * 100).rounded())
    let tam = kurus / 100, ond = kurus % 100
    return isaret + "₺" + binlik(tam) + (ond == 0 ? "" : "," + String(format: "%02d", ond))
}

/// "1,5 lt", "1.200 gr" — en çok 2 ondalık, sondaki sıfırlar atılır.
public func miktar(_ x: Double, _ birim: String) -> String {
    let isaret = x < 0 ? "-" : ""
    let yuzde = Int64((abs(x) * 100).rounded())
    let tam = yuzde / 100, ond = yuzde % 100
    var o = isaret + binlik(tam)
    if ond != 0 {
        var d = String(format: "%02d", ond)
        while d.hasSuffix("0") { d.removeLast() }
        o += "," + d
    }
    return birim.isEmpty ? o : o + " " + birim
}

private let aylar = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]

/// "2026-11-13" → "13 Kas"; çözülemezse olduğu gibi.
public func kisaTarih(_ iso: String) -> String {
    let p = iso.prefix(10).split(separator: "-").compactMap { Int($0) }
    guard p.count == 3, (1...12).contains(p[1]), (1...31).contains(p[2]) else { return iso }
    return "\(p[2]) \(aylar[p[1] - 1])"
}
