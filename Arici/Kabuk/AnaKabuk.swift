import AriCekirdek
import SwiftUI

/// Başlatma argümanları (simülatör ekran görüntüleri): `-sekme <ad>`, `-ornekVeri`, `-ornekKaydir`.
enum Baslatma {
    static var argumanlar: [String] { ProcessInfo.processInfo.arguments }
    static func deger(_ ad: String) -> String? {
        guard let i = argumanlar.firstIndex(of: ad), i + 1 < argumanlar.count else { return nil }
        return argumanlar[i + 1]
    }
    static var ilkSekme: Sekme { deger("-sekme").flatMap(Sekme.init(rawValue:)) ?? .anaSayfa }
    static var ornekVeri: Bool { argumanlar.contains("-ornekVeri") }
    static func var_(_ ad: String) -> Bool { argumanlar.contains(ad) }
}

struct AnaKabuk: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var menu: MenuDurumu = {
        let m = MenuDurumu()
        m.secili = Baslatma.ilkSekme
        return m
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
            Renk.orman.ignoresSafeArea()
            ZStack {
                ForEach(Sekme.allCases) { s in
                    sekmeEkrani(s)
                        .opacity(menu.secili == s ? 1 : 0)
                        .allowsHitTesting(menu.secili == s)
                        .accessibilityHidden(menu.secili != s)
                }
            }
            AltCubuk(durum: menu)
        }
        .environment(menu)
        .preferredColorScheme(.dark)
        .onAppear(perform: rozetleriGuncelle)
        .onChange(of: depo.veri) { _, _ in rozetleriGuncelle() }
    }

    private func rozetleriGuncelle() {
        menu.rozetler[.anaAri] = depo.veri.kovanlar.filter { $0.queenStatus == "no" }.count
        menu.rozetler[.satis] = depo.veri.satislar.filter { ($0.payment == "pending" || $0.payment == "partial") && kalan($0.ham) > 0 }.count
    }

    @ViewBuilder
    private func sekmeEkrani(_ s: Sekme) -> some View {
        switch s {
        case .anaSayfa: AnaSayfaEkrani()
        case .kovanlar: KovanlarEkrani()
        case .anaAri: AnaAriEkrani()
        case .satis: SatisEkrani()
        case .daha: DahaEkrani()
        }
    }
}

/// Geçici ekran (Task 8): ekranlar sonraki görevlerde gelir.
struct YerTutucuEkran: View {
    let baslik: String
    let gorsel: String
    var body: some View {
        SekmeKaydirma {
            ManzaraBasligi(gorsel: gorsel) {
                HStack { Marka(kucuk: true); Spacer(); CamDugme(simge: "bell", nokta: true) {} }
                BuyukBaslik(metin: baslik, alt: "Hazırlanıyor")
            }
            VStack(spacing: 12) {
                ForEach(0..<8, id: \.self) { i in
                    Kart { Text("Kart \(i + 1)").font(Yazi.govdeOrta); Text("Kaydırınca alt menü incelir.").font(Yazi.kucuk).foregroundStyle(Renk.metin3) }
                }
            }
            .padding(.horizontal, Olcu.kenar)
            .padding(.top, 12)
        }
    }
}
