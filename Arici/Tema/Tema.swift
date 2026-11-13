import SwiftUI

/// Renkler (Assets colorset'leri — araclar/varlik-uret.py üretir). Tasarım v6 paleti.
enum Renk {
    static let orman = Color("Orman")
    static let orman2 = Color("Orman2")
    static let ormanKoyu = Color("OrmanKoyu")
    static let bal = Color("Bal")
    static let acikBal = Color("AcikBal")
    static let krem = Color("Krem")
    static let krem2 = Color("Krem2")
    static let kart = Color("Kart")
    static let metin = Color("Metin")
    static let metin2 = Color("Metin2")
    static let metin3 = Color("Metin3")
    static let iyi = Color("Iyi")
    static let uyari = Color("Uyari")
    static let kotu = Color("Kotu")
    static let bilgi = Color("Bilgi")
    static let mor = Color("Mor")
    static let turkuaz = Color("Turkuaz")
    static let petekKenar = Color("PetekKenar")
    static let seciliMetin = Color("SeciliMetin")

    /// Ana arı renk kodu → görünen renk.
    static func ana(_ kod: String?) -> Color {
        switch kod {
        case "white": return .white
        case "yellow": return Color(red: 1, green: 0.84, blue: 0)
        case "red": return Color(red: 0.91, green: 0.30, blue: 0.24)
        case "green": return Color(red: 0.15, green: 0.68, blue: 0.38)
        case "blue": return Color(red: 0.20, green: 0.60, blue: 0.86)
        default: return .clear
        }
    }
}

/// Nunito (gövde) + Cormorant Garamond (logo). Kalın yazı yok: en fazla Bold (700), çoğunlukla 400–600.
enum Yazi {
    static func nunito(_ boyut: CGFloat, _ agirlik: Font.Weight = .regular) -> Font {
        let ad: String
        switch agirlik {
        case .medium: ad = "Nunito-Medium"
        case .semibold: ad = "Nunito-SemiBold"
        case .bold, .heavy, .black: ad = "Nunito-Bold"
        default: ad = "Nunito-Regular"
        }
        return .custom(ad, size: boyut)
    }
    static func logo(_ boyut: CGFloat) -> Font { .custom("CormorantGaramond-Bold", size: boyut) }

    static let buyukBaslik = nunito(31, .bold)
    static let baslik = nunito(17, .bold)
    static let kartBaslik = nunito(16, .bold)
    static let govde = nunito(15)
    static let govdeOrta = nunito(15, .semibold)
    static let kucuk = nunito(13)
    static let kucukOrta = nunito(13, .semibold)
    static let etiket = nunito(12, .semibold)
    static let minik = nunito(11, .semibold)
    static let buyukSayi = nunito(26, .bold)
}

enum Olcu {
    static let kenar: CGFloat = 14
    static let kartYaricap: CGFloat = 22
    static let altCubukPayi: CGFloat = 118
}
