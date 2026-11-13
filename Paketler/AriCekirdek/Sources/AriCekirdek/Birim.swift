import Foundation

/// Ürün birimleri. Dönüşüm yalnız kg↔gr ve lt↔ml (1000); stok her zaman ürünün kendi biriminde tutulur.
public enum Birim: String, CaseIterable, Sendable {
    case kg, gr, lt, ml, adet

    public static func uyumlular(_ urunBirimi: Birim) -> [Birim] {
        switch urunBirimi {
        case .kg: return [.kg, .gr]
        case .gr: return [.gr, .kg]
        case .lt: return [.lt, .ml]
        case .ml: return [.ml, .lt]
        case .adet: return [.adet]
        }
    }

    /// Uyumsuz birimler arasında nil.
    public static func cevir(_ miktar: Double, _ kaynak: Birim, _ hedef: Birim) -> Double? {
        if kaynak == hedef { return miktar }
        switch (kaynak, hedef) {
        case (.gr, .kg), (.ml, .lt): return miktar / 1000
        case (.kg, .gr), (.lt, .ml): return miktar * 1000
        default: return nil
        }
    }
}
