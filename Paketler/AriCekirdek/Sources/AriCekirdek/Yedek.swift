import Foundation

public enum YedekHatasi: Error, Equatable {
    case veriYok
    case listeDegil(String)
}

/// Web `normalizeBackup` birebir: veri nesnesi şart; eksik koleksiyonlar tamamlanır, id'siz/nesne olmayan
/// kayıtlar atılır, sezon yoksa "YYYY Sezonu" oluşturulur, bozuk `deleted` kaldırılır. Mevcut veriye dokunmaz.
public func yedegiNormallestir(_ j: JSONDeger, buYil: Int) throws -> (BBVeri, Ayarlar?) {
    guard case .nesne(var d)? = j["data"] else { throw YedekHatasi.veriYok }
    for c in BBVeri.esitlenenler {
        let deger = d[c] ?? .yok
        if deger == .yok { d[c] = .dizi([]); continue }
        guard case .dizi(let a) = deger else { throw YedekHatasi.listeDegil(c) }
        d[c] = .dizi(a.filter { x in
            guard case .nesne(let o) = x, let id = o["id"], id != .yok else { return false }
            return true
        })
    }
    if d["seasons"]?.diziDegeri?.isEmpty ?? true {
        d["seasons"] = .dizi([.nesne(["id": .metin("s\(buYil)"), "year": .tam(Int64(buYil)),
                                      "name": .metin("\(buYil) Sezonu"), "active": .bool(true)])])
    }
    if let del = d["deleted"], del.diziDegeri == nil { d.removeValue(forKey: "deleted") }
    let ayar = j["settings"]?.nesneDegeri.map { Ayarlar(ham: $0) }
    return (BBVeri(ham: d), ayar)
}
