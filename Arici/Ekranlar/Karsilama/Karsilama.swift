import AVFoundation
import SwiftUI
import UserNotifications

/// Karşılama (Android Karsilama ile aynı): ilk açılışta ve güncelleyen kullanıcılara bir kez, Vızıltı kanat çırparak
/// 6 sayfada uygulamayı anlatır; cümleler ema-lightning ile önceden seslendirildi (Ses/karsilama_N.m4a).
/// Ayarlar › Vızıltı › "Tanıtımı tekrar göster" ile yeniden açılır. Tercihler cihaza özel.
@MainActor @Observable
final class KarsilamaDurumu {
    static let paylasilan = KarsilamaDurumu()
    private let t = UserDefaults.standard

    /// Kök görünüm bunu izler.
    var goster: Bool

    private init() {
        goster = Baslatma.var_("-karsilama") || (!Baslatma.ornekVeri && !UserDefaults.standard.bool(forKey: "bb_karsilamaGoruldu"))
    }

    func bitti() {
        t.set(true, forKey: "bb_karsilamaGoruldu")
        goster = false
    }

    var sesAcik: Bool {
        get { t.object(forKey: "bb_vizilti_ses") as? Bool ?? true }
        set { t.set(newValue, forKey: "bb_vizilti_ses") }
    }
}

private struct KarsilamaSayfasi {
    let baslik: String
    let soz: String
    let ses: String
    let gorseller: [String]
}

private let sayfalar: [KarsilamaSayfasi] = [
    .init(baslik: "Hoş geldin!", soz: "Akıllı arıcılık sistemimize hoş geldin! Ben Vızıltı, sana yol göstereceğim.", ses: "karsilama_1", gorseller: []),
    .init(baslik: "Kovanlar ve arazi", soz: "Kovanlarını kart kart takip et, arazi düzeninde yerlerine diz. Ana arıların takvimini de ben hatırlarım.", ses: "karsilama_2", gorseller: ["SimgeKovan", "SimgeArazi", "SimgeAnaAri"]),
    .init(baslik: "Satış ve stok tek yerde", soz: "Satışların, stoğun, zekat ve hediyelerin, giderlerin hepsi tek yerde. Kimden ne alacağın da hesapta.", ses: "karsilama_3", gorseller: ["SimgeSatis", "SimgeHediye", "SimgeZekat"]),
    .init(baslik: "Hatırlatmalar", soz: "İzin verirsen, Dağıtım ve Çıkım günü sabah seni uyarırım. Günün işlerini de unutturmam.", ses: "karsilama_4", gorseller: ["SimgeSezon"]),
    .init(baslik: "Verilerin güvende", soz: "Giriş yaparsan verilerin bulutta saklanır, telefonların eşitlenir. İstersen girişsiz de kullanabilirsin.", ses: "karsilama_5", gorseller: ["SimgeYedek"]),
    .init(baslik: "Yakında: sesle kayıt", soz: "Eller dolu mu? Yakında bana söyleyeceksin, ben yazacağım. Hadi başlayalım!", ses: "karsilama_6", gorseller: []),
]

struct KarsilamaEkrani: View {
    @Environment(OturumYoneticisi.self) private var oturum
    private var durum: KarsilamaDurumu { .paylasilan }
    @State private var sayfa = 0
    @State private var ses = KarsilamaDurumu.paylasilan.sesAcik
    @State private var calar: AVAudioPlayer?
    @State private var konusuyor = false
    @State private var izin: UNAuthorizationStatus = .notDetermined

