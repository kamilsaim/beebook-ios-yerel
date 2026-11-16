import Foundation

// Bal Defterim kuralları (16 Kas 2026). Yalnız hesap; veri biçimi değişmez (web ile uyum korunur).

public struct ZekatDurumu: Equatable, Sendable {
    /// Sezonda girilen hasat/stok (devir ve başlangıç stoğu hariç), ürün biriminde.
    public let hasat: Double
    /// Hasadın %10'u (öşür).
    public let borc: Double
    /// Sezonda "zekat" ödemesiyle verilen miktar.
    public let verilen: Double
    public var kalan: Double { max(0, borc - verilen) }
}

/// Zekat = sezon hasadının %10'u; devreden/başlangıç stoğu zekata dahil edilmez; verilen zekat düşülür.
public func zekatDurumu(_ v: BBVeri, urun: String, urunBirimi: Birim, aralik: SezonAraligi?) -> ZekatDurumu {
    var hasat = 0.0
    for k in v.stokKayitlari where k.product == urun && k.action == "in" && sezonda(k.date, aralik) {
        let not = (k.note ?? "").lowercased(with: Locale(identifier: "tr_TR"))
        if not.contains("devir") || not.contains("başlangıç stoğu") { continue }
        hasat += cevrilmis(k.amount ?? 0, k.unit, urunBirimi)
    }
    var verilen = 0.0
    for s in v.satislar where s.payment == "zekat" && satisStokUrunu(s) == urun && sezonda(s.date, aralik) {
        verilen += cevrilmis(s.qty ?? 0, s.unit, urunBirimi)
    }
    return ZekatDurumu(hasat: hasat, borc: hasat * 0.1, verilen: verilen)
}

/// Teslim edilmemiş ön siparişlerin miktarı (ürün biriminde). Stok düşümü satış girilince yapıldığından
/// "satılabilir" = stokSeviyesi, "depoda" = stokSeviyesi + rezerve.
public func rezerveMiktar(_ v: BBVeri, urun: String, urunBirimi: Birim?) -> Double {
    v.satislar.filter { $0.orderStatus == "preorder" && satisStokUrunu($0) == urun }
        .reduce(0) { $0 + cevrilmis($1.qty ?? 0, $1.unit, urunBirimi) }
}

/// Müşterinin tüm sezonlardaki satışları, yeniden eskiye. Ad büyük/küçük harf ve baş/son boşluk duyarsız.
public func musteriGecmisi(_ satislar: [Satis], musteri: String) -> [Satis] {
    let anahtar = musteriAnahtari(musteri)
    return satislar.filter { musteriAnahtari($0.customer ?? "") == anahtar }
        .sorted { ($0.date ?? "") > ($1.date ?? "") }
}

public func musteriAnahtari(_ ad: String) -> String {
    ad.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Locale(identifier: "tr_TR"))
}

/// Birimi uyumluysa ürün birimine çevirir; uyumsuz/bilinmiyorsa miktarı olduğu gibi alır.
func cevrilmis(_ miktar: Double, _ birim: String?, _ hedef: Birim?) -> Double {
    guard let hedef, let b = birim.flatMap(Birim.init(rawValue:)), let c = Birim.cevir(miktar, b, hedef) else { return miktar }
    return c
}
