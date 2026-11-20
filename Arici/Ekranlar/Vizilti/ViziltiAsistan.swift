import AriCekirdek
import AVFoundation
import Speech
import SwiftUI

// Vızvız sesli kayıt — Android `ViziltiAsistan.kt` ile aynı akış: kenarda yüzen maskot → dokun → konuş →
// ayrıştırıcı (AriCekirdek/Vizilti.swift) → muayene / bal sağımı formu önceden dolu açılır; kullanıcı kontrol edip kaydeder.

/// Vızvız'ın açacağı form.
enum ViziltiHedef: Identifiable {
    case muayene(kovanId: String, taslak: ViziltiSonuc?)
    case balSagimi(kovanId: String, taslak: ViziltiSonuc?)
    var id: String {
        switch self {
        case let .muayene(k, t): "m-\(k)-\(t?.metin ?? "")"
        case let .balSagimi(k, t): "b-\(k)-\(t?.metin ?? "")"
        }
    }
}

/// Anlamadığı cümle (yalnız bu telefonda, en çok 100).
struct Anlamadigi: Codable, Hashable {
    var zaman: Double   // ms
    var metin: String
    var kalan: String?
}

/// Cihaza özel Vızvız tercihleri ve kabuk ile ekranlar arası istekler.
@MainActor @Observable
final class ViziltiAyari {
    static let paylasilan = ViziltiAyari()
    private let t = UserDefaults.standard

    /// Yüzen balon açık mı (basılı tut → Gizle; ana sayfa simgesinden ya da Ayarlar'dan geri açılır).
    var balonAcik: Bool { didSet { t.set(balonAcik, forKey: "bb_vizilti_balon") } }
    var sagda: Bool { didSet { t.set(sagda, forKey: "bb_vizilti_sag") } }
    var yOran: Double { didSet { t.set(yOran, forKey: "bb_vizilti_y") } }
    /// Bal sağımında çerçeve başı tahmini kg.
    var cerceveBasiKg: Double { didSet { t.set(cerceveBasiKg, forKey: "bb_vizilti_cerceveKg") } }
    private(set) var anlamadiklari: [Anlamadigi]

    /// Balon dışından (ana sayfa simgesi) dinleme panelini açma isteği.
    var panelIstegi = false
    /// Kılavuzdaki "Dene": cümle söylenmiş gibi işlenir.
    var deneme: String?
    /// Açık kovan detayı (numarasız cümle o kovana gider).
    var acikKovanId: String?
    /// Arazi turundaki kovan (numarasız cümle o kovana gider; detaydan önce).
    var turKovanId: String?
    /// Arazi tam ekranı açık: Vızvız formunu kabuk değil arazi açar.
    var araziAcik = false
    /// Kabuğun açacağı form.
    var hedef: ViziltiHedef?

    private init() {
        balonAcik = t.object(forKey: "bb_vizilti_balon") as? Bool ?? true
        sagda = t.object(forKey: "bb_vizilti_sag") as? Bool ?? true
        yOran = t.object(forKey: "bb_vizilti_y") as? Double ?? 0.6
        cerceveBasiKg = t.object(forKey: "bb_vizilti_cerceveKg") as? Double ?? 3
        anlamadiklari = (t.data(forKey: "bb_vizilti_anlamadi")).flatMap { try? JSONDecoder().decode([Anlamadigi].self, from: $0) } ?? []
        // Simülatör/deneme: `-vizilti "3 numaralı kovan ..."` konuşmadan dener
        deneme = Baslatma.deger("-vizilti")
    }

    private func anlamadiklariYaz(_ l: [Anlamadigi]) {
        anlamadiklari = Array(l.suffix(100))
        t.set(try? JSONEncoder().encode(anlamadiklari), forKey: "bb_vizilti_anlamadi")
    }

    func anlamadigiEkle(_ s: ViziltiSonuc) {
        guard s.niyet == .bilinmiyor || s.not != nil else { return }
        if anlamadiklari.last?.metin == s.metin { return }
        anlamadiklariYaz(anlamadiklari + [Anlamadigi(zaman: Date().timeIntervalSince1970 * 1000, metin: s.metin, kalan: s.niyet == .bilinmiyor ? nil : s.not)])
    }
    func anlamadiklariSil() { anlamadiklariYaz([]) }
    func anlamadiklariCikar(_ gonderilen: [Anlamadigi]) {
        let g = Set(gonderilen)
        anlamadiklariYaz(anlamadiklari.filter { !g.contains($0) })
    }
}

