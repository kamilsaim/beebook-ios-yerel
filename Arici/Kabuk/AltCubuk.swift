import SwiftUI
import UIKit

enum Sekme: String, CaseIterable, Identifiable {
    case anaSayfa, kovanlar, anaAri, satis, daha
    var id: String { rawValue }
    var ad: String {
        switch self {
        case .anaSayfa: return "Ana Sayfa"
        case .kovanlar: return "Kovanlar"
        case .anaAri: return "Ana Arı"
        case .satis: return "Satış"
        case .daha: return "Daha"
        }
    }
    var simge: String {
        switch self {
        case .anaSayfa: return "house"
        case .kovanlar: return "archivebox"
        case .anaAri: return "crown"
        case .satis: return "cart"
        case .daha: return "square.grid.2x2"
        }
    }
}

/// Menü durumu: seçili sekme, kaydırınca incelme, rozetler. Ekranlar `inceltmeyiIzle()` ile bildirir.
@Observable @MainActor
final class MenuDurumu {
    var secili: Sekme = .anaSayfa
    var ince = false
    var rozetler: [Sekme: Int] = [:]
    /// Ana sayfadaki "Arazi" kısayolu: Kovanlar sekmesini arazi görünümünde aç.
    var araziIstegi = 0
    /// Ana sayfadaki "Satış" kısayolu: yeni satış formunu aç.
    var yeniSatisIstegi = 0

    func git(_ s: Sekme) {
        ince = false
        secili = s
    }
}

/// Petek (yuvarlatılmış altıgen) — tasarım v6 SVG yolu, 60×68 görünüm kutusu.
struct Petek: Shape {
    func path(in r: CGRect) -> Path {
        let sx = r.width / 60, sy = r.height / 68
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + y * sy) }
        // köşeler: üst, sağ-üst, sağ-alt, alt, sol-alt, sol-üst; köşeler yumuşatılır
        let k = [p(30, 0), p(58, 16), p(58, 52), p(30, 68), p(2, 52), p(2, 16)]
        var path = Path()
        let yuvarlak: CGFloat = 7 * min(sx, sy)
        for i in 0..<6 {
            let onceki = k[(i + 5) % 6], simdi = k[i], sonraki = k[(i + 1) % 6]
            let a = nokta(simdi, onceki, yuvarlak), b = nokta(simdi, sonraki, yuvarlak)
            if i == 0 { path.move(to: a) } else { path.addLine(to: a) }
            path.addQuadCurve(to: b, control: simdi)
        }
        path.closeSubpath()
        return path
    }
    private func nokta(_ k: CGPoint, _ diger: CGPoint, _ d: CGFloat) -> CGPoint {
        let dx = diger.x - k.x, dy = diger.y - k.y, l = max(1, (dx * dx + dy * dy).squareRoot())
        return CGPoint(x: k.x + dx / l * d, y: k.y + dy / l * d)
    }
}

/// Zarif petek: koyu yeşil cam dolgu, ince bal kenar, altta bal ışığı.
struct SeciliPetek: View {
    var body: some View {
        ZStack {
            Petek().fill(LinearGradient(colors: [Color(red: 0.12, green: 0.42, blue: 0.33), Color(red: 0.04, green: 0.2, blue: 0.16)],
                                        startPoint: .top, endPoint: .bottom))
            Petek().fill(RadialGradient(colors: [Renk.bal.opacity(0.42), .clear], center: .bottom, startRadius: 0, endRadius: 46))
            Petek().fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
                .mask(Rectangle().frame(height: 26).frame(maxHeight: .infinity, alignment: .top))
            Petek().stroke(LinearGradient(colors: [Renk.petekKenar, Color(red: 0.9, green: 0.64, blue: 0.23)],
                                          startPoint: .top, endPoint: .bottom), lineWidth: 1.4)
        }
        .shadow(color: Renk.bal.opacity(0.45), radius: 6)
        .shadow(color: .black.opacity(0.35), radius: 8, y: 6)
    }
}

