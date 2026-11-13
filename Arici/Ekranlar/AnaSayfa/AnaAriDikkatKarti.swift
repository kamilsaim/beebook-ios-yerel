import AriCekirdek
import SwiftUI

/// Anasız, bakire ve 2+ yaşındaki analar (en çok 3 + Tümü).
struct AnaAriDikkatKarti: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(MenuDurumu.self) private var menu

    var body: some View {
        let dikkat = depo.veri.kovanlar
            .filter { $0.sorunlu || ["bakire", "new"].contains($0.queenStatus ?? "") || $0.yasliAna }
            .sorted { oncelik($0) < oncelik($1) || (oncelik($0) == oncelik($1) && $0.numara < $1.numara) }
        if !dikkat.isEmpty {
            Kart {
                KartBasligi(baslik: "Ana arı dikkat", baglanti: dikkat.count > 3 ? "Tümü (\(dikkat.count))" : "Tümü") { menu.git(.anaAri) }
                ForEach(dikkat.prefix(3), id: \.id) { k in
                    HStack(spacing: 10) {
                        AltigenNumara(numara: k.num, tur: k.sorunlu ? .kotu : k.yasliAna ? .uyari : .bilgi)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(k.yasliAna ? "Ana \(Calendar.current.component(.year, from: Date()) - (k.anaYili ?? 0)) yaşında" : k.anaDurumMetni)
                                .font(Yazi.govdeOrta)
                            Text([k.race, k.type, k.yasliAna ? "değişim önerilir" : nil].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(Yazi.etiket).foregroundStyle(Renk.metin3).lineLimit(1)
                        }
                        Spacer()
                        Rozet(metin: k.sorunlu ? "Anasız" : k.yasliAna ? "Yaşlı" : "Bakire", tur: k.sorunlu ? .kotu : k.yasliAna ? .uyari : .bilgi)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func oncelik(_ k: Kovan) -> Int { k.sorunlu ? 0 : k.yasliAna ? 2 : 1 }
}

struct AltigenNumara: View {
    let numara: String
    var tur: RozetTuru = .uyari
    var body: some View {
        Text(numara).font(Yazi.nunito(14, .bold)).foregroundStyle(Renk.orman)
            .frame(width: 38, height: 42)
            .background(Petek().fill(renk))
    }
    private var renk: Color {
        switch tur {
        case .kotu: return Color(red: 0.96, green: 0.79, blue: 0.76)
        case .bilgi: return Color(red: 0.81, green: 0.88, blue: 0.96)
        default: return Color(red: 1, green: 0.89, blue: 0.63)
        }
    }
}
