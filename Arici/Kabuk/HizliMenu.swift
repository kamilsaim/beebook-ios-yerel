import SwiftUI
import UIKit

/// Hızlı ekleme (Android `HizliMenu`): alt menüdeki arıya dokununca alt menünün üstünde yay biçiminde açılır.
/// Kovan, satış, stok girişi, gider ve sesle kayıt tek dokunuşta; boşluğa ya da ✕'e dokununca kapanır.
struct HizliMenu: View {
    let menu: MenuDurumu
    @Binding var stokGirisi: Bool
    @Binding var gider: Bool
    @State private var acilma: CGFloat = 0

    private struct Eylem: Identifiable {
        let ad: String
        let simge: String?
        let f: () -> Void
        var id: String { ad }
    }

    var body: some View {
        let eylemler = [
            Eylem(ad: "Kovan ekle", simge: "SimgeKovan") { menu.git(.kovanlar); menu.yeniKovanIstegi += 1 },
            Eylem(ad: "Satış ekle", simge: "SimgeSatis") { menu.git(.satis); menu.yeniSatisIstegi += 1 },
            Eylem(ad: "Stok girişi", simge: "SimgeEnvanter") { stokGirisi = true },
            Eylem(ad: "Gider ekle", simge: "SimgeGider") { gider = true },
            Eylem(ad: "Sesle kaydet", simge: nil) { ViziltiAyari.paylasilan.panelIstegi = true },
        ]
        GeometryReader { g in
            let yaricap: CGFloat = 135
            let mx = g.size.width / 2
            let my = g.size.height - 120
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.62 * acilma).ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { kapat() }
                ForEach(Array(eylemler.enumerated()), id: \.element.id) { i, e in
                    // 185° … 355° (üst yarı), soldan sağa
                    let aci = (185.0 + 170.0 * Double(i) / Double(eylemler.count - 1)) * .pi / 180
                    let r = yaricap * acilma
                    let x = mx + r * CGFloat(cos(aci))
                    let y = my + r * CGFloat(sin(aci))
                    Button { kapat(); e.f() } label: {
                        VStack(spacing: 4) {
                            Group {
                                if let s = e.simge {
                                    SimgeKutusu(ad: s, boyut: 58)
                                } else {
                                    Image(systemName: "mic.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(Renk.ormanKoyu)
                                        .frame(width: 58, height: 58)
                                        .background(Renk.bal, in: Circle())
                                        .overlay(Circle().strokeBorder(Renk.acikBal, lineWidth: 2))
                                        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                                }
                            }
                            .scaleEffect(0.6 + 0.4 * acilma)
                            Text(e.ad).font(Yazi.nunito(12, .bold)).foregroundStyle(.white).lineLimit(1)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Renk.ormanKoyu.opacity(0.85), in: Capsule())
                                .overlay(Capsule().strokeBorder(Renk.bal.opacity(0.6)))
                        }
                        .frame(width: 84)
                    }
                    .buttonStyle(.plain)
                    .position(x: x, y: y + 12)
                    .opacity(Double(acilma))
                }
                Button { kapat() } label: {
                    Image(systemName: "xmark").font(.system(size: 20, weight: .bold)).foregroundStyle(Renk.ormanKoyu)
                        .frame(width: 48, height: 48).background(.white, in: Circle()).shadow(radius: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Kapat")
                .position(x: mx, y: my)
                .opacity(Double(acilma))
            }
        }
        .onAppear {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.68)) { acilma = 1 }
        }
    }

    private func kapat() { menu.hizliMenu = false }
}