/// Önceden seslendirilmiş kısa cevaplar (Ses/vizilti_*.m4a). Vızvız sesi kapalıysa susar.
@MainActor @Observable
final class ViziltiSes {
    static let paylasilan = ViziltiSes()
    var konusuyor = false
    private var calar: AVAudioPlayer?

    func cal(_ ad: String) {
        guard KarsilamaDurumu.paylasilan.sesAcik, let url = Bundle.main.url(forResource: ad, withExtension: "m4a") else { return }
        dur()
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        calar = try? AVAudioPlayer(contentsOf: url)
        calar?.play()
        konusuyor = calar?.isPlaying ?? false
        let c = calar
        Task {
            while let c, c.isPlaying { try? await Task.sleep(for: .milliseconds(150)) }
            if calar === c { konusuyor = false }
        }
    }

    func dur() { calar?.stop(); calar = nil; konusuyor = false }
}

/// iOS konuşma tanıma (tr-TR): SFSpeechRecognizer + AVAudioEngine. Sessizlikte (2,5 sn) kendiliğinden biter.
@MainActor @Observable
final class SesTanima {
    var dinliyor = false
    var kismi = ""
    var seviye: Float = 0

    private let tanici = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR"))
    private let motor = AVAudioEngine()
    private var istek: SFSpeechAudioBufferRecognitionRequest?
    private var gorev: SFSpeechRecognitionTask?
    private var sessizlik: Task<Void, Never>?
    private var musluk = false
    private var bitti = true
    private var sonucF: ((String) -> Void)?
    private var hataF: ((String) -> Void)?

    var kullanilabilir: Bool { tanici?.isAvailable == true }

    /// Konuşma tanıma + mikrofon izni.
    static func izinIste() async -> Bool {
        let d = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard d == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func baslat(sonuc: @escaping (String) -> Void, hata: @escaping (String) -> Void) {
        kapat()
        guard let tanici, tanici.isAvailable else { hata("Konuşma tanıma şu an kullanılamıyor. Yazarak da söyleyebilirsin."); return }
        sonucF = sonuc; hataF = hata; bitti = false; kismi = ""; seviye = 0
        do {
            let oturum = AVAudioSession.sharedInstance()
            try oturum.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try oturum.setActive(true, options: .notifyOthersOnDeactivation)
            let r = SFSpeechAudioBufferRecognitionRequest()
            r.shouldReportPartialResults = true
            r.taskHint = .dictation
            istek = r
            let giris = motor.inputNode
            let bicim = giris.outputFormat(forBus: 0)
            giris.installTap(onBus: 0, bufferSize: 1024, format: bicim, block: SesTanima.musluk(r) { [weak self] s in
                Task { @MainActor in self?.seviye = s }
            })
            musluk = true
            motor.prepare()
            try motor.start()
            dinliyor = true
            gorev = tanici.recognitionTask(with: r, resultHandler: SesTanima.sonucIsleyici { [weak self] metin, son, hataVar in
                Task { @MainActor in self?.geldi(metin, son: son, hataVar: hataVar) }
            })
            sessizlikKur(sure: 8)
        } catch {
            kapat()
            hata("Mikrofon açılamadı. Yazarak da söyleyebilirsin.")
        }
    }

    /// "Bitir": ses kesilir, son sonuç beklenir.
    func bitir() {
        guard !bitti else { return }
        motoruDurdur()
        sessizlik?.cancel()
        sessizlik = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let self else { return }
            self.teslim()
        }
    }

    func kapat() {
        bitti = true
        sessizlik?.cancel(); sessizlik = nil
        gorev?.cancel(); gorev = nil
        motoruDurdur()
        dinliyor = false
    }

    private func geldi(_ metin: String?, son: Bool, hataVar: Bool) {
        guard !bitti else { return }
        if let metin, !metin.isEmpty, metin != kismi {
            kismi = metin
            sessizlikKur(sure: 2.5)
        }
        if son || hataVar { teslim() }
    }

    private func teslim() {
        guard !bitti else { return }
        bitti = true
        sessizlik?.cancel()
        gorev?.cancel(); gorev = nil
        motoruDurdur()
        dinliyor = false
        let m = kismi.trimmingCharacters(in: .whitespacesAndNewlines)
        if m.isEmpty { hataF?("Bir şey duyamadım.") } else { sonucF?(m) }
    }

