import AriCekirdek
import SwiftUI
import UniformTypeIdentifiers
import Charts

// MARK: - Raporlar (web Özet sayfası)

struct RaporlarEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var hedef: RaporHedefi?
    enum RaporHedefi: String, Identifiable { case satis, stok; var id: String { rawValue } }

    var body: some View {
        let k = depo.veri.kovanlar
        let s = depo.sezonda(depo.veri.satislar)
        let g = depo.sezonda(depo.veri.giderler)
        let gelir = s.reduce(0) { $0 + ($1.total ?? 0) }, gider = g.reduce(0) { $0 + ($1.amount ?? 0) }
        let net = gelir - gider
        let satis = SatisOzeti(depo: depo)
        let saglik = KoloniSagligi(kovanlar: k)
        let sezonAdi = depo.veri.sezonlar.first { $0.id == depo.ayarlar.activeSeason }?.name ?? "Sezon"
        ScrollView {
            VStack(spacing: 12) {
                // Finans
                DogaKart {
                    HStack {
                        BolumBasligi(simge: "wallet.pass", baslik: "Sezon Finansı", kucuk: true)
                        Spacer()
                        Text(sezonAdi).font(Yazi.minik).foregroundStyle(dahaAltin)
                            .padding(.horizontal, 10).padding(.vertical, 4).background(Renk.bal.opacity(0.18), in: Capsule())
                    }
                    HStack(spacing: 8) {
                        finans("chart.line.uptrend.xyaxis", "Gelir", tl(gelir), Renk.iyi)
                        finans("chart.line.downtrend.xyaxis", "Gider", tl(gider), Renk.kotu)
                        finans("wallet.pass", "Net", tl(net), net >= 0 ? Renk.orman2 : Renk.kotu, vurgu: true)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if gelir + gider > 0 {
                        let oran = gelir / (gelir + gider)
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                Rectangle().fill(Renk.iyi).frame(width: geo.size.width * oran)
                                Rectangle().fill(Renk.kotu.opacity(0.75))
                            }
                        }
                        .frame(height: 10).clipShape(Capsule())
                        HStack {
                            Text("Gelir %\(Int((oran * 100).rounded()))").foregroundStyle(Renk.iyi)
                            Spacer()
                            Text("Gider %\(100 - Int((oran * 100).rounded()))").foregroundStyle(Renk.kotu)
                        }
                        .font(Yazi.minik)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        VStack(spacing: 4) {
                            Halka(oran: satis.tahsilatOrani, renk: Renk.bal, metin: satis.tahsilatOrani.map { "%\(Int(($0 * 100).rounded()))" } ?? "—")
                            Text("Tahsilat").font(Yazi.minik).foregroundStyle(Renk.metin2)
                            Text(satis.bekleyen > 0 ? "\(tl(satis.bekleyen)) bekliyor" : "Bekleyen yok").font(Yazi.minik)
                                .foregroundStyle(satis.bekleyen > 0 ? Renk.uyari : Renk.metin3).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .icKutu()
                        VStack(spacing: 4) {
                            Text("Son 6 ay satış (₺)").font(Yazi.minik).foregroundStyle(Renk.metin2)
                            if satis.aylik.allSatisfy({ $0.tutar == 0 }) {
                                Text("Bu dönemde satış yok").font(Yazi.minik).foregroundStyle(Renk.metin3).frame(maxWidth: .infinity, minHeight: 86)
                            } else {
                                AylikSatisGrafigi(aylik: satis.aylik, yukseklik: 96)
                            }
                        }
                        .icKutu()
                        .layoutPriority(1)
                    }
                }
                // Gider dağılımı
                let giderSatirlari = giderRaporu(g, turler: depo.giderTurleri.map(\.v)).sorted { $0.toplam > $1.toplam }
                if !giderSatirlari.isEmpty {
                    let enBuyuk = max(1, giderSatirlari.map(\.toplam).max() ?? 1)
                    Kart {
                        BolumBasligi(simge: "doc.text", baslik: "Gider Dağılımı", kucuk: true)
                        ForEach(giderSatirlari, id: \.tur) { r in
                            CubukSatiri(simge: giderSimgesi(r.tur), ad: emojisiz(depo.giderTurAdi(r.tur)), alt: "\(r.adet) kayıt", deger: tl(r.toplam), oran: r.toplam / enBuyuk, renk: Renk.kotu.opacity(0.7))
                        }
                    }
                }
                // Kovanlar
                Kart {
                    BolumBasligi(simge: "square.stack.3d.up", baslik: "Kovanlar", kucuk: true)
                    HStack(spacing: 12) {
                        VStack(spacing: 2) {
                            Halka(oran: saglik.oran, renk: Renk.iyi, metin: saglik.oran.map { "%\(Int(($0 * 100).rounded()))" } ?? "—", boyut: 64)
                            Text("Koloni sağlığı").font(Yazi.minik).foregroundStyle(Renk.metin2)
                        }
                        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                            GridRow { sayiHapi("\(k.count)", "toplam", Renk.orman2); sayiHapi("\(saglik.saglikli)", "sağlıklı", Renk.iyi) }
                            GridRow { sayiHapi("\(saglik.riskli)", "riskli", Renk.uyari); sayiHapi("\(k.filter(\.arisiz).count)", "arısız", Renk.metin3) }
                        }
                    }
                    araBaslik("Kovan tipi")
                    let tipler = Dictionary(grouping: k) { ($0.type ?? "").isEmpty ? "—" : $0.type! }.mapValues(\.count).sorted { $0.value > $1.value }
                    let tipEnBuyuk = Double(max(1, tipler.first?.value ?? 1))
                    ForEach(tipler, id: \.key) { e in
                        CubukSatiri(simge: "square.stack.3d.up", ad: e.key, deger: "\(e.value)", oran: Double(e.value) / tipEnBuyuk, renk: Renk.bal)
                    }
                }
                // Ana arı
                Kart {
                    BolumBasligi(simge: "crown", baslik: "Ana Arı Durumu", kucuk: true)
                    let gruplar = Dictionary(grouping: k) { $0.anaDurumMetni }.sorted { $0.value.count > $1.value.count }
                    let enBuyuk = Double(max(1, gruplar.first?.value.count ?? 1))
                    ForEach(gruplar, id: \.key) { e in
                        CubukSatiri(simge: "", ad: e.key, deger: "\(e.value.count)", oran: Double(e.value.count) / enBuyuk, renk: anaDurumRengi(e.value[0]), nokta: true)
                    }
                    let irklar = Dictionary(grouping: k.filter { !($0.race ?? "").isEmpty && !$0.arisiz }) { $0.race! }.mapValues(\.count).sorted { $0.value > $1.value }
                    if !irklar.isEmpty {
                        araBaslik("Irklar")
                        let toplam = Double(max(1, irklar.reduce(0) { $0 + $1.value }))
                        let renkler: [Color] = [Renk.orman2, Renk.bal, Renk.bilgi, Renk.mor, Renk.kotu, Renk.metin3]
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                ForEach(Array(irklar.enumerated()), id: \.offset) { i, e in
                                    Rectangle().fill(renkler[i % renkler.count]).frame(width: geo.size.width * Double(e.value) / toplam)
                                }
                            }
                        }
                        .frame(height: 12).clipShape(Capsule())
                        ForEach(Array(irklar.enumerated()), id: \.offset) { i, e in
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 3).fill(renkler[i % renkler.count]).frame(width: 10, height: 10)
                                Image(systemName: "ladybug").font(.system(size: 12)).foregroundStyle(Renk.metin3)
                                Text(e.key).font(Yazi.govde)
                                Spacer()
                                Text("\(e.value) · %\(Int((Double(e.value) * 100 / toplam).rounded()))").font(Yazi.govdeOrta).foregroundStyle(Renk.metin2)
                            }
                        }
                    }
                }
                // Üretim ve stok
                let urunSatirlari = stokRaporu(depo.veri, urunler: depo.urunler)
                Kart {
                    BolumBasligi(simge: "shippingbox", baslik: "Üretim ve Stok", kucuk: true)
                    HStack {
                        Text("Arı sütü hasadı (sezon)").font(Yazi.govde).foregroundStyle(Renk.metin2)
                        Spacer()
                        Text(miktar(depo.sezonda(depo.veri.hasatlar).reduce(0) { $0 + ($1.amount ?? 0) }, "gr")).font(Yazi.nunito(16, .bold))
                    }
                    .icKutu()
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(urunSatirlari, id: \.urun) { r in
                            let u = depo.urunler.first { $0.v == r.urun }
                            VStack(spacing: 2) {
                                Text(u?.temizAd ?? r.urun).font(Yazi.minik).foregroundStyle(Renk.metin2).lineLimit(1)
                                Text(miktar(r.mevcut, u?.unit ?? "")).font(Yazi.nunito(17, .bold)).foregroundStyle(r.mevcut < 0 ? Renk.kotu : Renk.metin)
                                Text("mevcut").font(Yazi.minik).foregroundStyle(Renk.metin3)
                            }
                            .icKutu()
                        }
                    }
                }
                // Detaylı raporlar
                Kart(dolgu: 6) {
                    Button { hedef = .satis } label: {
                        SimgeliSatir(simge: "cart", renk: dahaAltin, baslik: "Satış raporu", alt: "Ürün, hediye, zekat ve bekleyen ödemeler") { Image(systemName: "chevron.right").foregroundStyle(Renk.metin3) }
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    Rectangle().fill(Renk.krem2).frame(height: 1).padding(.horizontal, 8)
                    Button { hedef = .stok } label: {
                        SimgeliSatir(simge: "chart.bar", renk: dahaAltin, baslik: "Stok raporu", alt: "Giriş, satış, hediye, zekat ve mevcut") { Image(systemName: "chevron.right").foregroundStyle(Renk.metin3) }
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Olcu.kenar)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $hedef) { h in
            switch h {
            case .satis: SatisRaporuSayfasi()
            case .stok: StokRaporuSayfasi()
            }
        }
    }

    private func finans(_ simge: String, _ baslik: String, _ deger: String, _ renk: Color, vurgu: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: simge).font(.system(size: 12, weight: .semibold)).foregroundStyle(renk)
                Text(baslik).font(Yazi.minik).foregroundStyle(Renk.metin2)
            }
            Text(deger).font(Yazi.nunito(15, .bold)).foregroundStyle(renk).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 8).padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(vurgu ? renk.opacity(0.12) : .white.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(renk.opacity(vurgu ? 0.45 : 0.22)))
    }

    private func sayiHapi(_ sayi: String, _ ad: String, _ renk: Color) -> some View {
        HStack(spacing: 6) {
            Text(sayi).font(Yazi.nunito(17, .bold)).foregroundStyle(renk)
            Text(ad).font(Yazi.minik).foregroundStyle(Renk.metin2).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(renk.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func araBaslik(_ m: String) -> some View {
        Text(m.uppercased(with: Locale(identifier: "tr"))).font(Yazi.nunito(11, .bold)).foregroundStyle(Renk.metin3).padding(.top, 6)
    }

    private func anaDurumRengi(_ k: Kovan) -> Color {
        switch k.queenStatus {
        case "yes": return Renk.iyi
        case "no": return Renk.kotu
        case "bakire", "new": return Renk.bilgi
        case "meme": return Renk.mor
        case "empty": return Color(white: 0.6)
        default: return Renk.uyari
        }
    }
}

private extension View {
    func icKutu() -> some View {
        self.padding(10)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Renk.bal.opacity(0.3)))
    }
}

