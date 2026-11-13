import Foundation

// Satış (total) ve gider (amount) ödeme hesabı. payment: paid | pending | partial | hediye | zekat.
// Ödeme alanı olmayan eski kayıt ödenmiş sayılır (web v2.2).

private func tutar(_ k: Kayit) -> Double { k["total"]?.sayi ?? k["amount"]?.sayi ?? 0 }
private func odemeTuru(_ k: Kayit) -> String {
    let p = k["payment"]?.metinDegeri ?? ""
    return p.isEmpty ? "paid" : p
}

public func odenen(_ k: Kayit) -> Double {
    switch odemeTuru(k) {
    case "paid": return tutar(k)
    case "partial": return k["paidAmount"]?.sayi ?? 0
    default: return 0
    }
}

public func kalan(_ k: Kayit) -> Double {
    switch odemeTuru(k) {
    case "pending": return tutar(k)
    case "partial": return max(0, tutar(k) - (k["paidAmount"]?.sayi ?? 0))
    default: return 0
    }
}

public func bekleyenToplam(satislar: [Satis]) -> Double {
    satislar.reduce(0) { $0 + kalan($1.ham) }
}