/// Kanadı ayrı katmanda çırpan arı.
struct UcanAriGorseli: View {
    var cirpiyor: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !cirpiyor)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let faz = cirpiyor ? (sin(t * 2 * .pi * 8) + 1) / 2 : 1 // 8 Hz
            ZStack {
                Image("AriKanat").resizable().scaledToFit()
                    .scaleEffect(x: 1, y: 0.35 + 0.65 * faz, anchor: UnitPoint(x: 0.52, y: 0.5))
                    .rotationEffect(.degrees(cirpiyor ? -8 * (1 - faz) : 0), anchor: UnitPoint(x: 0.52, y: 0.5))
                Image("AriGovde").resizable().scaledToFit()
            }
        }
    }
}

struct AltCubuk: View {
    @Bindable var durum: MenuDurumu
    @Environment(\.accessibilityReduceMotion) private var hareketiAzalt

    @State private var ariX: CGFloat = 0
    @State private var ucuyor = false
    @State private var cirpiyor = false
    @State private var solaBakiyor = false
    @State private var konuyor = false
    @State private var iz: (bas: CGFloat, bit: CGFloat)? = nil
    @State private var izOpaklik: Double = 0
    @State private var olcu: CGFloat = 0

    private var ince: Bool { durum.ince }
    private var yukseklik: CGFloat { ince ? 54 : 70 }
    private var petekBoyut: CGSize { ince ? CGSize(width: 48, height: 54) : CGSize(width: 60, height: 68) }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let adim = w / CGFloat(Sekme.allCases.count)
            let merkez = { (s: Sekme) in adim * (CGFloat(Sekme.allCases.firstIndex(of: s)!) + 0.5) }