// MARK: - Sezonlar

/// Sezonun bitişi: bir sonraki sezonun başlangıcından bir gün önce; en yeni sezon "devam ediyor" (nil).
func sezonBitisi(_ s: Sezon, _ tumu: [Sezon]) -> String? {
    let bas = sezonBaslangici(s)
    guard let sonraki = tumu.map({ sezonBaslangici($0) }).filter({ $0 > bas }).min(), let d = isoTarih(sonraki),
          let once = Calendar.current.date(byAdding: .day, value: -1, to: d) else { return nil }
    return bugunISO(once)
}

func uzunTarih(_ iso: String) -> String { "\(kisaTarih(iso)) \(iso.prefix(4))" }

struct SezonlarEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var form: KimlikKutusu?
    var body: some View {
        let sezonlar = depo.veri.sezonlar.sorted { sezonBaslangici($0) > sezonBaslangici($1) }
        let aktif = sezonlar.first { $0.id == depo.ayarlar.activeSeason }
        List {
            Section {
                SayfaKahramani(gorsel: "SimgeSezon", baslik: "Sezonlar", alt: "Hesap dönemleri") {
                    HStack(spacing: 8) {
                        OzetKutucuk(simge: "checkmark.circle.fill", etiket: "Aktif sezon", deger: aktif?.name ?? "—", renk: Renk.iyi).layoutPriority(1)
                        OzetKutucuk(simge: "calendar", etiket: "Sezon", deger: "\(sezonlar.count)", renk: dahaAltin)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                EylemDugmesi(simge: "plus", metin: "Yeni sezon", dolu: true) { form = KimlikKutusu(id: "") }
            }
            .listeBasligi()
            Section(footer: Text("Her sezon kendi başlangıcından bir sonraki sezonun başlangıcına kadar sürer; bitiş kendiliğinden hesaplanır. Satış, gider ve arı sütü aktif sezona göre gösterilir; kovanlar, ana arılar ve stok sezon-üstüdür. Düzenlemek ya da silmek için sezona dokun.")) {
                ForEach(sezonlar, id: \.id) { s in
                    let aktifMi = s.id == depo.ayarlar.activeSeason
                    SimgeliSatir(simge: "calendar", renk: aktifMi ? Renk.iyi : dahaAltin, baslik: s.name ?? "Sezon",
                                     alt: "\(uzunTarih(sezonBaslangici(s))) – \(sezonBitisi(s, sezonlar).map { uzunTarih($0) } ?? "devam ediyor")") {
                            if aktifMi { Rozet(metin: "Aktif", tur: .iyi, simge: "checkmark.circle.fill") }
                            else {
                                Button("Aktifleştir") { depo.ayarDegistir { $0.activeSeason = s.id } }
                                    .font(Yazi.kucukOrta).buttonStyle(.borderless).foregroundStyle(Renk.orman2)
                                    .padding(.horizontal, 10).padding(.vertical, 6).background(Renk.orman2.opacity(0.12), in: Capsule())
                            }
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Renk.metin3)
                    }
                    .onTapGesture { form = KimlikKutusu(id: s.id) }
                }
            }
        }
        .sheet(item: $form) { SezonFormu(sezonId: $0.id.isEmpty ? nil : $0.id) }
    }
}

