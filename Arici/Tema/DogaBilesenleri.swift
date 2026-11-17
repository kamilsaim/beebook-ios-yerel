import SwiftUI

// Yapraklı doğa zemini ve Daha/Raporlar sayfalarının ortak parçaları (Android DogaZemin/DahaSayfalari ile aynı).

private struct BaslikGirintiAnahtari: EnvironmentKey { static let defaultValue: CGFloat = 0 }

extension EnvironmentValues {
    /// Kart başlığının soldan girintisi: yapraklı kartta başlık yaprakların yanına kayar.
    var baslikGirinti: CGFloat {
        get { self[BaslikGirintiAnahtari.self] }
        set { self[BaslikGirintiAnahtari.self] = newValue }
    }
}

let dogaKrem = Color(red: 0.969, green: 0.933, blue: 0.894)
let dahaAltin = Color(red: 0.72, green: 0.5, blue: 0.05)

extension View {
    /// Doğa zemini: krem, ince altın çerçeve, sol üstte yaprak dalı, altta soluk yeşil dalga.
    func dogaZemini(yaricap: CGFloat = Olcu.kartYaricap, yaprak: CGFloat = 70, golge: CGFloat = 10, dalga: Double = 0.9) -> some View {
        let sekil = RoundedRectangle(cornerRadius: yaricap, style: .continuous)
        return self
            .background {
                ZStack(alignment: .topLeading) {
                    dogaKrem
                    Image("KartDalga").resizable().scaledToFit().opacity(dalga)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    Image("KartYaprak").resizable().scaledToFit().frame(width: yaprak)
                }
            }
            .clipShape(sekil)
            .overlay(sekil.strokeBorder(LinearGradient(colors: [Color(red: 0.89, green: 0.72, blue: 0.35), Color(red: 0.96, green: 0.89, blue: 0.66), Color(red: 0.85, green: 0.66, blue: 0.24)],
                                                      startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.25), radius: golge, y: 6)
            .foregroundStyle(Renk.metin)
    }
}

/// Doğa kartı: Kart gibi dolgulu sütun, yapraklı zemin; başlıklar yaprakların yanına kayar.
struct DogaKart<Icerik: View>: View {
    var dolgu: CGFloat = 14
    @ViewBuilder var icerik: Icerik
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { icerik }
            .padding(dolgu)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.baslikGirinti, 46)
            .dogaZemini()
    }
}

/// Bal dairesi içinde ikon + başlık (yapraklı kartta girintili).
struct BolumBasligi: View {
    @Environment(\.baslikGirinti) private var girinti
    let simge: String
    let baslik: String
    var kucuk = false
    var body: some View {
        HStack(spacing: kucuk ? 6 : 8) {
            Image(systemName: simge).font(.system(size: kucuk ? 12 : 15, weight: .semibold)).foregroundStyle(Renk.orman2)
                .frame(width: kucuk ? 24 : 30, height: kucuk ? 24 : 30)
                .background(Renk.bal.opacity(0.2), in: Circle())
            Text(baslik).font(kucuk ? Yazi.nunito(15, .bold) : Yazi.kartBaslik).lineLimit(1)
        }
        .padding(.leading, girinti)
    }
}

/// Sayfa başı kartı: yapraklı zemin, başlık + açıklama, sağda menü simgesi; altında içerik.
struct SayfaKahramani<Icerik: View>: View {
    let gorsel: String
    let baslik: String
    let alt: String
    @ViewBuilder var icerik: Icerik
    var body: some View {
        DogaKart {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(baslik).font(Yazi.nunito(21, .bold)).foregroundStyle(Renk.orman)
                    Text(alt).font(Yazi.minik).foregroundStyle(Renk.metin2)
                }
                .padding(.leading, 44)
                Spacer(minLength: 0)
                SimgeKutusu(ad: gorsel, boyut: 60)
            }
            icerik
        }
    }
}

extension SayfaKahramani where Icerik == EmptyView {
    init(gorsel: String, baslik: String, alt: String) {
        self.init(gorsel: gorsel, baslik: baslik, alt: alt) { EmptyView() }
    }
}

