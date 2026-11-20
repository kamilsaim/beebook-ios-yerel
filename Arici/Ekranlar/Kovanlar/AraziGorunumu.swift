import AriCekirdek
import SwiftUI

/// Arazi düzeni, tam ekran: `araziLayout.positions` (web ile aynı koordinatlar). İki parmakla ya da +/− ile
/// yakınlaş/uzaklaş; kovana dokun → ayrıntı; uzun basıp sürükle → yerini değiştir. Kapat → Kovanlar listesi.
struct AraziTamEkran: View {
    @Environment(\.dismiss) private var kapat
    @State private var yol = NavigationPath()
    var body: some View {
        let _ = ViziltiAyari.paylasilan.hedef?.id
        NavigationStack(path: $yol) {
            AraziGorunumu(kapat: { kapat() }) { yol.append($0) }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: String.self) { id in KovanDetayi(kovanId: id) }
        }
        .overlay { ViziltiKatmani(balon: false) }
        .sheet(item: Binding(get: { ViziltiAyari.paylasilan.hedef }, set: { ViziltiAyari.paylasilan.hedef = $0 })) { ViziltiHedefFormu(hedef: $0) }
        .onAppear { ViziltiAyari.paylasilan.araziAcik = true }
        .onDisappear { ViziltiAyari.paylasilan.araziAcik = false; ViziltiAyari.paylasilan.turKovanId = nil }
    }
}

struct AraziGorunumu: View {
    @Environment(VeriDeposu.self) private var depo
    var kapat: () -> Void = {}
    let ac: (String) -> Void
    @State private var surukle: (id: String, fark: CGSize)?
    @State private var olcek: CGFloat = 1
    @State private var bazOlcek: CGFloat = 1
    @State private var rakim: Int?
    /// Toplu taşıma: seçili kovanlar birlikte sürüklenir.
    @State private var secimModu = false
    @State private var secili: Set<String> = []
    // Durum katmanı + tur
    @State private var vurgu = false
    @State private var tur: [String]?
    @State private var turSira = 0
    @State private var bakilan = 0
    @State private var bilinen: Set<String> = []
    @State private var elleForm: String?
    @State private var aciklama = false

    private let hucre: CGFloat = 72
    private var turKovani: String? { tur.flatMap { turSira < $0.count ? $0[turSira] : nil } }