/// Yeni sezon ya da mevcut sezonu düzenle / sil.
struct SezonFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    var sezonId: String? = nil
    @State private var ad = "\(Calendar.current.component(.year, from: Date()) + 1) Sezonu"
    @State private var baslangic = Date()
    @State private var silOnay = false
    @State private var yuklendi = false

    private var mevcut: Sezon? { depo.veri.sezonlar.first { $0.id == sezonId } }
    private var cakisma: Bool { depo.veri.sezonlar.contains { $0.id != sezonId && sezonBaslangici($0) == bugunISO(baslangic) } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ad", text: $ad)
                    DatePicker("Başlangıç", selection: $baslangic, displayedComponents: .date)
                } footer: {
                    Text(cakisma ? "Bu tarihte başlayan başka bir sezon var." : mevcut == nil ? "Oluşturulunca aktif sezon olur. Önceki sezon bu tarihten bir gün önce biter." : "Başlangıcı değiştirince önceki sezonun bitişi de kendiliğinden kayar.")
                }
                if mevcut != nil, depo.veri.sezonlar.count > 1 {
                    Section(footer: Text("Satış, gider ve hasat kayıtları silinmez; tarihlerine göre komşu sezonda görünür.")) {
                        Button("Sezonu sil", role: .destructive) { silOnay = true }
                    }
                }
            }
            .navigationTitle(mevcut == nil ? "Yeni Sezon" : "Sezonu Düzenle").navigationBarTitleDisplayMode(.inline)
            .formArkaplani()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mevcut == nil ? "Oluştur" : "Kaydet") { kaydet(); kapat() }
                        .disabled(ad.trimmingCharacters(in: .whitespaces).isEmpty || cakisma)
                }
            }
            .confirmationDialog("\(mevcut?.name ?? "Sezon") silinsin mi?", isPresented: $silOnay, titleVisibility: .visible) {
                Button("Sil", role: .destructive) { sil(); kapat() }
            } message: { Text("Kayıtlar silinmez, yalnızca sezon tanımı kalkar.") }
            .onAppear {
                guard !yuklendi else { return }
                yuklendi = true
                if let m = mevcut { ad = m.name ?? ""; baslangic = isoTarih(sezonBaslangici(m)) ?? Date() }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func kaydet() {
        let yil = Calendar.current.component(.year, from: baslangic)
        let bas = bugunISO(baslangic)
        let temiz = ad.trimmingCharacters(in: .whitespaces)
        if let sezonId {
            depo.degistir { v in
                var l = v.sezonlar
                if let i = l.firstIndex(where: { $0.id == sezonId }) { l[i].name = temiz; l[i].start = bas; l[i].year = yil; v.sezonlar = l }
            }
        } else {
            let id = yeniKimlik()
            depo.degistir { v in
                v.sezonlar = v.sezonlar + [Sezon(["id": .metin(id), "year": .tam(Int64(yil)), "name": .metin(temiz), "active": .bool(true), "start": .metin(bas)])]
            }
            depo.ayarDegistir { $0.activeSeason = id }
        }
    }

    private func sil() {
        guard let sezonId else { return }
        depo.degistir { v in v.sezonlar = v.sezonlar.filter { $0.id != sezonId } }
        if depo.ayarlar.activeSeason == sezonId {
            let yeni = depo.veri.sezonlar.max { sezonBaslangici($0) < sezonBaslangici($1) }?.id
            depo.ayarDegistir { $0.activeSeason = yeni }
        }
    }
}

