import Foundation

private func kucuk(_ s: String) -> String {
    s.replacingOccurrences(of: "I", with: "ı").replacingOccurrences(of: "İ", with: "i").lowercased()
        .trimmingCharacters(in: .whitespaces)
}

/// Toplu iş ifadesini kovan id'lerine çevirir: "12-18", "1,3,5", "1-3, 7", "Tüm Langstroth", "Tümü".
/// Geçersiz parçalar yok sayılır; sonuç kovan numarasına göre sıralı ve tekil.
public func topluIsKovanlari(_ ifade: String, kovanlar: [Kovan]) -> [String] {
    let numarali = kovanlar.compactMap { k in Int(k.num.trimmingCharacters(in: .whitespaces)).map { (n: $0, k: k) } }
        .sorted { $0.n < $1.n }
    let i = kucuk(ifade)
    guard !i.isEmpty else { return [] }

    if i.hasPrefix("tüm") {
        var tip = i.hasPrefix("tümü") ? String(i.dropFirst(4)) : String(i.dropFirst(3))
        tip = tip.trimmingCharacters(in: .whitespaces)
        let secilen = tip.isEmpty ? numarali : numarali.filter { kucuk($0.k.type ?? "") == tip }
        return secilen.map(\.k.id)
    }

    var araliklar: [ClosedRange<Int>] = []
    for parca in i.split(separator: ",", omittingEmptySubsequences: true) {
        let p = parca.trimmingCharacters(in: .whitespaces)
        if p.contains("-") {
            let uc = p.split(separator: "-", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            guard uc.count == 2, let a = Int(uc[0]), let b = Int(uc[1]) else { continue }
            araliklar.append(min(a, b)...max(a, b))
        } else if let n = Int(p) {
            araliklar.append(n...n)
        }
    }
    guard !araliklar.isEmpty else { return [] }
    return numarali.filter { x in araliklar.contains { $0.contains(x.n) } }.map(\.k.id)
}