    var body: some View {
        ZStack {
            Renk.orman.ignoresSafeArea()
            Image("ArkaManzara").resizable().scaledToFill().ignoresSafeArea()
            LinearGradient(stops: [
                .init(color: .black.opacity(0.15), location: 0), .init(color: .clear, location: 0.3),
                .init(color: Renk.orman.opacity(0.55), location: 0.55), .init(color: Renk.orman.opacity(0.95), location: 1),
            ], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        ses.toggle(); durum.sesAcik = ses
                        if ses { cal() } else { durdur() }
                    } label: {
                        Image(systemName: ses ? "speaker.wave.2.fill" : "speaker.slash.fill").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white).frame(width: 40, height: 40).background(.black.opacity(0.25), in: Circle())
                    }
                    .accessibilityLabel(ses ? "Sesi kapat" : "Sesi aç")
                    Spacer()
                    if sayfa < sayfalar.count - 1 {
                        Button { bitir() } label: {
                            Text("Atla").font(Yazi.govdeOrta).foregroundStyle(.white)
                                .padding(.horizontal, 16).padding(.vertical, 8).background(.black.opacity(0.25), in: Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8)

                TabView(selection: $sayfa) {
                    ForEach(sayfalar.indices, id: \.self) { i in
                        SayfaIcerigi(s: sayfalar[i], i: i, son: i == sayfalar.count - 1, konusuyor: konusuyor && sayfa == i).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                eylem.frame(height: 56).padding(.horizontal, 24)

                HStack {
                    HStack(spacing: 6) {
                        ForEach(sayfalar.indices, id: \.self) { i in
                            Capsule().fill(i == sayfa ? Renk.bal : .white.opacity(0.45)).frame(width: i == sayfa ? 22 : 8, height: 8)
                        }
                    }
                    .animation(.spring(response: 0.3), value: sayfa)
                    Spacer()
                    let son = sayfa == sayfalar.count - 1
                    dugme(son ? "Başla" : "İleri") {
                        if son { bitir() } else { withAnimation { sayfa += 1 } }
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 16)
            }
        }
        .preferredColorScheme(.dark)
        .task { izin = await Hatirlatici.izinDurumu() }
        .onChange(of: sayfa, initial: true) { _, _ in cal() }
        .onDisappear { durdur() }
    }

    @ViewBuilder private var eylem: some View {
        if sayfa == 3 {
            if izin == .authorized { durumSatiri("Bildirimler açık") }
            else if izin == .notDetermined {
                dugme("Bildirimlere izin ver", simge: "bell.badge", ikincil: true) {
                    Task {
                        await Hatirlatici.izinIste()
                        izin = await Hatirlatici.izinDurumu()
                        withAnimation { sayfa = 4 }
                    }
                }
            }
        } else if sayfa == 4 {
            if oturum.durum == .girisli { durumSatiri("Giriş yaptın, verilerin eşitleniyor") }
            else {
                Text("Sonraki ekranda Apple ya da Google ile giriş yapabilir veya girişsiz devam edebilirsin.")
                    .font(Yazi.kucuk).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
            }
        } else { Color.clear }
    }

    private func dugme(_ metin: String, simge: String? = nil, ikincil: Bool = false, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            HStack(spacing: 8) {
                if let simge { Image(systemName: simge).foregroundStyle(Renk.orman) }
                Text(metin).font(Yazi.nunito(16, .heavy)).foregroundStyle(Renk.ormanKoyu)
            }
            .padding(.horizontal, 22).padding(.vertical, 12)
            .background(ikincil ? Color.white : Renk.bal, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func durumSatiri(_ m: String) -> some View {
        Label(m, systemImage: "checkmark.circle").font(Yazi.govdeOrta).foregroundStyle(.white)
    }

    private func cal() {
        durdur()
        guard ses, let url = Bundle.main.url(forResource: sayfalar[sayfa].ses, withExtension: "m4a") else { return }
        let hedef = sayfa
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard hedef == sayfa, ses else { return }
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            calar = try? AVAudioPlayer(contentsOf: url)
            calar?.play()
            konusuyor = calar?.isPlaying ?? false
            // Bitişi izle (temsilci yerine basit yoklama)
            while let c = calar, c.isPlaying, hedef == sayfa { try? await Task.sleep(for: .milliseconds(150)) }
            if hedef == sayfa { konusuyor = false }
        }
    }

    private func durdur() {
        calar?.stop(); calar = nil; konusuyor = false
    }

    private func bitir() {
        durdur()
        durum.bitti()
    }
}

private struct SayfaIcerigi: View {
    let s: KarsilamaSayfasi
    let i: Int
    let son: Bool
    let konusuyor: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let y = sin(t * 2 * .pi / 2.8) * 6
            let x = sin(t * 2 * .pi / 4.6) * 4
            let nabiz = konusuyor ? 1 + 0.02 * (sin(t * 2 * .pi / 0.84) + 1) : 1
            VStack(spacing: 0) {
                gorsel.frame(height: 150)
                Spacer().frame(height: 12)
                Vizilti(konusuyor: konusuyor)
                    .frame(width: 150, height: 225)
                    .scaleEffect(nabiz)
                    .offset(x: x, y: y)
                Spacer().frame(height: 10)
                Text(s.baslik).font(Yazi.nunito(28, .heavy)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.75), radius: 5, y: 2).multilineTextAlignment(.center)
                Spacer().frame(height: 8)
                Text(s.soz).font(Yazi.nunito(17, .semibold)).foregroundStyle(.white.opacity(0.95)).lineSpacing(3)
                    .shadow(color: .black.opacity(0.75), radius: 5, y: 2).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private var gorsel: some View {
        if i == 0 {
            Image("Amblem").resizable().scaledToFit().frame(width: 220)
        } else if son {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "mic.fill").font(.system(size: 50)).foregroundStyle(Renk.ormanKoyu)
                    .frame(width: 110, height: 110)
                    .background(RadialGradient(colors: [Renk.bal, Renk.bal.opacity(0.55)], center: .center, startRadius: 0, endRadius: 60), in: Circle())
                    .overlay(Circle().strokeBorder(Renk.acikBal, lineWidth: 2))
                Text("YAKINDA").font(Yazi.nunito(12, .heavy)).foregroundStyle(Renk.ormanKoyu)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(.white, in: RoundedRectangle(cornerRadius: 10))
                    .offset(x: 18, y: -6)
            }
        } else {
            HStack(spacing: -14) {
                ForEach(Array(s.gorseller.enumerated()), id: \.offset) { j, g in
                    let orta = s.gorseller.count == 1 || j == 1
                    SimgeKutusu(ad: g, boyut: orta ? 116 : 92)
                        .rotationEffect(.degrees(s.gorseller.count == 1 ? 0 : Double(j - 1) * 8))
                        .zIndex(orta ? 1 : 0)
                }
            }
        }
    }
}

/// Vızıltı: gövde + kanat ayrı katman (kanatlar birleşme noktası %33/%48,5 etrafında çırpar);
/// konuşurken ağız yaması (ViziltiAgiz) hece ritminde açılıp kapanır.
struct Vizilti: View {
    var cirpiyor = true
    var konusuyor = false

    /// Android keyframes ile aynı 900 ms ağız deseni.
    private static let agizDeseni: [(Double, Double)] = [(0, 0), (90, 1), (200, 1), (280, 0), (380, 1), (470, 0.6), (560, 0), (650, 1), (760, 1), (840, 0), (900, 0)]

    private static func agiz(_ t: Double) -> Double {
        let ms = (t * 1000).truncatingRemainder(dividingBy: 900)
        for k in 1..<agizDeseni.count where ms <= agizDeseni[k].0 {
            let (t0, v0) = agizDeseni[k - 1], (t1, v1) = agizDeseni[k]
            return v0 + (v1 - v0) * (ms - t0) / max(1, t1 - t0)
        }
        return 0
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !cirpiyor && !konusuyor)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let faz = cirpiyor ? (sin(t * 2 * .pi * 7) + 1) / 2 : 1 // ~7 Hz
            let merkez = UnitPoint(x: 0.33, y: 0.485)
            ZStack {
                Image("ViziltiKanat").resizable().scaledToFit()
                    .scaleEffect(x: 0.55 + 0.45 * faz, y: 1, anchor: merkez)
                    .rotationEffect(.degrees(10 * (1 - faz)), anchor: merkez)
                Image("ViziltiGovde").resizable().scaledToFit()
                if konusuyor {
                    Image("ViziltiAgiz").resizable().scaledToFit().opacity(Self.agiz(t))
                }
            }
        }
        .accessibilityLabel("Vızıltı")
    }
}

/// Ayarlar › Vızıltı: ses ve tanıtımı tekrar göster.
struct ViziltiAyarlariBolumu: View {
    @Environment(\.dismiss) private var kapat
    @State private var ses = KarsilamaDurumu.paylasilan.sesAcik

    var body: some View {
        Section(header: Label("Vızıltı", systemImage: "ladybug")) {
            Toggle(isOn: $ses) {
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Vızıltı sesi").foregroundStyle(Renk.metin)
                        Text(ses ? "Vızıltı konuşur" : "Sessiz").font(Yazi.minik).foregroundStyle(Renk.metin2)
                    }
                } icon: { Image(systemName: "waveform") }
            }
            .tint(Renk.orman2)
            .onChange(of: ses) { _, v in KarsilamaDurumu.paylasilan.sesAcik = v }
            Button {
                kapat()
                KarsilamaDurumu.paylasilan.goster = true
            } label: {
                Label("Tanıtımı tekrar göster", systemImage: "arrow.counterclockwise").foregroundStyle(Renk.metin)
            }
        }
    }
}