    var body: some View {
        let kovanlar = depo.veri.kovanlar
        let konumlar = konumlariOku()
        let yerlesmemis = kovanlar.filter { konumlar[$0.id] == nil }
        let ekran = UIScreen.main.bounds.size
        // Üst çubuğun altında kalmasın diye ekranda sabit ~130 pt boşluk (yakınlaştırmadan bağımsız).
        let ust = 130 / olcek
        let genislik = max(ekran.width / olcek, (konumlar.values.map(\.x).max() ?? 0) + hucre + 60)
        let yukseklik = max(ekran.height / olcek, (konumlar.values.map(\.y).max() ?? 0) + ust + hucre + 220)
        let durumlar = araziDurumlari(depo.veri, bugun: bugunISO())
        let bugunkuler = Set(durumlar.filter { !$0.value.isDisjoint(with: bugunIsaretleri) }.keys)

        ZStack(alignment: .top) {
            ScrollViewReader { kaydir in
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Zemin kaydırılmaz: sabit arka planda (aşağıda) durur, yalnız kovanlar kayar → kenarda ek yeri/kayma görünmez.
                    Color.clear.frame(width: genislik, height: yukseklik)
                    ForEach(araLar(), id: \.id) { a in
                        RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.55, green: 0.42, blue: 0.25).opacity(0.75))
                            .frame(width: a.w, height: a.h).offset(x: a.x, y: a.y + ust)
                    }
                    ForEach(kovanlar.filter { konumlar[$0.id] != nil }, id: \.id) { k in
                        let p = konumlar[k.id]!
                        let grupta = secimModu && secili.contains(k.id)
                        let f = surukle.map { $0.id == k.id || (grupta && secili.contains($0.id)) ? $0.fark : .zero } ?? .zero
                        AraziKovani(kovan: k, genislik: hucre, isaretler: durumlar[k.id] ?? [], turda: k.id == turKovani)
                            .opacity((vurgu && !bugunkuler.contains(k.id)) || (tur.map { !$0.contains(k.id) } ?? false) ? 0.35 : 1)
                            .id(k.id)
                            .overlay {
                                if grupta {
                                    RoundedRectangle(cornerRadius: 12).strokeBorder(Renk.bal, lineWidth: 3)
                                        .shadow(color: Renk.bal, radius: 6).padding(-4)
                                }
                            }
                            .offset(x: p.x + f.width, y: p.y + f.height + ust)
                            .zIndex(f != .zero ? 1 : 0)
                            .onTapGesture {
                                if secimModu {
                                    if secili.contains(k.id) { secili.remove(k.id) } else { secili.insert(k.id) }
                                } else if var t = tur {
                                    // Turda dokunulan kovan sıradaki olur
                                    if let i = t.firstIndex(of: k.id) { turSira = i } else { t.insert(k.id, at: min(turSira, t.count)); tur = t }
                                } else { ac(k.id) }
                            }
                            .gesture(
                                LongPressGesture(minimumDuration: 0.3)
                                    .sequenced(before: DragGesture())
                                    .onChanged { d in
                                        if case .second(true, let drag?) = d { surukle = (k.id, drag.translation) }
                                    }
                                    .onEnded { d in
                                        if case .second(true, let drag?) = d {
                                            if grupta { grupTasi(konumlar, drag.translation) } else { tasi(k.id, p, drag.translation) }
                                        }
                                        surukle = nil
                                    }
                            )
                    }
                }
                .frame(width: genislik, height: yukseklik, alignment: .topLeading)
                .clipped()
                .scaleEffect(olcek, anchor: .topLeading)
                .frame(width: genislik * olcek, height: yukseklik * olcek, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
            .background(Image("AraziZemin").resizable().scaledToFill().ignoresSafeArea())
            .ignoresSafeArea()
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in olcek = min(3, max(0.4, bazOlcek * v.magnification)) }
                    .onEnded { _ in bazOlcek = olcek }
            )
            // Turdaki kovanı ekrana getir
            .onChange(of: turKovani) { _, id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.45)) { kaydir.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.35)) }
            }
            }

            VStack(spacing: 8) {
                ustCubuk
                if tur == nil && !bugunkuler.isEmpty { bugunCipi(bugunkuler.count) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let t = tur { turPaneli(t, durumlar) } else { altPanel(yerlesmemis, konumlar, bugunkuler) }
        }
        .onAppear { bilinen = Set(depo.veri.muayeneler.map(\.id)) }
        // Turdaki kovana muayene kaydedilince sıradakine geç
        .onChange(of: depo.veri.muayeneler.count) { _, _ in
            let yeni = depo.veri.muayeneler.filter { !bilinen.contains($0.id) }
            bilinen = Set(depo.veri.muayeneler.map(\.id))
            if let t = tur, let k = turKovani, yeni.contains(where: { $0.hiveId == k }) {
                bakilan += 1
                withAnimation(.snappy) { turSira = min(turSira + 1, t.count) }
            }
        }
        .onChange(of: turKovani, initial: true) { _, id in ViziltiAyari.paylasilan.turKovanId = id }
        .sheet(item: Binding(get: { elleForm.map(ElleHedef.init) }, set: { elleForm = $0?.id })) { MuayeneFormu(kovanId: $0.id) }
        .task {
            let sehir = (depo.ayarlar.city?.isEmpty == false ? depo.ayarlar.city : nil) ?? "Muğla"
            rakim = try? await HavaServisi.paylasilan.getir(sehir: sehir).rakim
        }
        .background(Renk.ormanKoyu)
    }

    private var ustCubuk: some View {
        HStack(spacing: 10) {
            Button(action: kapat) {
                Label("Liste", systemImage: "chevron.left").font(Yazi.govdeOrta)
                    .padding(.horizontal, 14).frame(height: 42)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .accessibilityLabel("Kovan listesine dön")
            Spacer()
            VStack(spacing: 0) {
                Text("Arazi").font(Yazi.logo(24))
                if let rakim { Text("Rakım \(rakim) m").font(Yazi.etiket) }
            }
            .shadow(color: .black.opacity(0.6), radius: 4)
            Spacer()
            Button {
                withAnimation(.snappy) { secimModu.toggle() }
                if !secimModu { secili = [] }
            } label: {
                Image(systemName: secimModu ? "checkmark.circle.fill" : "checkmark.circle").frame(width: 42, height: 42)
                    .background(secimModu ? AnyShapeStyle(Renk.bal.opacity(0.85)) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
            }
            .accessibilityLabel(secimModu ? "Seçimi bitir" : "Kovan seç, birlikte taşı")
            HStack(spacing: 0) {
                Button { yakinlas(1 / 1.3) } label: { Image(systemName: "minus").frame(width: 42, height: 42) }
                    .accessibilityLabel("Uzaklaş")
                Divider().frame(height: 22)
                Button { yakinlas(1.3) } label: { Image(systemName: "plus").frame(width: 42, height: 42) }
                    .accessibilityLabel("Yakınlaş")
            }
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.horizontal, Olcu.kenar)
        .padding(.top, 4)
    }

    private func bugunCipi(_ n: Int) -> some View {
        Button { withAnimation(.snappy) { vurgu.toggle() } } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.exclamationmark").foregroundStyle(vurgu ? Renk.ormanKoyu : Renk.acikBal)
                Text("Bugün \(n) kovan").font(Yazi.govdeOrta).foregroundStyle(vurgu ? Renk.ormanKoyu : .white)
                if vurgu { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Renk.ormanKoyu) }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(vurgu ? AnyShapeStyle(Renk.bal) : AnyShapeStyle(Renk.ormanKoyu.opacity(0.88)), in: Capsule())
            .overlay(Capsule().strokeBorder(Renk.bal))
            .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Bugün bakılacak kovanları öne çıkarır")
    }

    private func turBaslat(_ konumlar: [String: CGPoint], _ bugunkuler: Set<String>) {
        let sira = araziTurSirasi(konumlar.mapValues { (x: Double($0.x), y: Double($0.y)) })
            .filter { id in (depo.veri.kovanlar.first(where: { $0.id == id }).map { !$0.arisiz } ?? false) && (!vurgu || bugunkuler.contains(id)) }
        guard !sira.isEmpty else { return }
        withAnimation(.snappy) { tur = sira; turSira = 0; bakilan = 0; secimModu = false; secili = [] }
    }

    /// Tur paneli: sıradaki kovan, durumu, büyük "Sesle kaydet".
    private func turPaneli(_ t: [String], _ durumlar: [String: Set<AraziIsaret>]) -> some View {
        let k: Kovan? = turSira < t.count ? depo.veri.kovanlar.first(where: { $0.id == t[turSira] }) : nil
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(k != nil ? "Tur · \(turSira + 1)/\(t.count)" : "Tur bitti").font(Yazi.kucukOrta).foregroundStyle(Renk.acikBal)
                Spacer()
                Text("\(bakilan) kovana bakıldı").font(Yazi.etiket).foregroundStyle(Color(white: 0.85))
            }
            if let k {
                HStack(spacing: 10) {
                    Image(k.gorselAdi).resizable().scaledToFit().frame(width: 52, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kovan \(k.num)").font(Yazi.nunito(22, .heavy)).foregroundStyle(.white)
                        let d = (durumlar[k.id] ?? []).filter { $0 != .anasiz }.sorted()
                        Text(([k.anaDurumMetni] + d.map(araziIsaretAdi)).joined(separator: " · ")).font(Yazi.kucuk)
                            .foregroundStyle(d.isEmpty ? Color(white: 0.85) : Renk.acikBal).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                Button {
                    ViziltiAyari.paylasilan.turKovanId = k.id
                    ViziltiAyari.paylasilan.panelIstegi = true
                } label: {
                    Label("Sesle kaydet", systemImage: "mic.fill").font(Yazi.nunito(19, .heavy)).foregroundStyle(Renk.ormanKoyu)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(LinearGradient(colors: [Renk.bal, Color(red: 0.86, green: 0.6, blue: 0.1)], startPoint: .top, endPoint: .bottom), in: Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                HStack(spacing: 8) {
                    turDugmesi("‹") { withAnimation(.snappy) { turSira = max(0, turSira - 1) } }.frame(maxWidth: 56)
                    turDugmesi("Elle yaz") { elleForm = k.id }
                    turDugmesi("Atla ›") { withAnimation(.snappy) { turSira = min(turSira + 1, t.count) } }
                    turDugmesi("Bitir") { turBitir() }
                }
            } else {
                Text("Hepsi tamam! Ellerine sağlık").font(Yazi.nunito(18, .heavy)).foregroundStyle(.white)
                Button { turBitir() } label: {
                    Text("Turu bitir").font(Yazi.nunito(17, .heavy)).foregroundStyle(Renk.ormanKoyu).frame(maxWidth: .infinity, minHeight: 50).background(Renk.bal, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial.opacity(0.85), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(Renk.ormanKoyu.opacity(0.7), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, Olcu.kenar)
        .padding(.bottom, 6)
    }

    private func turBitir() {
        withAnimation(.snappy) { tur = nil }
        ViziltiAyari.paylasilan.turKovanId = nil
    }

    private func turDugmesi(_ m: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Text(m).font(Yazi.govdeOrta).foregroundStyle(Renk.krem).lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(.white.opacity(0.1), in: Capsule())
                .overlay(Capsule().strokeBorder(Renk.krem.opacity(0.35)))
        }
        .buttonStyle(.plain)
    }

    private func altPanel(_ yerlesmemis: [Kovan], _ konumlar: [String: CGPoint], _ bugunkuler: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { turBaslat(konumlar, bugunkuler) } label: {
                Label(vurgu ? "Bugünküleri gez (\(bugunkuler.count))" : "Turu başlat", systemImage: "play.fill")
                    .font(Yazi.nunito(16, .heavy)).foregroundStyle(Renk.ormanKoyu)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(LinearGradient(colors: [Renk.bal, Color(red: 0.86, green: 0.6, blue: 0.1)], startPoint: .top, endPoint: .bottom), in: Capsule())
            }
            .buttonStyle(.plain)
            if aciklama { AraziIsaretAciklamasi(koyu: true) }
            HStack(spacing: 6) {
                Button { withAnimation(.snappy) { aciklama.toggle() } } label: {
                    Image(systemName: "info").font(.system(size: 14, weight: .heavy)).foregroundStyle(aciklama ? Renk.ormanKoyu : .white)
                        .frame(width: 28, height: 28).background(aciklama ? AnyShapeStyle(Renk.bal) : AnyShapeStyle(.white.opacity(0.15)), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("İşaretlerin anlamı")
                Rozet(metin: "Ana var", tur: .iyi); Rozet(metin: "Bakire", tur: .bilgi); Rozet(metin: "Anasız", tur: .kotu); Rozet(metin: "Meme", tur: .mor)
                Spacer(minLength: 0)
                Text("%\(Int((olcek * 100).rounded()))").font(Yazi.etiket).foregroundStyle(Color(white: 0.85))
            }
            if secimModu {
                HStack(spacing: 8) {
                    Text("\(secili.count) kovan seçili").font(Yazi.kucukOrta)
                    Spacer()
                    Button("Tümünü seç") { secili = Set(depo.veri.kovanlar.filter { konumlariOku()[$0.id] != nil }.map(\.id)) }
                    Button("Temizle") { secili = [] }.disabled(secili.isEmpty)
                }
                .font(Yazi.kucukOrta).foregroundStyle(Renk.bal)
                Text("Dokun: seç/bırak · Seçili bir kovana uzun basıp sürükle: hepsi birlikte taşınır").font(Yazi.etiket).foregroundStyle(Color(white: 0.85))
            } else {
                Text("Dokun: ayrıntı · Uzun basıp sürükle: taşı · İki parmak: yakınlaş · ✓: toplu taşı").font(Yazi.etiket).foregroundStyle(Color(white: 0.85))
            }
            if !yerlesmemis.isEmpty {
                HStack {
                    Text("Yerleştirilmemiş (\(yerlesmemis.count))").font(Yazi.kucukOrta)
                    Spacer()
                    Button("Hepsini yerleştir") { otomatikYerlestir(yerlesmemis) }.font(Yazi.kucukOrta).foregroundStyle(Renk.bal)
                }
                ScrollView(.horizontal) {
                    HStack { ForEach(yerlesmemis, id: \.id) { k in AraziKovani(kovan: k, genislik: 50).onTapGesture { ac(k.id) } } }
                }
                .scrollIndicators(.hidden)
            }
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(.ultraThinMaterial.opacity(0.85), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(Renk.ormanKoyu.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, Olcu.kenar)
        .padding(.bottom, 6)
    }

    private func yakinlas(_ kat: CGFloat) {
        withAnimation(.snappy) { olcek = min(3, max(0.4, olcek * kat)) }
        bazOlcek = olcek
    }

    private func konumlariOku() -> [String: CGPoint] {
        var s: [String: CGPoint] = [:]
        for (id, d) in depo.veri.araziLayout?["positions"]?.nesneDegeri ?? [:] {
            if let x = d["x"]?.sayi, let y = d["y"]?.sayi { s[id] = CGPoint(x: x, y: y) }
        }
        return s
    }

    private func araLar() -> [(id: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] {
        (depo.veri.araziLayout?["spacers"]?.diziDegeri ?? []).compactMap { a -> (id: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)? in
            guard let id = a["id"]?.metinDegeri, let x = a["x"]?.sayi, let y = a["y"]?.sayi else { return nil }
            return (id, CGFloat(x), CGFloat(y), CGFloat(a["w"]?.sayi ?? 40), CGFloat(a["h"]?.sayi ?? 20))
        }
    }

    private func tasi(_ id: String, _ p: CGPoint, _ f: CGSize) {
        let yeni = CGPoint(x: max(0, (p.x + f.width).rounded()), y: max(0, (p.y + f.height).rounded()))
        konumYaz([id: yeni])
    }

    /// Seçili kovanları birlikte kaydırır; grubun en solu/en üstü 0'ın altına inmez.
    private func grupTasi(_ konumlar: [String: CGPoint], _ f: CGSize) {
        let grup = konumlar.filter { secili.contains($0.key) }
        guard !grup.isEmpty else { return }
        let dx = max(f.width, -(grup.values.map(\.x).min() ?? 0))
        let dy = max(f.height, -(grup.values.map(\.y).min() ?? 0))
        konumYaz(grup.mapValues { CGPoint(x: ($0.x + dx).rounded(), y: ($0.y + dy).rounded()) })
    }

    /// Web araziAutoPlace: ızgara adımları hücre×1,6 / ×2,4, dolu yerleri atla.
    private func otomatikYerlestir(_ liste: [Kovan]) {
        let mevcut = konumlariOku()
        let sutun = max(3, Int(Double(liste.count + mevcut.count).squareRoot().rounded(.up)))
        let cAdim = (80 * 1.6).rounded(), rAdim = (80 * 2.4).rounded()
        var dolu = Set(mevcut.values.map { "\(Int(($0.x / cAdim).rounded())),\(Int(($0.y / rAdim).rounded()))" })
        var c = 0, r = 0
        var yeni: [String: CGPoint] = [:]
        for k in liste {
            while dolu.contains("\(c),\(r)") { c += 1; if c >= sutun { c = 0; r += 1 } }
            dolu.insert("\(c),\(r)")
            yeni[k.id] = CGPoint(x: CGFloat(c) * cAdim + 40, y: CGFloat(r) * rAdim + 40)
        }
        konumYaz(yeni)
    }

    private func konumYaz(_ yeni: [String: CGPoint]) {
        depo.degistir { v in
            var lay = v.araziLayout ?? [:]
            var konum = lay["positions"]?.nesneDegeri ?? [:]
            for (id, p) in yeni { konum[id] = .nesne(["x": .sayidan(p.x), "y": .sayidan(p.y)]) }
            lay["positions"] = .nesne(konum)
            if lay["spacers"] == nil { lay["spacers"] = .dizi([]) }
            lay["_up"] = .tam(VeriDeposu.simdiMs)
            v.araziLayout = lay
        }
    }
}

private struct ElleHedef: Identifiable { let id: String }

/// Arazi işaretlerinin açıklaması: arazideki (i) paneli ve Ayarlar › Arazi işaretleri.
struct AraziIsaretAciklamasi: View {
    let koyu: Bool
    private let aciklamalar: [(AraziIsaret, String)] = [
        (.is_, "Bu kovana bağlı bugünkü ya da gecikmiş iş var (ör. şerit çıkar, tekrar bak)"),
        (.gecikmis, "Son muayenesi \(araziGecikmeGun) günden eski"),
        (.serit, "Varroa şeridi takılı, henüz çıkarılmadı"),
        (.zayif, "Koloni zayıf (güç 1–2)"),
    ]
    var body: some View {
        let metin: Color = koyu ? .white : Renk.metin
        let alt: Color = koyu ? Color(white: 0.85) : Renk.metin2
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("5 · anasız").font(Yazi.nunito(11, .bold)).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 2).background(Renk.kotu, in: Capsule())
                Text("Ana yok — etiket kırmızı").font(Yazi.kucuk).foregroundStyle(alt)
            }
            ForEach(aciklamalar, id: \.0) { i, a in
                let (simge, renk) = araziIsaretGorunumu(i)
                HStack(spacing: 10) {
                    Image(systemName: simge).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 22, height: 22).background(renk, in: Circle()).overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(araziIsaretAdi(i)).font(Yazi.kucukOrta).foregroundStyle(metin)
                        Text(a).font(Yazi.minik).foregroundStyle(alt)
                    }
                }
            }
            Text("“Bugün N kovan”: anasız, işi olan, muayenesi geciken ya da zayıf kovanlar. Dokununca diğerleri soluklaşır; “Bugünküleri gez” yalnız onları sırayla gezer. Arısız kovanlar işaret almaz.")
                .font(Yazi.minik).foregroundStyle(alt)
        }
    }
}

func araziIsaretAdi(_ i: AraziIsaret) -> String {
    switch i {
    case .anasiz: "Anasız"
    case .is_: "Bugün iş var"
    case .gecikmis: "Muayene gecikti"
    case .serit: "Varroa şeridi takılı"
    case .zayif: "Zayıf koloni"
    }
}

private func araziIsaretGorunumu(_ i: AraziIsaret) -> (String, Color) {
    switch i {
    case .anasiz: ("exclamationmark", Renk.kotu)
    case .is_: ("calendar", Color(red: 0.13, green: 0.45, blue: 0.85))
    case .gecikmis: ("clock", Color(red: 0.93, green: 0.5, blue: 0.1))
    case .serit: ("ladybug.fill", Renk.mor)
    case .zayif: ("arrow.down.right", Color(red: 0.75, green: 0.6, blue: 0.05))
    }
}

struct AraziKovani: View {
    let kovan: Kovan
    let genislik: CGFloat
    var isaretler: Set<AraziIsaret> = []
    var turda = false
    @State private var nabiz = false
    var body: some View {
        VStack(spacing: -4) {
            Image(kovan.gorselAdi).resizable().scaledToFit().frame(width: genislik)
                .grayscale(kovan.arisiz ? 1 : 0).opacity(kovan.arisiz ? 0.65 : 1)
                .shadow(color: (kovan.isimaRengi ?? .black).opacity(kovan.isimaRengi == nil ? 0.4 : 0.8), radius: 6)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 4)
            HStack(spacing: 3) {
                if kovan.anaNoktasiGoster && !kovan.sorunlu { AnaNoktasi(renk: kovan.queenColor, boyut: 8) }
                Text(kovan.sorunlu ? "\(kovan.num) · anasız" : kovan.num).font(Yazi.nunito(11, .bold))
            }
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(kovan.sorunlu ? Renk.kotu : etiketRenk, in: Capsule())
            .foregroundStyle(kovan.sorunlu || kovan.queenStatus == "meme" ? .white : Renk.metin)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .padding(.horizontal, 8)
        .background {
            if turda {
                RoundedRectangle(cornerRadius: 14).fill(Renk.bal.opacity(nabiz ? 0.25 : 0.08))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Renk.bal.opacity(nabiz ? 1 : 0.4), lineWidth: 3))
                    .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever()) { nabiz = true } }
                    .onDisappear { nabiz = false }
            }
        }
        .overlay(alignment: .topTrailing) {
            // Durum işaretleri; anasız zaten etikette kırmızı
            let l = isaretler.filter { $0 != .anasiz }.sorted()
            if !l.isEmpty {
                HStack(spacing: -4) {
                    ForEach(l, id: \.self) { i in
                        let (simge, renk) = araziIsaretGorunumu(i)
                        Image(systemName: simge).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 20, height: 20).background(renk, in: Circle())
                            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5)).shadow(color: .black.opacity(0.3), radius: 2)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((["Kovan \(kovan.num), \(kovan.anaDurumMetni)"] + isaretler.filter { $0 != .anasiz }.sorted().map(araziIsaretAdi)).joined(separator: ", "))
    }
    private var etiketRenk: Color { kovan.queenStatus == "meme" ? Renk.mor : kovan.arisiz ? Color(white: 0.75) : Renk.kart }
}