            ZStack(alignment: .topLeading) {
                // Çubuk
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.086, green: 0.376, blue: 0.33).opacity(0.82),
                                                  Color(red: 0.03, green: 0.18, blue: 0.14).opacity(0.9)],
                                         startPoint: .top, endPoint: .bottom))
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Renk.turkuaz.opacity(0.6), lineWidth: 1.5))
                    .shadow(color: Renk.turkuaz.opacity(0.45), radius: 8)
                    .shadow(color: .black.opacity(0.45), radius: 15, y: 14)
                    .frame(height: yukseklik)

                // Kesikli uçuş izi
                if let iz {
                    let tepe = min(70, 22 + abs(iz.bit - iz.bas) * 0.25)
                    Path { p in
                        p.move(to: CGPoint(x: iz.bas - 12, y: -4))
                        p.addQuadCurve(to: CGPoint(x: iz.bit - 12, y: -8),
                                       control: CGPoint(x: (iz.bas + iz.bit) / 2, y: -4 - tepe))
                    }
                    .stroke(Renk.acikBal, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [5, 7]))
                    .shadow(color: Renk.bal.opacity(0.9), radius: 3)
                    .opacity(izOpaklik)
                    .allowsHitTesting(false)
                }

                // Petek (seçili sekme)
                SeciliPetek()
                    .frame(width: petekBoyut.width, height: petekBoyut.height)
                    .offset(x: merkez(durum.secili) - petekBoyut.width / 2, y: ince ? -9 : -13)
                    .animation(hareketiAzalt ? nil : .spring(response: 0.4, dampingFraction: 0.72), value: durum.secili)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: ince)
                    .allowsHitTesting(false)

                // Sekmeler
                HStack(spacing: 0) {
                    ForEach(Sekme.allCases) { s in
                        sekmeDugmesi(s)
                            .frame(width: adim, height: yukseklik)
                    }
                }

                // Arı
                UcanAriGorseli(cirpiyor: cirpiyor)
                    .frame(width: 50, height: 44)
                    .scaleEffect(x: solaBakiyor ? -1 : 1, y: 1)
                    .rotationEffect(.degrees(ucuyor ? (solaBakiyor ? -8 : 8) : 0))
                    .scaleEffect(ince ? 0.82 : 1)
                    .scaleEffect(x: 1, y: konuyor ? 0.94 : 1, anchor: .bottom)
                    .offset(x: ariX - 22, y: (ince ? -42 : -50) + (ucuyor ? -14 : 0))
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 3)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .onAppear {
                olcu = w
                ariX = merkez(durum.secili)
            }
            .onChange(of: w) { _, yeni in
                olcu = yeni
                ariX = merkez(durum.secili)
            }
            .onChange(of: durum.secili) { eski, yeni in
                uc(from: merkez(eski), to: merkez(yeni), sola: (Sekme.allCases.firstIndex(of: yeni) ?? 0) < (Sekme.allCases.firstIndex(of: eski) ?? 0))
            }
        }
        .frame(height: yukseklik)
        .padding(.horizontal, ince ? 40 : 12)
        .padding(.bottom, 24)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: ince)
    }

    @ViewBuilder
    private func sekmeDugmesi(_ s: Sekme) -> some View {
        let secili = durum.secili == s
        Button {
            if secili { durum.ince = false; return }
            UISelectionFeedbackGenerator().selectionChanged()
            durum.ince = false
            durum.secili = s
        } label: {
            VStack(spacing: ince ? 0 : 3) {
                Image(systemName: secili ? s.simge + ".fill" : s.simge)
                    .font(.system(size: 21, weight: .regular))
                    .symbolEffect(.bounce, value: secili)
                if !ince {
                    Text(s.ad).font(secili ? Yazi.minik : Yazi.nunito(11, .medium)).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(secili ? Renk.seciliMetin : Color(red: 0.93, green: 0.96, blue: 0.95))
            .offset(y: secili ? -6 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                if let n = durum.rozetler[s], n > 0, !secili {
                    Text("\(n)").font(Yazi.nunito(10, .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 5).frame(minWidth: 17, minHeight: 17)
                        .background(s == .anaAri ? Renk.uyari : Renk.kotu, in: Capsule())
                        .overlay(Capsule().strokeBorder(Renk.ormanKoyu, lineWidth: 2))
                        .offset(x: 13, y: ince ? 4 : 8)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(s.ad)
        .accessibilityAddTraits(secili ? .isSelected : [])
    }

    private func uc(from: CGFloat, to: CGFloat, sola: Bool) {
        guard abs(to - from) > 1 else { ariX = to; return }
        if hareketiAzalt {
            ariX = to
            return
        }
        solaBakiyor = sola
        iz = (from, to)
        izOpaklik = 0.95
        withAnimation(.easeOut(duration: 1.0)) { izOpaklik = 0 }
        cirpiyor = true
        withAnimation(.easeOut(duration: 0.2)) { ucuyor = true }
        withAnimation(.timingCurve(0.45, 0.05, 0.3, 1, duration: 0.4)) { ariX = to }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 0.18)) { ucuyor = false }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { konuyor = true }
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { konuyor = false }
            try? await Task.sleep(for: .milliseconds(200)) // inişte birkaç kanat çırpışı daha
            cirpiyor = false
            try? await Task.sleep(for: .milliseconds(700))
            iz = nil
        }
    }
}

// MARK: - Kaydırınca incelme

private struct OfsetAnahtari: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Bir ScrollView'u menünün incelmesine bağlar: aşağı >6 pt ve y>80 → ince; yukarı >6 pt ya da y<40 → normal.
struct InceltmeIzleyici: ViewModifier {
    let durum: MenuDurumu
    @State private var son: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .background(GeometryReader { g in
                Color.clear.preference(key: OfsetAnahtari.self, value: -g.frame(in: .named("kaydirma")).minY)
            })
            .onPreferenceChange(OfsetAnahtari.self) { y in
                MainActor.assumeIsolated {
                    if y > son + 6 && y > 80 { if !durum.ince { durum.ince = true } }
                    else if y < son - 6 || y < 40 { if durum.ince { durum.ince = false } }
                    son = y
                }
            }
    }
}

/// Sekme ekranlarının ortak kaydırma kabı: koordinat alanı + incelme + alt menü payı.
struct SekmeKaydirma<Icerik: View>: View {
    @Environment(MenuDurumu.self) private var menu
    @ViewBuilder var icerik: Icerik
    var body: some View {
        ScrollView {
            VStack(spacing: 0) { icerik }
                .modifier(InceltmeIzleyici(durum: menu))
                .padding(.bottom, Olcu.altCubukPayi)
        }
        .coordinateSpace(name: "kaydirma")
        .scrollIndicators(.hidden)
    }
}