/// Renkli küçük özet kutucuğu.
struct OzetKutucuk: View {
    let simge: String
    let etiket: String
    let deger: String
    let renk: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: simge).font(.system(size: 11, weight: .semibold)).foregroundStyle(renk)
                    .frame(width: 22, height: 22).background(renk.opacity(0.14), in: Circle())
                Text(etiket).font(Yazi.minik).foregroundStyle(Renk.metin2).lineLimit(1)
            }
            Text(deger).font(Yazi.nunito(17, .bold)).foregroundStyle(Renk.metin).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(renk.opacity(0.28)))
    }
}

/// Simgeli tam genişlik düğme. dolu: yeşil gradyan zemin.
struct EylemDugmesi: View {
    let simge: String
    let metin: String
    var renk: Color = Renk.orman2
    var dolu = false
    let eylem: () -> Void
    var body: some View {
        let sekil = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button(action: eylem) {
            HStack(spacing: 8) {
                Image(systemName: simge).font(.system(size: 17, weight: .semibold)).foregroundStyle(dolu ? Renk.acikBal : renk)
                Text(metin).font(Yazi.govdeOrta).foregroundStyle(dolu ? .white : renk)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                if dolu { sekil.fill(LinearGradient(colors: [Renk.orman2, Renk.orman], startPoint: .leading, endPoint: .trailing)) }
                else { sekil.fill(Renk.kart) }
            }
            .overlay(sekil.strokeBorder(dolu ? Renk.bal.opacity(0.6) : renk.opacity(0.3)))
        }
        .buttonStyle(.borderless)
    }
}

/// Liste satırı: renkli ikon dairesi, başlık + alt yazı, sağda içerik.
struct SimgeliSatir<Sag: View>: View {
    let simge: String
    let renk: Color
    let baslik: String
    var alt: String? = nil
    @ViewBuilder var sag: Sag
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: simge).font(.system(size: 16, weight: .medium)).foregroundStyle(renk)
                .frame(width: 38, height: 38)
                .background(renk.opacity(0.13), in: Circle())
                .overlay(Circle().strokeBorder(renk.opacity(0.25)))
            VStack(alignment: .leading, spacing: 1) {
                Text(baslik).font(Yazi.govdeOrta).foregroundStyle(Renk.metin).lineLimit(1)
                if let alt, !alt.isEmpty { Text(alt).font(Yazi.etiket).foregroundStyle(Renk.metin2).lineLimit(1) }
            }
            Spacer(minLength: 4)
            sag
        }
        .contentShape(Rectangle())
    }
}

extension SimgeliSatir where Sag == EmptyView {
    init(simge: String, renk: Color, baslik: String, alt: String? = nil) {
        self.init(simge: simge, renk: renk, baslik: baslik, alt: alt) { EmptyView() }
    }
}

/// İkon + ad + değer satırı ve altında oran çubuğu.
struct CubukSatiri: View {
    let simge: String
    let ad: String
    var alt: String? = nil
    let deger: String
    let oran: Double
    let renk: Color
    /// SF Symbol yerine renkli nokta.
    var nokta = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Group {
                    if nokta { Circle().fill(renk).frame(width: 11, height: 11) }
                    else { Image(systemName: simge).font(.system(size: 12, weight: .semibold)).foregroundStyle(renk) }
                }
                .frame(width: 24, height: 24).background(renk.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    Text(ad).font(Yazi.govde).lineLimit(1)
                    if let alt { Text(alt).font(Yazi.minik).foregroundStyle(Renk.metin3) }
                }
                Spacer()
                Text(deger).font(Yazi.govdeOrta)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Renk.krem2)
                    Capsule().fill(renk).frame(width: max(0, min(1, oran)) * g.size.width)
                }
            }
            .frame(height: 7)
            .padding(.leading, 31)
        }
        .padding(.vertical, 2)
    }
}

/// Sayfa başlığı kartını List içinde kenarsız göstermek için.
extension View {
    func listeBasligi() -> some View {
        self.listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
            .listRowSeparator(.hidden)
    }
}
