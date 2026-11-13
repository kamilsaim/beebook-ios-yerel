import SwiftUI

/// Krem kart (tasarım v6).
struct Kart<Icerik: View>: View {
    var dolgu: CGFloat = 14
    @ViewBuilder var icerik: Icerik
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { icerik }
            .padding(dolgu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Renk.krem, in: RoundedRectangle(cornerRadius: Olcu.kartYaricap, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
            .foregroundStyle(Renk.metin)
    }
}

/// Koyu cam kart (hava durumu, özet şerit).
struct CamKart<Icerik: View>: View {
    @ViewBuilder var icerik: Icerik
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { icerik }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(Renk.ormanKoyu.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.18)))
            .foregroundStyle(Renk.krem)
    }
}

struct KartBasligi: View {
    let baslik: String
    var baglanti: String? = nil
    var eylem: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(baslik).font(Yazi.kartBaslik)
            Spacer()
            if let baglanti {
                Button(baglanti) { eylem?() }.font(Yazi.kucukOrta).foregroundStyle(Renk.orman2)
            }
        }
    }
}

enum RozetTuru { case iyi, uyari, kotu, bilgi, mor, notr }

struct Rozet: View {
    let metin: String
    var tur: RozetTuru = .notr
    var body: some View {
        Text(metin)
            .font(Yazi.minik)
            .lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(on)
            .background(arka, in: Capsule())
    }
    private var arka: Color {
        switch tur {
        case .iyi: return Color(red: 0.86, green: 0.94, blue: 0.85)
        case .uyari: return Color(red: 1, green: 0.92, blue: 0.75)
        case .kotu: return Color(red: 0.98, green: 0.87, blue: 0.84)
        case .bilgi: return Color(red: 0.87, green: 0.91, blue: 0.97)
        case .mor: return Color(red: 0.93, green: 0.89, blue: 0.97)
        case .notr: return Renk.krem2
        }
    }
    private var on: Color {
        switch tur {
        case .iyi: return Color(red: 0.12, green: 0.42, blue: 0.17)
        case .uyari: return Color(red: 0.54, green: 0.33, blue: 0)
        case .kotu: return Color(red: 0.65, green: 0.18, blue: 0.13)
        case .bilgi: return Color(red: 0.14, green: 0.35, blue: 0.6)
        case .mor: return Color(red: 0.36, green: 0.21, blue: 0.57)
        case .notr: return Renk.metin2
        }
    }
}

/// Yuvarlak cam düğme (başlıktaki zil, + vb.).
struct CamDugme: View {
    let simge: String
    var nokta = false
    let eylem: () -> Void
    var body: some View {
        Button(action: eylem) {
            Image(systemName: simge)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.25)))
                .overlay(alignment: .topTrailing) {
                    if nokta { Circle().fill(Renk.bal).frame(width: 8, height: 8).offset(x: -8, y: 8) }
                }
        }
        .buttonStyle(.plain)
    }
}

/// Logo (amblem + "BeeBook").
struct Marka: View {
    var kucuk = false
    var body: some View {
        HStack(spacing: 6) {
            Image("Amblem").resizable().scaledToFit().frame(width: kucuk ? 30 : 36)
                .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
            (Text("Bee").foregroundStyle(Renk.krem) + Text("Book").foregroundStyle(Renk.bal))
                .font(Yazi.logo(kucuk ? 22 : 27))
                .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BeeBook")
    }
}

/// Görsel arka planlı başlık (manzara/bokeh) + alttan yeşile kararan degrade.
struct ManzaraBasligi<Icerik: View>: View {
    let gorsel: String
    @ViewBuilder var icerik: Icerik
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { icerik }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    Image(gorsel).resizable().scaledToFill()
                    LinearGradient(stops: [
                        .init(color: Renk.ormanKoyu.opacity(0.55), location: 0),
                        .init(color: Renk.ormanKoyu.opacity(0.1), location: 0.4),
                        .init(color: Renk.orman.opacity(0.95), location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                }
                .ignoresSafeArea(edges: .top)
            }
            .clipped()
            .foregroundStyle(.white)
    }
}

struct BuyukBaslik: View {
    let metin: String
    var alt: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(metin).font(Yazi.buyukBaslik).foregroundStyle(Renk.krem)
            if let alt { Text(alt).font(Yazi.kucuk).foregroundStyle(Color(white: 0.85)) }
        }
        .padding(.top, 12)
    }
}

/// Ana arı renk noktası.
struct AnaNoktasi: View {
    let renk: String?
    var boyut: CGFloat = 12
    var body: some View {
        Circle().fill(Renk.ana(renk)).frame(width: boyut, height: boyut)
            .overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 1.5))
    }
}

/// iOS segment (Liste | Arazi, Satışlar | Stok).
struct Segment<Deger: Hashable>: View {
    let secenekler: [(Deger, String)]
    @Binding var secili: Deger
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 0) {
            ForEach(secenekler, id: \.0) { d, ad in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { secili = d }
                } label: {
                    Text(ad).font(Yazi.kucukOrta)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .foregroundStyle(secili == d ? Renk.orman : Color(white: 0.9))
                        .background {
                            if secili == d {
                                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Renk.krem)
                                    .matchedGeometryEffect(id: "secim", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.14)))
    }
}

/// Boş durum.
struct BosDurum: View {
    let simge: String
    let baslik: String
    var alt: String? = nil
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: simge).font(.system(size: 30)).foregroundStyle(Renk.bal)
            Text(baslik).font(Yazi.govdeOrta).foregroundStyle(Renk.krem)
            if let alt { Text(alt).font(Yazi.kucuk).foregroundStyle(Color(white: 0.75)).multilineTextAlignment(.center) }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}