    private func sessizlikKur(sure: Double) {
        sessizlik?.cancel()
        sessizlik = Task { [weak self] in
            try? await Task.sleep(for: .seconds(sure))
            guard !Task.isCancelled else { return }
            self?.bitir()
        }
    }

    private func motoruDurdur() {
        if motor.isRunning { motor.stop() }
        if musluk { motor.inputNode.removeTap(onBus: 0); musluk = false }
        istek?.endAudio(); istek = nil
        seviye = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // Ses motoru ve tanıyıcı bu blokları arka planda çağırır: ana aktöre bağlı olmasınlar diye burada kurulur.
    nonisolated static func musluk(_ r: SFSpeechAudioBufferRecognitionRequest, _ seviye: @escaping @Sendable (Float) -> Void) -> AVAudioNodeTapBlock {
        { tampon, _ in
            r.append(tampon)
            seviye(seviyeHesapla(tampon))
        }
    }

    nonisolated static func sonucIsleyici(_ f: @escaping @Sendable (String?, Bool, Bool) -> Void) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { sonuc, hata in f(sonuc?.bestTranscription.formattedString, sonuc?.isFinal ?? false, hata != nil) }
    }

    nonisolated static func seviyeHesapla(_ t: AVAudioPCMBuffer) -> Float {
        guard let k = t.floatChannelData?[0], t.frameLength > 0 else { return 0 }
        let n = Int(t.frameLength)
        var top: Float = 0
        for i in 0..<n { top += k[i] * k[i] }
        let rms = sqrt(top / Float(n))
        let db = 20 * log10(max(rms, 0.000_01))
        return max(0, min(1, (db + 50) / 40))
    }
}

// MARK: - Kabuk katmanı

/// Kabuğun en üstüne konur: yüzen balon + dinleme paneli + formu açma.
struct ViziltiKatmani: View {
    @Environment(VeriDeposu.self) private var depo
    /// Yüzen balon gösterilsin mi (arazide yalnız panel).
    var balon = true
    private var ayar: ViziltiAyari { .paylasilan }
    @State private var panel = false

