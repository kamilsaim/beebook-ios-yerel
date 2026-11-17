import Network
import SwiftUI

/// İnternet bağlantısını canlı izler (NWPathMonitor).
@MainActor @Observable
final class BaglantiIzleyici {
    static let paylasilan = BaglantiIzleyici()
    private(set) var internetVar = true
    private let izleyici = NWPathMonitor()

    private init() {
        izleyici.pathUpdateHandler = { yol in
            let var_ = yol.status == .satisfied
            Task { @MainActor in BaglantiIzleyici.paylasilan.internetVar = var_ }
        }
        izleyici.start(queue: DispatchQueue(label: "beebook.baglanti"))
    }
}

/// Ana sayfada sezon seçicinin karşısında: oturum açan kullanıcının baş harfi + adı ve durum ışığı.
/// Yeşil: çevrimiçi ve eşitlendi · bal (yanıp söner): eşitleniyor · kırmızı: eşitleme hatası · gri: internet yok / hesapsız.
/// Dokununca Ayarlar açılır.
struct KullaniciRozeti: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(OturumYoneticisi.self) private var oturum
    @Environment(MenuDurumu.self) private var menu
    @State private var nabiz = false
    private var baglanti: BaglantiIzleyici { .paylasilan }

    var body: some View {
        let hesapsiz = oturum.durum == .hesapsiz
        let internet = baglanti.internetVar
        let ad = hesapsiz ? "Hesapsız" : (oturum.adSoyad.split(separator: " ").map(String.init).first { !$0.isEmpty && $0 != "—" } ?? "Hesap")
        let bas = hesapsiz ? "?" : String(ad.prefix(1)).uppercased(with: Locale(identifier: "tr"))
        let gri = Color(white: 0.62)
        let (isik, durum): (Color, String) = hesapsiz ? (gri, "Yalnız bu telefonda")
            : !internet ? (gri, "Çevrimdışı")
            : depo.esitleniyor ? (Renk.bal, "Eşitleniyor")
            : depo.sonHata != nil ? (Color(red: 0.95, green: 0.3, blue: 0.25), "Eşitlenemedi")
            : (Color(red: 0.3, green: 0.85, blue: 0.4), "Çevrimiçi")
        let yanipSon = depo.esitleniyor && internet && !hesapsiz

        Button {
            menu.dahaIstegi = .ayarlar
            menu.git(.daha)
        } label: {
            HStack(spacing: 8) {
                Text(bas).font(Yazi.nunito(14, .bold)).foregroundStyle(Renk.acikBal)
                    .frame(width: 30, height: 30)
                    .background(LinearGradient(colors: [Renk.orman2, Renk.orman], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    .overlay(Circle().strokeBorder(Renk.bal, lineWidth: 1.5))
                    .overlay(alignment: .bottomTrailing) {
                        Circle().fill(isik)
                            .frame(width: 8, height: 8)
                            .padding(1.5)
                            .background(Renk.ormanKoyu, in: Circle())
                            .shadow(color: isik, radius: 4)
                            .opacity(yanipSon && nabiz ? 0.35 : 1)
                            .offset(x: 2, y: 2)
                    }
                VStack(alignment: .leading, spacing: 0) {
                    Text(ad).font(Yazi.kucukOrta).foregroundStyle(.white).lineLimit(1)
                    Text(durum).font(Yazi.nunito(10)).foregroundStyle(isik).lineLimit(1)
                }
                .frame(maxWidth: 110, alignment: .leading)
            }
            .padding(.leading, 4).padding(.trailing, 12).padding(.vertical, 4)
            .background(Renk.ormanKoyu.opacity(0.6), in: Capsule())
            .overlay(Capsule().strokeBorder(Renk.bal.opacity(0.6)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ad), \(durum)")
        .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { nabiz = true } }
    }
}