// MARK: - Hava

/// Geniş hava sayfası: şimdi kartı (gökyüzü renginde), arıcılık yorumu, 24 saat şeridi, 7 gün listesi, şehir.
struct HavaEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var hava: HavaDurumu?
    @State private var hata = false
    @State private var sehir = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let h = hava {
                    simdiKarti(h)
                    aricilikKarti(h)
                    if let uzun = h.saatlikUzun, !uzun.isEmpty { saatlikKart(uzun) }
                    gunlukKart(h)
                } else {
                    VStack(spacing: 10) {
                        if hata {
                            Image(systemName: "icloud.slash").font(.system(size: 30)).foregroundStyle(Renk.metin3)
                            Text("Hava durumu alınamadı. İnternet bağlantını ve şehri kontrol et.").font(Yazi.govde).foregroundStyle(Renk.metin2).multilineTextAlignment(.center)
                        } else {
                            ProgressView().tint(Renk.orman2)
                            Text("Hava durumu yükleniyor…").font(Yazi.govde).foregroundStyle(Renk.metin3)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .dogaZemini()
                }
                sehirKarti
            }
            .padding(.horizontal, Olcu.kenar)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .task(id: depo.ayarlar.city) {
            sehir = depo.ayarlar.city ?? "Muğla"
            hata = false
            do { hava = try await HavaServisi.paylasilan.getir(sehir: sehir.isEmpty ? "Muğla" : sehir) } catch { hata = true }
        }
    }

    // MARK: Parçalar

    /// Hava koduna göre gökyüzü degradesi (açık mavi / bulutlu gri / yağmurlu koyu / gece lacivert değil — gündüz paleti).
    private func gokyuzu(_ kod: Int) -> [Color] {
        switch kod {
        case 0, 1: return [Color(red: 0.24, green: 0.56, blue: 0.86), Color(red: 0.55, green: 0.78, blue: 0.95)]
        case 2, 3, 45, 48: return [Color(red: 0.36, green: 0.45, blue: 0.55), Color(red: 0.6, green: 0.68, blue: 0.75)]
        case 95...99: return [Color(red: 0.2, green: 0.2, blue: 0.3), Color(red: 0.4, green: 0.4, blue: 0.5)]
        default: return [Color(red: 0.26, green: 0.35, blue: 0.46), Color(red: 0.45, green: 0.55, blue: 0.65)]
        }
    }

    private func simdiKarti(_ h: HavaDurumu) -> some View {
        let bugun = h.gunlukEk?.first
        let gun = h.gunluk.first
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 13, weight: .semibold))
                Text(h.sehir + (h.rakim.map { " · \($0) m" } ?? "")).font(Yazi.kucukOrta)
                Spacer()
                Text("Şimdi").font(Yazi.minik).padding(.horizontal, 8).padding(.vertical, 3).background(.white.opacity(0.2), in: Capsule())
            }
            .foregroundStyle(.white.opacity(0.92))
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: h.simge).symbolRenderingMode(.multicolor).font(.system(size: 58))
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(h.derece)°").font(Yazi.nunito(56, .bold)).foregroundStyle(.white)
                    Text(h.durumMetni).font(Yazi.govdeOrta).foregroundStyle(.white)
                    if let gun { Text("En düşük \(gun.enDusuk)° · En yüksek \(gun.enYuksek)°").font(Yazi.etiket).foregroundStyle(.white.opacity(0.85)) }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                kutucuk("thermometer.medium", "Hissedilen", "\(h.hissedilen)°")
                kutucuk("humidity", "Nem", "%\(h.nem)")
                kutucuk("wind", "Rüzgâr", "\(h.ruzgar) km/s")
                kutucuk("drop", "Yağış", "%\(bugun?.yagis ?? 0)")
            }
            if let d = bugun?.dogus, let b = bugun?.batis {
                HStack(spacing: 14) {
                    Label(d, systemImage: "sunrise.fill")
                    Label(b, systemImage: "sunset.fill")
                    Spacer()
                }
                .font(Yazi.etiket).foregroundStyle(.white.opacity(0.9)).symbolRenderingMode(.multicolor)
            }
        }
        .padding(16)
        .background(LinearGradient(colors: gokyuzu(h.kod), startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Image("KartYaprak").resizable().scaledToFit().frame(width: 90).scaleEffect(x: -1).opacity(0.85).allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.35)))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
    }

    private func kutucuk(_ simge: String, _ ad: String, _ deger: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: simge).font(.system(size: 14, weight: .semibold)).foregroundStyle(Renk.acikBal)
            Text(deger).font(Yazi.nunito(15, .bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(ad).font(Yazi.minik).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func aricilikKarti(_ h: HavaDurumu) -> some View {
        var engeller: [String] = []
        if h.derece < 15 { engeller.append("hava serin (\(h.derece)°)") }
        if h.ruzgar > 20 { engeller.append("rüzgâr sert (\(h.ruzgar) km/s)") }
        if h.kod >= 51 { engeller.append(h.durumMetni.lowercased(with: Locale(identifier: "tr"))) }
        let uygun = engeller.isEmpty
        let renk = uygun ? Renk.iyi : Renk.uyari
        let liste = engeller.joined(separator: ", ")
        let bas: String = String(liste.prefix(1)).uppercased(with: Locale(identifier: "tr"))
        let aciklama: String = uygun ? "Sıcak, sakin ve kuru. Kovan açmak için iyi bir zaman." : bas + String(liste.dropFirst()) + ". Kovanı açmayı ertele."
        // Bugün içinde uygun saat önerisi: 15°+ , rüzgâr ≤ 20, yağış < %30
        let uygunSaat = (h.saatlikUzun ?? []).first { $0.derece >= 15 && $0.ruzgar <= 20 && $0.yagis < 30 && $0.kod < 51 }
        return DogaKart {
            BolumBasligi(simge: "ladybug", baslik: "Arıcılık için", kucuk: true)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: uygun ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 22)).foregroundStyle(renk)
                    .frame(width: 44, height: 44).background(renk.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(uygun ? "Muayeneye uygun" : "Muayene için uygun değil").font(Yazi.govdeOrta).foregroundStyle(renk)
                    Text(aciklama).font(Yazi.kucuk).foregroundStyle(Renk.metin2)
                    if !uygun, let s = uygunSaat {
                        Label("En yakın uygun saat: \(s.tarih == bugunISO() ? "bugün" : kisaTarih(s.tarih)) \(String(format: "%02d:00", s.saat)) (\(s.derece)°)", systemImage: "clock")
                            .font(Yazi.etiket).foregroundStyle(Renk.orman2).padding(.top, 2)
                    }
                }
            }
        }
    }

    private func saatlikKart(_ uzun: [HavaDurumu.UzunSaat]) -> some View {
        Kart {
            BolumBasligi(simge: "clock", baslik: "24 saat", kucuk: true)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(uzun) { s in
                        VStack(spacing: 4) {
                            Text(String(format: "%02d", s.saat)).font(Yazi.etiket).foregroundStyle(Renk.metin2)
                            Image(systemName: HavaDurumu.simge(s.kod)).symbolRenderingMode(.multicolor).font(.system(size: 20)).frame(height: 24)
                            Text("\(s.derece)°").font(Yazi.nunito(15, .bold))
                            Text(s.yagis > 0 ? "%\(s.yagis)" : " ").font(Yazi.minik).foregroundStyle(Renk.bilgi)
                            Text("\(s.ruzgar) km").font(Yazi.minik).foregroundStyle(Renk.metin3)
                        }
                        .frame(width: 48)
                        .padding(.vertical, 8)
                        .background(s.saat == 12 ? Renk.bal.opacity(0.12) : Renk.kart, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Renk.krem2))
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func gunlukKart(_ h: HavaDurumu) -> some View {
        let gunAdlari = ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"]
        let enDusuk = h.gunluk.map(\.enDusuk).min() ?? 0
        let enYuksek = h.gunluk.map(\.enYuksek).max() ?? 1
        let aralik = Double(max(1, enYuksek - enDusuk))
        return Kart {
            BolumBasligi(simge: "calendar", baslik: "7 gün", kucuk: true)
            ForEach(Array(h.gunluk.enumerated()), id: \.offset) { i, d in
                let ek = h.gunlukEk?.first { $0.tarih == d.tarih }
                let ad = i == 0 ? "Bugün" : isoTarih(d.tarih).map { gunAdlari[Calendar.current.component(.weekday, from: $0) - 1] } ?? kisaTarih(d.tarih)
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(ad).font(Yazi.govdeOrta)
                        Text(kisaTarih(d.tarih)).font(Yazi.minik).foregroundStyle(Renk.metin3)
                    }
                    .frame(width: 58, alignment: .leading)
                    Image(systemName: HavaDurumu.simge(d.kod)).symbolRenderingMode(.multicolor).font(.system(size: 18)).frame(width: 26)
                    Text((ek?.yagis ?? 0) > 0 ? "%\(ek!.yagis)" : "").font(Yazi.minik).foregroundStyle(Renk.bilgi).frame(width: 34, alignment: .leading)
                    Text("\(d.enDusuk)°").font(Yazi.kucuk).foregroundStyle(Renk.metin3).frame(width: 30, alignment: .trailing)
                    // Sıcaklık aralığı çubuğu (haftanın en düşük–en yüksek aralığına göre)
                    GeometryReader { g in
                        let bas = Double(d.enDusuk - enDusuk) / aralik * g.size.width
                        let gen = max(6, Double(d.enYuksek - d.enDusuk) / aralik * g.size.width)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Renk.krem2)
                            Capsule().fill(LinearGradient(colors: [Renk.bilgi.opacity(0.7), Renk.bal], startPoint: .leading, endPoint: .trailing))
                                .frame(width: gen).offset(x: bas)
                        }
                    }
                    .frame(height: 6)
                    Text("\(d.enYuksek)°").font(Yazi.kucukOrta).frame(width: 30, alignment: .leading)
                }
                .padding(.vertical, 4)
                if i < h.gunluk.count - 1 { Rectangle().fill(Renk.krem2).frame(height: 1) }
            }
        }
    }

    private var sehirKarti: some View {
        Kart {
            BolumBasligi(simge: "mappin.and.ellipse", baslik: "Şehir", kucuk: true)
            HStack(spacing: 8) {
                TextField("Şehir", text: $sehir).font(Yazi.govde)
                    .padding(.horizontal, 12).frame(height: 44)
                    .background(Renk.kart, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Renk.krem2))
                    .onSubmit { depo.ayarDegistir { $0.city = sehir.trimmingCharacters(in: .whitespaces) } }
                Button { depo.ayarDegistir { $0.city = sehir.trimmingCharacters(in: .whitespaces) } } label: {
                    Text("Kaydet").font(Yazi.govdeOrta).foregroundStyle(.white).padding(.horizontal, 16).frame(height: 44)
                        .background(Renk.orman2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Yedek

struct YedekDosyasi: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var veri: Data
    init(veri: Data) { self.veri = veri }
    init(configuration: ReadConfiguration) throws { veri = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: veri) }
}

struct YedekEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var disari = false
    @State private var iceri = false
    @State private var bekleyenIce: (BBVeri, Ayarlar?)?
    /// Dosya seçici Bal Defterim yedeği için mi açıldı (tek `fileImporter`; iki tane aynı görünümde çakışır).
    @State private var balModu = false
    @State private var bekleyenBal: BalAktarim?
    @State private var mesaj: String?

    var body: some View {
        let son = depo.ayarlar.lastBackup
        let gun: Int? = son.flatMap { isoTarih($0) }.flatMap { Calendar.current.dateComponents([.day], from: $0, to: Date()).day }
        List {
            Section {
                SayfaKahramani(gorsel: "SimgeYedek", baslik: "Yedek", alt: "Verilerini dosyaya al, geri yükle") {
                    HStack(spacing: 8) {
                        OzetKutucuk(simge: "clock.arrow.circlepath", etiket: "Son yedek", deger: son.map { uzunTarih(String($0.prefix(10))) } ?? "Hiç alınmadı",
                                    renk: (gun ?? 999) > 30 ? Renk.uyari : Renk.iyi).layoutPriority(1)
                        OzetKutucuk(simge: "square.stack.3d.up", etiket: "Kovan", deger: "\(depo.veri.kovanlar.count)", renk: dahaAltin)
                        OzetKutucuk(simge: "cart", etiket: "Satış", deger: "\(depo.veri.satislar.count)", renk: Renk.orman2)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if (gun ?? 999) > 30 {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle").foregroundStyle(Renk.uyari)
                            Text(gun == nil ? "Henüz yedek almadın. Telefon kaybolursa veriler gider; ara sıra yedek al." : "Son yedeğin \(gun!) gün önce. Yeni bir yedek almanı öneririz.")
                                .font(Yazi.minik).foregroundStyle(Renk.metin2)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Renk.uyari.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                EylemDugmesi(simge: "square.and.arrow.up", metin: "Yedek al (JSON)", dolu: true) { disari = true }
                EylemDugmesi(simge: "square.and.arrow.down", metin: "Yedek yükle") { balModu = false; iceri = true }
                Text("Yedek dosyası web, iPhone ve Android BeeBook ile aynı biçimdedir; her yönde yüklenebilir. Yüklemek mevcut verinin yerine geçer.")
                    .font(Yazi.kucuk).foregroundStyle(Renk.metin3).padding(.horizontal, 6)
            }
            .listeBasligi()
            Section(header: Label("Bal Defterim", systemImage: "arrow.left.arrow.right"), footer: Text("Bal Defterim'den aldığın yedeği (bal-defterim-yedek-….json) yükle: siparişler satışa, hasatlar stoğa, zekatlar zekat kaydına çevrilir. Mevcut kayıtların silinmez; aynı yedeği yeniden yüklersen kopya oluşmaz, güncellenir.")) {
                Button { balModu = true; iceri = true } label: {
                    SimgeliSatir(simge: "arrow.left.arrow.right", renk: dahaAltin, baslik: "Bal Defterim yedeğini içe aktar", alt: "Sipariş, hasat ve zekatlar eklenir") {
                        Image(systemName: "chevron.right").foregroundStyle(Renk.metin3)
                    }
                }
                .buttonStyle(.plain)
            }
            if let mesaj { Section { Label(mesaj, systemImage: "info.circle").foregroundStyle(Renk.metin) } }
        }
        .fileExporter(isPresented: $disari, document: YedekDosyasi(veri: yedekVerisi()), contentType: .json, defaultFilename: "beebook-yedek-\(bugunISO()).json") { s in
            if case .success = s { depo.ayarDegistir { $0.lastBackup = bugunISO() }; mesaj = "Yedek kaydedildi." }
        }
        .fileImporter(isPresented: $iceri, allowedContentTypes: [.json]) { s in
            guard case .success(let url) = s else { return }
            let erisim = url.startAccessingSecurityScopedResource()
            defer { if erisim { url.stopAccessingSecurityScopedResource() } }
            if balModu {
                guard let j = try? JSONDecoder().decode(JSONDeger.self, from: Data(contentsOf: url)) else {
                    mesaj = "Yedek okunamadı: dosya bozuk ya da Bal Defterim yedeği değil."; return
                }
                if balDefterimYedegiMi(j) { bekleyenBal = balDefterimAktarimi(j, veri: depo.veri, ayarlar: depo.ayarlar) }
                else { mesaj = "Bu dosya Bal Defterim yedeği değil." }
                return
            }
            do {
                let j = try JSONDecoder().decode(JSONDeger.self, from: Data(contentsOf: url))
                bekleyenIce = try yedegiNormallestir(j, buYil: Calendar.current.component(.year, from: Date()))
            } catch { mesaj = "Yedek okunamadı: dosya bozuk ya da Beebook yedeği değil." }
        }
        .alert("Bal Defterim yedeği eklensin mi?", isPresented: Binding(get: { bekleyenBal != nil }, set: { if !$0 { bekleyenBal = nil } })) {
            Button("Ekle") {
                if let t = bekleyenBal {
                    depo.ayarDegistir { t.ayarlaraUygula(&$0) }
                    let urunler = depo.urunler
                    depo.degistir { v in t.veriyeUygula(&v) { u in urunler.first { $0.v == u }.flatMap { Birim(rawValue: $0.unit) } } }
                    mesaj = "Bal Defterim yedeği eklendi: \(t.ozet)."
                }
                bekleyenBal = nil
            }
            Button("Vazgeç", role: .cancel) { bekleyenBal = nil }
        } message: {
            Text("\(bekleyenBal?.ozet ?? "") eklenecek.\n\nBu satışları BeeBook'a elle de girdiysen iki kez sayılır.")
        }
        .confirmationDialog("Yedek yüklensin mi?", isPresented: Binding(get: { bekleyenIce != nil }, set: { if !$0 { bekleyenIce = nil } }), titleVisibility: .visible) {
            Button("Yükle (mevcut verinin yerine)", role: .destructive) {
                if let b = bekleyenIce { depo.tumunuDegistir(veri: b.0, ayarlar: b.1); mesaj = "Yedek yüklendi." }
                bekleyenIce = nil
            }
        } message: { Text("Mevcut kovan, satış ve diğer kayıtlar yedektekiyle değiştirilir.") }
    }

    private func yedekVerisi() -> Data {
        let j: JSONDeger = .nesne([
            "version": .metin(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.0"),
            "exportDate": .metin(ISO8601DateFormatter().string(from: Date())),
            "data": .nesne(depo.veri.ham), "settings": .nesne(depo.ayarlar.ham)])
        return (try? JSONEncoder().encode(j)) ?? Data()
    }
}

// MARK: - Ayarlar

struct AyarlarEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(OturumYoneticisi.self) private var oturum
    @Environment(\.openURL) private var ac
    @State private var silOnay1 = false
    @State private var silOnay2 = false
    @State private var mesaj: String?
    @State private var yeniTip = ""
    @State private var yeniIrk = ""
    @State private var renkler = false

    var body: some View {
        List {
            Section {
                SayfaKahramani(gorsel: "SimgeAyarlar", baslik: "Ayarlar", alt: "BeeBook \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")") {
                    if oturum.durum == .hesapsiz {
                        HStack(spacing: 10) {
                            Image(systemName: "icloud.slash").font(.system(size: 20)).foregroundStyle(Renk.uyari)
                            Text("İnternetsiz kullanıyorsun; veriler yalnız bu telefonda.").font(Yazi.kucuk).foregroundStyle(Renk.metin2)
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        EylemDugmesi(simge: "person.crop.circle.badge.checkmark", metin: "Giriş yap ve eşitle", dolu: true) { oturum.girisEkraninaDon() }
                    } else {
                        HStack(spacing: 10) {
                            Text(String(oturum.adSoyad.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased(with: Locale(identifier: "tr")))
                                .font(Yazi.nunito(19, .bold)).foregroundStyle(Renk.acikBal)
                                .frame(width: 44, height: 44)
                                .background(LinearGradient(colors: [Renk.orman2, Renk.orman], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                                .overlay(Circle().strokeBorder(Renk.bal, lineWidth: 1.5))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(oturum.adSoyad).font(Yazi.govdeOrta).lineLimit(1)
                                Text(oturum.epostaGorunen).font(Yazi.etiket).foregroundStyle(Renk.metin2).lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            let durum: (String, Color, String) = depo.esitleniyor ? ("Eşitleniyor", Renk.bilgi, "arrow.triangle.2.circlepath")
                                : depo.sonHata != nil ? ("Hata", Renk.uyari, "exclamationmark.icloud") : ("Eşitlendi", Renk.iyi, "checkmark.icloud")
                            Label(durum.0, systemImage: durum.2).font(Yazi.minik).foregroundStyle(durum.1)
                                .padding(.horizontal, 8).padding(.vertical, 4).background(durum.1.opacity(0.12), in: Capsule())
                        }
                        .padding(12)
                        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        if let h = depo.sonHata { Text("Eşitlenemedi: \(h)").font(Yazi.minik).foregroundStyle(Renk.uyari) }
                    }
                }
            }
            .listeBasligi()
            Section(header: Label("Profil", systemImage: "person")) {
                TextField("Adın", text: Binding(get: { depo.ayarlar.userName ?? "" }, set: { v in depo.ayarDegistir { $0.userName = v } }))
                TextField("Telefon", text: Binding(get: { depo.ayarlar.userPhone ?? "" }, set: { v in depo.ayarDegistir { $0.userPhone = v } })).keyboardType(.phonePad)
                TextField("Hava durumu şehri", text: Binding(get: { depo.ayarlar.city ?? "" }, set: { v in depo.ayarDegistir { $0.city = v } }))
            }
            Section(header: Label("Kovan tipleri", systemImage: "square.stack.3d.up"), footer: Text("Silmek için sola kaydır; sırayı değiştirmek için basılı tutup sürükle.")) {
                ForEach(depo.kovanTipleri, id: \.self) { t in Label(t, systemImage: "square.stack.3d.up").foregroundStyle(Renk.metin) }
                    .onDelete { i in let l = depo.kovanTipleri; depo.ayarDegistir { a in a.hiveTypes = l.enumerated().filter { !i.contains($0.offset) }.map(\.element) } }
                    .onMove { f, t in var l = depo.kovanTipleri; l.move(fromOffsets: f, toOffset: t); depo.ayarDegistir { $0.hiveTypes = l } }
                HStack {
                    TextField("Yeni tip", text: $yeniTip)
                    Button { let l = depo.kovanTipleri + [yeniTip.trimmingCharacters(in: .whitespaces)]; depo.ayarDegistir { $0.hiveTypes = l }; yeniTip = "" } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 26)).foregroundStyle(yeniTip.isEmpty ? Renk.krem2 : Renk.orman2)
                    }
                    .buttonStyle(.borderless).disabled(yeniTip.isEmpty)
                }
            }
            Section(header: Label("Kovan renkleri", systemImage: "paintpalette")) {
                Button { renkler = true } label: {
                    HStack {
                        Label("Işıma ve renk durumları", systemImage: "paintpalette").foregroundStyle(Renk.metin)
                        Spacer()
                        Text(depo.ayarlar.hiveMarksOn ? "Açık" : "").font(Yazi.etiket).foregroundStyle(Renk.metin2)
                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Renk.metin3)
                    }
                }
                .sheet(isPresented: $renkler) { KovanRenkleriSayfasi() }
            }
            BildirimAyarlariBolumu()
            Section(header: Label("Arazi işaretleri", systemImage: "map"), footer: Text("Arazi ekranında kovanların köşesindeki işaretler. Arazide (i) düğmesiyle de görünür.")) {
                AraziIsaretAciklamasi(koyu: false).padding(.vertical, 4)
            }
            ViziltiAyarlariBolumu()
            VarroaIlaclariBolumu()
            Section(header: Label("Arı ırkları", systemImage: "ladybug"), footer: Text("Silmek için sola kaydır.")) {
                ForEach(depo.irklar, id: \.self) { t in Label(t, systemImage: "ladybug").foregroundStyle(Renk.metin) }
                    .onDelete { i in let l = depo.irklar; depo.ayarDegistir { a in a.beeRaces = l.enumerated().filter { !i.contains($0.offset) }.map(\.element) } }
                HStack {
                    TextField("Yeni ırk", text: $yeniIrk)
                    Button { let l = depo.irklar + [yeniIrk.trimmingCharacters(in: .whitespaces)]; depo.ayarDegistir { $0.beeRaces = l }; yeniIrk = "" } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 26)).foregroundStyle(yeniIrk.isEmpty ? Renk.krem2 : Renk.orman2)
                    }
                    .buttonStyle(.borderless).disabled(yeniIrk.isEmpty)
                }
            }
            Section {
                Button { UygulamaYasami.paylasilan.magazayiAc(yorum: true) } label: {
                    SimgeliSatir(simge: "star", renk: dahaAltin, baslik: "Uygulamayı puanla", alt: "App Store'da yorum yaz") { Image(systemName: "chevron.right").foregroundStyle(Renk.metin3) }
                }
                .buttonStyle(.plain)
                Button { ac(Sabitler.gizlilik) } label: {
                    SimgeliSatir(simge: "hand.raised", renk: Renk.orman2, baslik: "Gizlilik politikası") { Image(systemName: "chevron.right").foregroundStyle(Renk.metin3) }
                }
                .buttonStyle(.plain)
                if oturum.durum == .girisli {
                    Button { Task { await oturum.cikis() } } label: { SimgeliSatir(simge: "rectangle.portrait.and.arrow.right", renk: Renk.orman2, baslik: "Çıkış yap") }
                        .buttonStyle(.plain)
                    Button { silOnay1 = true } label: { SimgeliSatir(simge: "trash", renk: Renk.kotu, baslik: "Hesabımı sil", alt: "Tüm verilerin kalıcı olarak silinir") }
                        .buttonStyle(.plain)
                }
            } header: { Label("Uygulama", systemImage: "info.circle") } footer: { Text("BeeBook \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")") }
            if let mesaj { Section { Text(mesaj) } }
        }
        .confirmationDialog("Hesabın silinsin mi?", isPresented: $silOnay1, titleVisibility: .visible) {
            Button("Devam", role: .destructive) { silOnay2 = true }
        } message: { Text("Tüm Beebook verilerin (kovanlar, satışlar, ürün fotoğrafları) kalıcı olarak silinir.") }
        .alert("GERİ ALINAMAZ", isPresented: $silOnay2) {
            Button("Vazgeç", role: .cancel) {}
            Button("Hesabımı sil", role: .destructive) {
                Task {
                    do { let tum = try await oturum.hesabiSil(); _ = tum } catch { mesaj = "Silinemedi: \(error.localizedDescription)" }
                }
            }
        } message: { Text("Bu işlem geri alınamaz. Emin misin?") }
    }
}