    var body: some View {
        ZStack {
            if balon && ayar.balonAcik && !panel { YuzenBalon { panel = true } }
            if panel {
                DinlemePaneli(kapat: { panel = false; ViziltiSes.paylasilan.dur() }) { s, secilen in
                    if let secilen { panel = false; formuAc(s, secilen); return nil }
                    let k = kovanCoz(s)
                    if s.niyet == .bilinmiyor && k == nil { return .hata }
                    guard let k else { return .kovanSec }
                    panel = false; formuAc(s, k); return nil
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: panel)
        .onChange(of: ayar.panelIstegi) { _, v in if v { panel = true; ayar.panelIstegi = false } }
        .task(id: ayar.deneme) {
            guard let d = ayar.deneme else { return }
            try? await Task.sleep(for: .milliseconds(700))
            let s = viziltiAyristir(d)
            ayar.deneme = nil
            if let k = kovanCoz(s) { formuAc(s, k) } else { panel = true }
        }
    }

    private func kovanCoz(_ s: ViziltiSonuc) -> Kovan? {
        let l = viziltiKovanBul(s.kovanNo, depo.veri.kovanlar)
        if l.count == 1 { return l[0] }
        if s.kovanNo == nil, let id = ayar.turKovanId ?? ayar.acikKovanId { return depo.veri.kovanlar.first { $0.id == id } }
        return nil
    }

    private func formuAc(_ s: ViziltiSonuc, _ k: Kovan) {
        ayar.hedef = s.niyet == .balSagimi ? .balSagimi(kovanId: k.id, taslak: s) : .muayene(kovanId: k.id, taslak: s)
        ViziltiSes.paylasilan.cal("vizilti_doldurdum")
    }
}

/// Hedefe göre formu açar (AnaKabuk `.sheet(item:)`).
struct ViziltiHedefFormu: View {
    let hedef: ViziltiHedef
    var body: some View {
        switch hedef {
        case let .muayene(k, t): MuayeneFormu(kovanId: k, taslak: t)
        case let .balSagimi(k, t): BalSagimiFormu(kovanId: k, taslak: t)
        }
    }
}

// MARK: - Yüzen balon

private struct YuzenBalon: View {
    let ac: () -> Void
    private var ayar: ViziltiAyari { .paylasilan }
    @State private var surukleme: CGPoint?
    @State private var menu = false

    var body: some View {
        GeometryReader { g in
            let gen: CGFloat = 96, yuk: CGFloat = 124
            let ust: CGFloat = 70, alt = max(ust, g.size.height - Olcu.altCubukPayi - yuk / 2 + 20)
            let solX = gen / 2 + 4, sagX = g.size.width - gen / 2 - 4
            let varsayilan = CGPoint(x: ayar.sagda ? sagX : solX, y: min(max(ayar.yOran * g.size.height, ust), alt))
            let yer = surukleme ?? varsayilan
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: surukleme != nil)) { ctx in
                let zipla = surukleme == nil ? (sin(ctx.date.timeIntervalSinceReferenceDate * 2 * .pi / 3.2) + 1) * 2.5 : 0
                balon(suruklenen: surukleme != nil)
                    .frame(width: gen, height: yuk)
                    .contentShape(Rectangle())
                    .position(x: yer.x, y: yer.y + zipla)
            }
            .onTapGesture { ac() }
            .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 10) { menu = true }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { d in
                        surukleme = CGPoint(x: min(max(d.location.x, solX), sagX), y: min(max(d.location.y, ust), alt))
                    }
                    .onEnded { d in
                        let son = CGPoint(x: d.location.x, y: min(max(d.location.y, ust), alt))
                        ayar.sagda = son.x > g.size.width / 2
                        ayar.yOran = son.y / max(1, g.size.height)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { surukleme = nil }
                    }
            )
            .frame(width: g.size.width, height: g.size.height)
        }
        .ignoresSafeArea(.keyboard)
        .confirmationDialog("Vızvız", isPresented: $menu, titleVisibility: .hidden) {
            Button("Vızvız'ı gizle") { ayar.balonAcik = false }
            Button("Vazgeç", role: .cancel) {}
        } message: { Text("Gizlersen ana sayfadaki simgelerin en soluna geçer; oradan basılı tutunca geri gelir.") }
    }

    private func balon(suruklenen: Bool) -> some View {
        ZStack(alignment: .bottom) {
            Circle().fill(RadialGradient(colors: [Renk.bal.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 34))
                .frame(width: 68, height: 68).offset(y: -38)
            Vizilti(cirpiyor: suruklenen).frame(width: 72, height: 100).frame(maxHeight: .infinity, alignment: .top)
            Text("Bana emret").font(Yazi.nunito(11, .bold)).foregroundStyle(Renk.acikBal).lineLimit(1)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(LinearGradient(colors: [Renk.orman2, Renk.ormanKoyu], startPoint: .top, endPoint: .bottom), in: Capsule())
                .overlay(Capsule().strokeBorder(Renk.bal.opacity(0.8)))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vızvız, sesle kayıt")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Dinleme paneli

enum ViziltiAsama { case dinliyor, yaziyla, hata, kovanSec }

/// Alttan açılan panel: maskot + ses dalgası + canlı metin + [İptal] [Yaz] [Bitir].
/// `isle` sonucu yönlendirir; panelde kalınacaksa yeni aşamayı döner.
struct DinlemePaneli: View {
    @Environment(VeriDeposu.self) private var depo
    let kapat: () -> Void
    /// Formdaki "Sesle ekle": örnek cümle buna göre (kovan numarası gerekmez).
    var formaEkle = false
    let isle: (ViziltiSonuc, Kovan?) -> ViziltiAsama?
    @State private var tanima = SesTanima()
    @State private var asama: ViziltiAsama = .dinliyor
    @State private var mesaj = ""
    @State private var yazi = ""
    @State private var sonuc: ViziltiSonuc?
    @State private var kilavuz = false
    @FocusState private var yaziOdak: Bool
    private var ses: ViziltiSes { .paylasilan }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { tanima.kapat(); kapat() }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Vizilti(cirpiyor: tanima.dinliyor || ses.konusuyor, konusuyor: ses.konusuyor).frame(width: 62, height: 88)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vızvız").font(Yazi.nunito(20, .heavy)).foregroundStyle(Renk.acikBal)
                        Text(baslik).font(Yazi.govdeOrta).foregroundStyle(Renk.krem)
                    }
                    Spacer()
                    if asama == .dinliyor { SesDalgasi(seviye: tanima.seviye, aktif: tanima.dinliyor) }
                }
                let gosterilen = asama == .dinliyor ? tanima.kismi : (sonuc?.metin ?? "")
                ScrollView {
                    Group {
                        if !gosterilen.isEmpty { Text("“\(gosterilen)”").font(Yazi.govde).foregroundStyle(.white) }
                        else { Text(formaEkle ? "Forma eklenecek, kovan numarası gerekmez. Örn: \"yavru seyrek, 2 litre şurup verdim.\"" : "Örn: \"3 numaralı kovan, 5 çerçeve, ana görüldü, yumurta var, güçlü.\"").font(Yazi.nunito(14).italic()).foregroundStyle(Renk.krem.opacity(0.6)) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .frame(minHeight: 64, maxHeight: gosterilen.count > 120 ? 160 : 96)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                if !mesaj.isEmpty { Text(mesaj).font(Yazi.kucukOrta).foregroundStyle(Renk.acikBal) }
                if asama != .kovanSec {
                    Button { kilavuz = true } label: { Text("Nasıl konuşmalıyım? ›").font(Yazi.kucukOrta).foregroundStyle(Renk.krem.opacity(0.8)) }
                        .buttonStyle(.plain)
                }
                altKisim
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 12)
            .background(
                LinearGradient(colors: [Renk.orman2, Renk.orman, Renk.ormanKoyu], startPoint: .top, endPoint: .bottom)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
                    .ignoresSafeArea(edges: .bottom)
            )
            .overlay(UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26).strokeBorder(Renk.bal.opacity(0.5)).ignoresSafeArea(edges: .bottom))
        }
        .task { await basla() }
        .onDisappear { tanima.kapat() }
        .sheet(isPresented: $kilavuz) { ViziltiKilavuzu() }
    }

    private var baslik: String {
        switch asama {
        case .dinliyor: tanima.dinliyor ? "Dinliyorum…" : "Hazırlanıyor…"
        case .yaziyla: "Yaz, ben anlayayım"
        case .hata: "Bir daha deneyelim"
        case .kovanSec: "Kovanı seç"
        }
    }

    @ViewBuilder private var altKisim: some View {
        switch asama {
        case .dinliyor:
            HStack(spacing: 10) {
                PanelDugmesi(metin: "İptal", ikincil: true) { tanima.kapat(); kapat() }
                PanelDugmesi(metin: "Yaz", ikincil: true) { tanima.kapat(); yazi = tanima.kismi; asama = .yaziyla; mesaj = ""; yaziOdak = true }
                PanelDugmesi(metin: "Bitir") { tanima.bitir() }.layoutPriority(1)
            }
        case .yaziyla:
            HStack {
                TextField("", text: $yazi, prompt: Text("3 numaralı kovan, ana görüldü…").foregroundStyle(Renk.krem.opacity(0.5)), axis: .vertical)
                    .font(Yazi.govde).foregroundStyle(.white).tint(Renk.bal)
                    .focused($yaziOdak).submitLabel(.send).onSubmit { gonder() }
                Button(action: gonder) { Image(systemName: "paperplane.fill").foregroundStyle(Renk.bal) }
                    .disabled(yazi.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Renk.krem.opacity(0.4)))
            HStack(spacing: 10) {
                PanelDugmesi(metin: "Kapat", ikincil: true) { kapat() }
                PanelDugmesi(metin: "Konuş", simge: "mic.fill") { Task { await basla() } }
            }
        case .hata:
            HStack(spacing: 10) {
                PanelDugmesi(metin: "Kapat", ikincil: true) { kapat() }
                PanelDugmesi(metin: "Yaz", ikincil: true) { yazi = sonuc?.metin ?? ""; asama = .yaziyla; mesaj = ""; yaziOdak = true }
                PanelDugmesi(metin: "Tekrar", simge: "mic.fill") { sonuc = nil; Task { await basla() } }
            }
        case .kovanSec:
            let l = depo.veri.kovanlar.sorted { (Int($0.num) ?? .max, $0.num) < (Int($1.num) ?? .max, $1.num) }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
                    ForEach(l, id: \.id) { k in
                        Button {
                            if let s = sonuc { _ = isle(s, k) }
                        } label: {
                            Text(k.num.isEmpty ? "—" : k.num).font(Yazi.govdeOrta).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(Renk.bal.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Renk.bal.opacity(0.6)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if l.isEmpty { Text("Henüz kovan yok.").font(Yazi.govde).foregroundStyle(Renk.krem) }
            }
            .frame(maxHeight: 220)
            HStack(spacing: 10) {
                PanelDugmesi(metin: "Kapat", ikincil: true) { kapat() }
                PanelDugmesi(metin: "Tekrar", simge: "mic.fill") { sonuc = nil; Task { await basla() } }
            }
        }
    }

    private func gonder() {
        let m = yazi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { return }
        yaziOdak = false
        ayristir(m)
    }

    private func basla() async {
        asama = .dinliyor; mesaj = ""
        guard await SesTanima.izinIste() else {
            asama = .yaziyla; mesaj = "Mikrofon ya da konuşma tanıma izni yok (Ayarlar › BeeBook). Yazarak da söyleyebilirsin."
            return
        }
        tanima.baslat(sonuc: { ayristir($0) }, hata: { h in asama = .hata; mesaj = h })
    }

    private func ayristir(_ metin: String) {
        let s = viziltiAyristir(metin)
        sonuc = s
        ViziltiAyari.paylasilan.anlamadigiEkle(s)
        switch isle(s, nil) {
        case .hata:
            asama = .hata; mesaj = "Anlayamadım. Kovan numarasıyla başla: \"3 numaralı kovan, ana görüldü…\""
            ses.cal("vizilti_anlamadim")
        case .kovanSec:
            asama = .kovanSec
            mesaj = s.kovanNo.map { "\"\($0)\" numaralı kovanı bulamadım. Hangi kovan?" } ?? "Hangi kovan?"
            ses.cal("vizilti_hangi_kovan")
        default: break
        }
    }
}

private struct PanelDugmesi: View {
    let metin: String
    var ikincil = false
    var simge: String? = nil
    let tikla: () -> Void
    var body: some View {
        Button(action: tikla) {
            HStack(spacing: 4) {
                if let simge { Image(systemName: simge).font(.system(size: 15, weight: .semibold)) }
                Text(metin).font(Yazi.govdeOrta)
            }
            .foregroundStyle(ikincil ? Renk.krem : Renk.ormanKoyu)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(ikincil ? AnyShapeStyle(.white.opacity(0.1)) : AnyShapeStyle(Renk.bal), in: Capsule())
            .overlay(Capsule().strokeBorder(ikincil ? Renk.krem.opacity(0.35) : Renk.acikBal))
        }
        .buttonStyle(.plain)
    }
}

/// Ses seviyesine göre kıpırdayan çubuklar.
private struct SesDalgasi: View {
    let seviye: Float
    let aktif: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate * 2 * .pi / 0.9
            let s = aktif ? 0.25 + Double(seviye) * 0.75 : 0.1
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    let h = 40 * (0.15 + 0.85 * s * max(0.1, min(1, 0.55 + 0.45 * sin(t + Double(i) * 0.9))))
                    Capsule().fill(Renk.acikBal).frame(width: 5, height: h)
                }
            }
            .frame(width: 64, height: 40)
            .animation(.easeOut(duration: 0.12), value: seviye)
        }
    }
}

/// Gizlenmiş Vızvız'ın ana sayfa hızlı erişimindeki kutusu (en solda): dokun → dinle, basılı tut → ekrana geri.
struct ViziltiKisayolKutusu: View {
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.1, green: 0.32, blue: 0.22), Renk.ormanKoyu], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).strokeBorder(LinearGradient(colors: [Renk.acikBal, Renk.bal.opacity(0.35)], startPoint: .top, endPoint: .bottom), lineWidth: 1.4))
                    .shadow(color: Renk.bal.opacity(0.4), radius: 8)
                Vizilti(cirpiyor: false).frame(width: 50, height: 70)
            }
            .frame(width: 74, height: 74)
            Text("Vızvız").font(Yazi.etiket).foregroundStyle(Renk.krem).lineLimit(1)
        }
        .frame(width: 78)
        .contentShape(Rectangle())
        .onTapGesture { ViziltiAyari.paylasilan.panelIstegi = true }
        .onLongPressGesture { ViziltiAyari.paylasilan.balonAcik = true }
        .accessibilityLabel("Vızvız, sesle kayıt")
    }
}
