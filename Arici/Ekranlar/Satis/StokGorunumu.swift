import AriCekirdek
import SwiftUI

/// Satış › Stok (yenilogoo/stokdetay): ürün stok özeti + toplam değer, son satışlar, hediye/zekat,
/// otomatik stok hareketleri, aylık gider özeti. Ürün ekle (20 sınırı), stok girişi, zekat, rapor.
struct StokGorunumu: View {
    @Environment(VeriDeposu.self) private var depo
    var satislaraGit: () -> Void = {}
    @State private var urunForm: KimlikKutusu?
    @State private var yeniUrun = false
    @State private var giris = false
    @State private var zekat = false
    @State private var odemeListesi: KimlikKutusu?
    @State private var urunStok: KimlikKutusu?
    @State private var rapor = false
    /// Stok hareketine dokununca açılan kayıt (satış / hasat / elle giriş-çıkış).
    @State private var hareketForm: HareketHedefi?
    @State private var tumHareketler = false
    /// Hareket süzgeci: "giris" (varsayılan) | "cikis" | "tumu"; ürün süzgeci nil = tümü.
    @State private var hareketTuru = "giris"
    @State private var hareketUrunu: String?

    var body: some View {
        let urunler = depo.urunler
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                kapsul("Stok girişi", "plus") { giris = true }
                kapsul("Zekat", "moon.stars") { zekat = true }
                kapsul("Rapor", "chart.bar") { rapor = true }
            }
            urunOzeti(urunler)
            giderOzeti
            sonSatislar(urunler)
            HStack(spacing: 10) {
                Button { odemeListesi = KimlikKutusu(id: "hediye") } label: { hediyeZekat(baslik: "Hediye", simge: "gift", odeme: "hediye", urunler: urunler) }.buttonStyle(.plain)
                Button { odemeListesi = KimlikKutusu(id: "zekat") } label: { hediyeZekat(baslik: "Zekat", simge: "moon.stars", odeme: "zekat", urunler: urunler) }.buttonStyle(.plain)
            }
            otomatikBilgi
            hareketler(urunler)
        }
        .sheet(item: $urunForm) { UrunFormu(urunId: $0.id) }
        .sheet(isPresented: $yeniUrun) { UrunFormu(urunId: nil) }
        .sheet(isPresented: $giris) { StokGirisFormu() }
        .sheet(isPresented: $zekat) { ZekatSayfasi() }
        .sheet(item: $odemeListesi) { OdemeKayitlariSayfasi(tur: $0.id) }
        .sheet(item: $urunStok) { UrunStokSayfasi(urunId: $0.id) }
        .sheet(isPresented: $rapor) { StokRaporuSayfasi() }
        .sheet(item: $hareketForm) { h in
            switch h {
            case .satis(let id): SatisFormu(satisId: id)
            case .hasat(let id): HasatFormu(hasatId: id)
            case .giris(let id): StokGirisFormu(kayitId: id)
            }
        }
    }

    // MARK: Ürün stok özeti

    private func urunOzeti(_ urunler: [UrunTanimi]) -> some View {
        let toplam = urunler.reduce(0) { $0 + max(0, stokSeviyesi(depo.veri, urun: $1.v)) * (depo.ayarlar.stockPrices[$1.v] ?? 0) }
        let eklenebilir = urunEklenebilir(depo.ayarlar)
        return DogaKart {
            HStack {
                BolumBasligi(simge: "shippingbox.fill", baslik: "Ürün Stok Özeti")
                Spacer(minLength: 4)
                HStack(spacing: 5) {
                    Text("Toplam").font(Yazi.minik).foregroundStyle(Color(white: 0.85))
                    Text(tl(toplam)).font(Yazi.nunito(16, .bold)).foregroundStyle(Renk.bal)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Renk.orman, in: Capsule())
            }
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    // Pasif ürün: stoğu bitmişse gizlenir (Ayarlar'dan değil, ürün formundan yeniden aktif edilir).
                    ForEach(urunler.filter { $0.pasif != true || stokSeviyesi(depo.veri, urun: $0.v) != 0 }, id: \.v) { u in
                        Button { urunStok = KimlikKutusu(id: u.v) } label: { urunKutusu(u, stokSeviyesi(depo.veri, urun: u.v)) }.buttonStyle(.plain)
                    }
                    Button { yeniUrun = true } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 26, weight: .medium))
                            Text("Ürün ekle").font(Yazi.kucukOrta)
                            Text(eklenebilir ? "kg · lt · gr · adet" : "En fazla \(ozelUrunSiniri)").font(Yazi.minik).opacity(0.8)
                        }
                        .foregroundStyle(Renk.orman2)
                        .frame(width: 112, height: 184)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Renk.bal.opacity(0.8), style: StrokeStyle(lineWidth: 1.6, dash: [6, 5])))
                    }
                    .buttonStyle(.plain)
                    .disabled(!eklenebilir)
                    .opacity(eklenebilir ? 1 : 0.5)
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func urunKutusu(_ u: UrunTanimi, _ mevcut: Double) -> some View {
        let fiyat = depo.ayarlar.stockPrices[u.v] ?? 0
        let rezerve = rezerveMiktar(depo.veri, urun: u.v, urunBirimi: Birim(rawValue: u.unit))
        return VStack(spacing: 5) {
            UrunGorseli(urun: u, boyut: 76, yaricap: 16).opacity(u.pasif == true ? 0.55 : 1)
            Text(u.pasif == true ? "\(u.temizAd) · pasif" : u.temizAd).font(Yazi.kucukOrta).lineLimit(1).minimumScaleFactor(0.7)
            Divider().overlay(Renk.krem2)
            HStack(spacing: 4) {
                Image(systemName: "cube.box").font(.system(size: 10)).foregroundStyle(Renk.bal)
                Text(miktar(mevcut, u.unit)).font(Yazi.kucukOrta).foregroundStyle(mevcut <= 0 ? Renk.metin3 : Renk.metin)
            }
            if rezerve > 0 {
                Text("+\(miktar(rezerve, u.unit)) rezerve").font(Yazi.minik).foregroundStyle(Renk.uyari).lineLimit(1).minimumScaleFactor(0.8)
            }
            HStack(spacing: 4) {
                Image(systemName: "turkishlirasign.circle").font(.system(size: 10)).foregroundStyle(Renk.bal)
                Text(fiyat > 0 ? tl(max(0, mevcut) * fiyat) : "fiyat yok").font(Yazi.minik).foregroundStyle(Renk.metin2)
            }
        }
        .padding(8)
        .frame(width: 112, height: 184)
        .background(Renk.kart, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Renk.krem2))
        .accessibilityElement(children: .combine)
    }

    // MARK: Son satışlar

    private func sonSatislar(_ urunler: [UrunTanimi]) -> some View {
        let son = depo.sezonda(depo.veri.satislar).sorted { ($0.date ?? "") > ($1.date ?? "") }.prefix(3)
        return DogaKart {
            HStack {
                BolumBasligi(simge: "cart", baslik: "Son Satışlar")
                Spacer()
                Button(action: satislaraGit) {
                    HStack(spacing: 2) { Text("Tümünü gör"); Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)) }
                }
                .font(Yazi.etiket).foregroundStyle(Renk.orman2)
            }
            if son.isEmpty { Text("Bu sezon satış yok.").font(Yazi.kucuk).foregroundStyle(Renk.metin3) }
            ForEach(Array(son), id: \.id) { s in
                HStack(spacing: 10) {
                    UrunGorseli(urun: satisStokUrunu(s).flatMap { p in urunler.first { $0.v == p } }, boyut: 40, yaricap: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(s.customer?.isEmpty == false ? s.customer! : "Müşteri").font(Yazi.kucukOrta).lineLimit(1)
                            Text(s.date.map { kisaTarih($0) } ?? "").font(Yazi.minik).foregroundStyle(Renk.metin3)
                        }
                        Text(s.etiket(urunler: urunler)).font(Yazi.kucuk).foregroundStyle(Renk.metin2).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 3) {
                        odemeRozeti(s)
                        Text(tl(s.total ?? 0)).font(Yazi.kucukOrta)
                    }
                }
                .padding(.vertical, 3)
                .overlay(alignment: .top) { Divider().overlay(Renk.krem2) }
            }
        }
    }

    @ViewBuilder
    private func odemeRozeti(_ s: Satis) -> some View {
        if s.orderStatus == "preorder" && ["pending", "partial"].contains(s.payment ?? "") { Rozet(metin: "Ön sipariş", tur: .uyari) } else {
        switch s.payment {
        case "pending": Rozet(metin: "Bekliyor", tur: .uyari)
        case "partial": Rozet(metin: "Kısmi", tur: .uyari)
        case "hediye": Rozet(metin: "Hediye", tur: .mor)
        case "zekat": Rozet(metin: "Zekat", tur: .bilgi)
        default: Rozet(metin: "Ödendi", tur: .iyi)
        }
        }
    }

    // MARK: Hediye / zekat

    private func hediyeZekat(baslik: String, simge: String, odeme: String, urunler: [UrunTanimi]) -> some View {
        let kayitlar = depo.sezonda(depo.veri.satislar).filter { $0.payment == odeme }
        let birimler = Dictionary(grouping: kayitlar, by: { $0.unit ?? "" })
            .map { e in miktar(e.value.reduce(0) { $0 + ($1.qty ?? 0) }, e.key) }
            .sorted()
        return HStack(spacing: 10) {
            Image(systemName: simge).font(.system(size: 20)).foregroundStyle(Renk.bal)
                .frame(width: 40, height: 40).background(Renk.bal.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("\(baslik) kayıtları").font(Yazi.kucukOrta)
                Text(kayitlar.isEmpty ? "Bu sezon yok" : "\(kayitlar.count) kayıt · " + birimler.prefix(2).joined(separator: ", "))
                    .font(Yazi.minik).foregroundStyle(Renk.metin2).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 74)
        .background(Renk.krem, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 9, y: 6)
        .foregroundStyle(Renk.metin)
        .accessibilityElement(children: .combine)
    }

    // MARK: Otomatik stok + hareketler

    private var otomatikBilgi: some View {
        HStack(spacing: 12) {
            Image(systemName: "hexagon.fill").font(.system(size: 26)).foregroundStyle(Renk.bal)
                .overlay(Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 11, weight: .bold)).foregroundStyle(Renk.ormanKoyu))
            VStack(alignment: .leading, spacing: 2) {
                Text("Otomatik stok").font(Yazi.kucukOrta).foregroundStyle(Renk.acikBal)
                Text("Hasat ve stok girişleri stoğu artırır; satış, hediye ve zekat kayıtları stoktan kendiliğinden düşer. Ön siparişler teslim edilene dek \"rezerve\" görünür; ürün kartındaki miktar satılabilir stoktur.")
                    .font(Yazi.etiket).foregroundStyle(Color(white: 0.88))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(Renk.ormanKoyu.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Renk.bal.opacity(0.35)))
    }

    private func hareketler(_ urunler: [UrunTanimi]) -> some View {
        // Aktif sezonun hareketleri (bakiye sezon-üstüdür; liste sezona göre). Satıra basınca kaydın kendisi açılır.
        let sezonHareketi = depo.sezonda(depo.veri.stokKayitlari).sorted { ($0.date ?? "") > ($1.date ?? "") }
        let tum = sezonHareketi.filter { k in
            guard hareketUrunu == nil || k.product == hareketUrunu else { return false }
            switch hareketTuru {
            case "giris": return k.action == "in"
            case "cikis": return k.action == "out"
            default: return true
            }
        }
        let son = tumHareketler ? tum : Array(tum.prefix(6))
        let hareketliUrunler = urunler.filter { u in sezonHareketi.contains { $0.product == u.v } }
        return DogaKart {
            HStack {
                BolumBasligi(simge: "arrow.left.arrow.right", baslik: "Stok Hareketleri")
                Spacer()
                Button("Rapor") { rapor = true }.font(Yazi.etiket).foregroundStyle(Renk.orman2)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    suzgecCipi("Girişler \(sezonHareketi.filter { $0.action == "in" }.count)", hareketTuru == "giris") { hareketTuru = "giris"; tumHareketler = false }
                    suzgecCipi("Çıkışlar \(sezonHareketi.filter { $0.action == "out" }.count)", hareketTuru == "cikis") { hareketTuru = "cikis"; tumHareketler = false }
                    suzgecCipi("Tümü \(sezonHareketi.count)", hareketTuru == "tumu") { hareketTuru = "tumu"; tumHareketler = false }
                }
            }
            if hareketliUrunler.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        suzgecCipi("Tüm ürünler", hareketUrunu == nil) { hareketUrunu = nil; tumHareketler = false }
                        ForEach(hareketliUrunler, id: \.v) { u in
                            suzgecCipi(u.temizAd, hareketUrunu == u.v) { hareketUrunu = u.v; tumHareketler = false }
                        }
                    }
                }
            }
            if son.isEmpty {
                Text(sezonHareketi.isEmpty ? "Bu sezon stok hareketi yok." : "Bu süzgeçte hareket yok.").font(Yazi.kucuk).foregroundStyle(Renk.metin3)
            } else {
                Text(hareketTuru == "cikis" ? "Satıştan düşen çıkışa dokununca o satış açılır." : "Düzenlemek için harekete dokun.").font(Yazi.minik).foregroundStyle(Renk.metin3)
            }
            ForEach(son, id: \.id) { k in
                let giris = k.action == "in"
                let ad = urunler.first { $0.v == k.product }?.temizAd ?? (k.product ?? "Ürün")
                HStack(spacing: 8) {
                    Image(systemName: giris ? "arrow.up" : "arrow.down").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(giris ? Renk.iyi : Renk.kotu)
                        .frame(width: 26, height: 26).background((giris ? Renk.iyi : Renk.kotu).opacity(0.14), in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ad + " · " + hareketTuruAdi(k))
                            .font(Yazi.kucukOrta).lineLimit(1)
                        Text([k.date.map { kisaTarih($0) }, k.note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(Yazi.minik).foregroundStyle(Renk.metin3).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text((giris ? "+" : "−") + miktar(k.amount ?? 0, k.unit ?? ""))
                        .font(Yazi.kucukOrta).foregroundStyle(giris ? Renk.iyi : Renk.kotu)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background((giris ? Renk.iyi : Renk.kotu).opacity(0.12), in: Capsule())
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let s = k.saleId { hareketForm = .satis(s) }
                    else if let m = k.milkId { hareketForm = .hasat(m) }
                    else { hareketForm = .giris(k.id) }
                }
            }
            if tum.count > 6 {
                Button(tumHareketler ? "Daha az göster" : "Tümünü göster (\(tum.count))") { tumHareketler.toggle() }
                    .font(Yazi.etiket).foregroundStyle(Renk.orman2).frame(maxWidth: .infinity)
            }
        }
    }

    private func suzgecCipi(_ ad: String, _ secili: Bool, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Text(ad).font(Yazi.etiket).foregroundStyle(secili ? Color.white : Renk.metin)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(secili ? Renk.orman2 : Renk.kart, in: Capsule())
                .overlay(Capsule().strokeBorder(secili ? Renk.orman2 : Renk.krem2))
        }
        .buttonStyle(.plain)
    }

    private func hareketTuruAdi(_ k: StokKaydi) -> String {
        if k.action == "in" { return k.milkId != nil ? "Hasat" : "Giriş" }
        guard k.saleId != nil else { return "Çıkış" }
        let not = k.note ?? ""
        if not.hasPrefix("Hediye:") { return "Hediye" }
        if not.hasPrefix("Zekat:") { return "Zekat" }
        return "Satış"
    }

    // MARK: Gider özeti (bu ay)

    private var giderOzeti: some View {
        let buAy = depo.sezonda(depo.veri.giderler)
        let sezonAdi = depo.veri.sezonlar.first { $0.id == depo.ayarlar.activeSeason }?.name ?? "Sezon"
        let toplam = buAy.reduce(0) { $0 + ($1.amount ?? 0) }
        let turler = Dictionary(grouping: buAy, by: { $0.type ?? "diger" })
            .map { GiderTuru(ad: depo.giderTurAdi($0.key), tutar: $0.value.reduce(0) { $0 + ($1.amount ?? 0) }) }
            .sorted { $0.tutar > $1.tutar }
        return DogaKart {
            HStack {
                BolumBasligi(simge: "doc.text", baslik: "Gider Özeti")
                Spacer()
                Text(sezonAdi).font(Yazi.etiket).foregroundStyle(Renk.metin3)
            }
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sezon gideri").font(Yazi.kucuk).foregroundStyle(Color(white: 0.85))
                    Text(tl(toplam)).font(Yazi.nunito(24, .bold)).foregroundStyle(Renk.bal).lineLimit(1).minimumScaleFactor(0.6)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
                .background(LinearGradient(colors: [Renk.orman2, Renk.ormanKoyu], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    if turler.isEmpty { Text("Bu sezon gider yok.").font(Yazi.kucuk).foregroundStyle(Renk.metin3) }
                    ForEach(turler.prefix(4), id: \.ad) { t in
                        HStack {
                            Text(t.ad).font(Yazi.kucuk).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(tl(t.tutar)).font(Yazi.kucukOrta)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private struct GiderTuru { let ad: String; let tutar: Double }

    private func kapsul(_ ad: String, _ simge: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Label(ad, systemImage: simge).font(Yazi.kucukOrta)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(.white.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(Renk.bal.opacity(0.4)))
                .foregroundStyle(Renk.krem)
        }
        .buttonStyle(.plain)
    }
}

/// Stok girişi (web stock-modal: ürün, miktar, tarih, not, birim fiyat).
enum HareketHedefi: Identifiable {
    case satis(String), hasat(String), giris(String)
    var id: String {
        switch self { case .satis(let i): return "s" + i; case .hasat(let i): return "h" + i; case .giris(let i): return "g" + i }
    }
}

/// Stok girişi (Android ile aynı): ürün kutucukları, büyük miktar + hazır değerler, önce/sonra önizlemesi, altta büyük Kaydet.
/// `kayitId` verilirse o giriş/çıkış kaydını düzenler ya da siler.
struct StokGirisFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    var kayitId: String? = nil
    @State private var silOnay = false
    @State private var urunId = ""
    @State private var miktarDeger: Double = 0
    @State private var tarih = Date()
    @State private var not = ""
    @State private var fiyat: Double = 0

    private var eski: StokKaydi? { kayitId.flatMap { id in depo.veri.stokKayitlari.first { $0.id == id } } }

    var body: some View {
        let urunler = depo.urunler
        let urun = urunler.first { $0.v == urunId }
        let birim = urun?.unit ?? (eski?.unit ?? "")
        let b = Birim(rawValue: birim)
        let cikis = eski?.action == "out"
        let adim: Double = (b == .gr || b == .ml) ? 50 : 1
        let hazir: [Double] = (b == .gr || b == .ml) ? [100, 250, 500, 1000, 2000] : b == .adet ? [1, 5, 10, 20, 50] : [1, 5, 10, 25, 50, 100]
        let mevcut = urunId.isEmpty ? 0 : stokSeviyesi(depo.veri, urun: urunId)
        let eskiEtki: Double = (eski != nil && eski?.product == urunId) ? (cikis ? -(eski?.amount ?? 0) : (eski?.amount ?? 0)) : 0
        let sonra = mevcut - eskiEtki + (cikis ? -miktarDeger : miktarDeger)
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        UrunGorseli(urun: urun, boyut: 72, yaricap: 16).padding(.leading, 14).padding(.top, 6)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(urun?.temizAd ?? "Ürün seç").font(Yazi.nunito(20, .bold)).foregroundStyle(Renk.orman).lineLimit(1)
                            HStack(spacing: 6) {
                                Text(miktar(mevcut, birim)).font(Yazi.nunito(15, .bold)).foregroundStyle(Renk.metin2)
                                if miktarDeger > 0 {
                                    Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold)).foregroundStyle(cikis ? Renk.kotu : Renk.iyi)
                                    Text(miktar(sonra, birim)).font(Yazi.nunito(19, .heavy)).foregroundStyle(cikis ? Renk.kotu : Renk.iyi)
                                }
                            }
                            HStack(spacing: 5) {
                                if miktarDeger > 0 { Rozet(metin: (cikis ? "−" : "+") + miktar(miktarDeger, birim), tur: cikis ? .kotu : .iyi) }
                                if miktarDeger > 0 && fiyat > 0 { Rozet(metin: tl(miktarDeger * fiyat), simge: "turkishlirasign.circle", arkaRenk: Renk.bal.opacity(0.2)) }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 18)
                    .dogaZemini()
                }
                .listeBasligi()
                Section(header: Label("Ürün", systemImage: "archivebox")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                        ForEach(urunler.filter { $0.pasif != true || $0.v == urunId }, id: \.v) { u in
                            urunKutusu(u, secili: urunId == u.v, kilitli: cikis)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section(header: Label("Miktar", systemImage: "plus")) {
                    HStack(spacing: 10) {
                        yuvarlakDugme("minus") { miktarDeger = max(0, miktarDeger - adim) }
                        HStack {
                            TextField("0", value: $miktarDeger, format: .number).keyboardType(.decimalPad).font(Yazi.nunito(20, .bold))
                            Text(birim).font(Yazi.nunito(16, .bold)).foregroundStyle(Renk.bal)
                        }
                        .padding(.horizontal, 14).frame(height: 56)
                        .background(Renk.bal.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Renk.bal.opacity(0.4)))
                        yuvarlakDugme("plus") { miktarDeger += adim }
                    }
                    CipSecici(baslik: nil, secenekler: hazir.map { ($0, miktar($0, birim)) }, secili: hazir.first { $0 == miktarDeger }) { miktarDeger = $0 }
                }
                Section(header: Label("Ayrıntı", systemImage: "doc.text")) {
                    DatePicker("Tarih", selection: $tarih, displayedComponents: .date)
                    CipSecici(baslik: nil, secenekler: [(0, "Bugün"), (1, "Dün"), (2, "2 gün önce")],
                              secili: (0...2).first { Calendar.current.isDate(tarih, inSameDayAs: Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? Date()) }) {
                        tarih = Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? Date()
                    }
                    HStack { Text("Birim fiyat"); TextField("₺", value: $fiyat, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    TextField("Not (ör. Yaz hasadı)", text: $not)
                    if !cikis {
                        CipSecici(baslik: nil, secenekler: ["Hasat", "Yaz hasadı", "Satın alma", "Başlangıç stoğu"].map { ($0, $0) }, secili: not.isEmpty ? nil : not) { not = not == $0 ? "" : $0 }
                    }
                }
                if eski != nil {
                    Section { Button(cikis ? "Çıkışı sil" : "Girişi sil", role: .destructive) { silOnay = true } }
                }
            }
            .navigationTitle(eski == nil ? "Stok Girişi" : (cikis ? "Stok Çıkışı" : "Stok Girişini Düzenle"))
            .confirmationDialog(cikis ? "Stok çıkışı silinsin mi?" : "Stok girişi silinsin mi?", isPresented: $silOnay, titleVisibility: .visible) {
                Button("Sil", role: .destructive) {
                    if let id = kayitId { depo.degistir { v in v.stokKayitlari = v.stokKayitlari.filter { $0.id != id } } }
                    kapat()
                }
            } message: { Text("Stok miktarı buna göre değişir.") }
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { kaydet(birim: birim) }.disabled(urunId.isEmpty || miktarDeger <= 0)
                }
            }
            .safeAreaInset(edge: .bottom) {
                BuyukKaydetCubugu(etkin: !urunId.isEmpty && miktarDeger > 0, ipucu: urunId.isEmpty ? "Önce ürün seç" : "Önce miktar gir") { kaydet(birim: birim) }
            }
            .onAppear {
                if let e = eski {
                    urunId = e.product ?? ""; miktarDeger = e.amount ?? 0; tarih = isoTarih(e.date) ?? Date(); not = e.note ?? ""
                }
                if urunId.isEmpty { urunId = urunler.first { $0.pasif != true }?.v ?? urunler.first?.v ?? "" }
                fiyat = depo.ayarlar.stockPrices[urunId] ?? 0
            }
        }
    }

    private func kaydet(birim: String) {
        guard !urunId.isEmpty, miktarDeger > 0 else { return }
        let onceki = eski
        let id = urunId, m = miktarDeger, t = bugunISO(tarih), n = not
        depo.degistir { v in
            var k = onceki ?? StokKaydi(["id": .metin(yeniKimlik())])
            k.product = id; k.action = onceki?.action ?? "in"; k.amount = m; k.unit = birim; k.date = t; k.note = n
            if onceki == nil { v.stokKayitlari = v.stokKayitlari + [k] }
            else { v.stokKayitlari = v.stokKayitlari.map { $0.id == k.id ? k : $0 } }
        }
        if fiyat > 0 { depo.ayarDegistir { a in var p = a.stockPrices; p[id] = fiyat; a.stockPrices = p } }
        kapat()
    }

    private func urunKutusu(_ u: UrunTanimi, secili: Bool, kilitli: Bool) -> some View {
        let stok = stokSeviyesi(depo.veri, urun: u.v)
        let sekil = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            if urunId != u.v { urunId = u.v; fiyat = depo.ayarlar.stockPrices[u.v] ?? 0; miktarDeger = 0 }
        } label: {
            VStack(spacing: 2) {
                UrunGorseli(urun: u, boyut: 48, yaricap: 12)
                Text(u.temizAd).font(Yazi.nunito(12, .bold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(miktar(stok, u.unit)).font(Yazi.nunito(10)).foregroundStyle(stok <= 0 ? Renk.metin3 : Renk.metin2).lineLimit(1)
            }
            .padding(.top, 8).padding(.bottom, 7).padding(.horizontal, 4).frame(maxWidth: .infinity)
            .background(secili ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.96, blue: 0.84), Color(red: 1, green: 0.9, blue: 0.66)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Renk.kart), in: sekil)
            .overlay(sekil.strokeBorder(secili ? Renk.bal : Renk.krem2, lineWidth: secili ? 2 : 1))
            .overlay(alignment: .topTrailing) {
                if secili {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 18, height: 18).background(Renk.orman2, in: Circle()).padding(4)
                }
            }
            .foregroundStyle(Renk.metin)
        }
        .buttonStyle(.plain)
        .disabled(kilitli && !secili)
    }

    private func yuvarlakDugme(_ simge: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Image(systemName: simge).font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(LinearGradient(colors: [Renk.orman2, Renk.orman], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Zekat (Bal Defterim kuralı): aktif sezonda girilen hasadın %10'u (öşür). Devreden/başlangıç stoğu dahil edilmez;
/// "Zekat" ödemesiyle girilen satışlar verilen sayılıp düşülür. Ürün formunda "Zekat hesabına dahil" kapalıysa gösterilmez.
private struct ZekatSatiri: Identifiable {
    let u: UrunTanimi
    let z: ZekatDurumu
    var id: String { u.v }
}

struct ZekatSayfasi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    @State private var zekatVer = false
    var body: some View {
        let aralik = depo.aktifAralik
        let satirlar = depo.urunler.filter { $0.zakat != false }.compactMap { u -> ZekatSatiri? in
            guard let b = Birim(rawValue: u.unit) else { return nil }
            let z = zekatDurumu(depo.veri, urun: u.v, urunBirimi: b, aralik: aralik)
            return z.hasat > 0 || z.verilen > 0 ? ZekatSatiri(u: u, z: z) : nil
        }
        // Birim başına toplam (kg, lt, adet… ayrı toplanır)
        let birimler = Dictionary(grouping: satirlar, by: { $0.u.unit }).sorted { $0.key < $1.key }
        let kalanlar = birimler.compactMap { b, l -> String? in
            let t = l.reduce(0) { $0 + $1.z.kalan }
            return t > 0 ? miktar(t, b) : nil
        }
        let verilenler = birimler.compactMap { b, l -> String? in
            let t = l.reduce(0) { $0 + $1.z.verilen }
            return t > 0 ? miktar(t, b) : nil
        }
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ustKart(kalanlar: kalanlar, verilenler: verilenler, bos: satirlar.isEmpty)
                    ForEach(satirlar) { urunKarti($0) }
                    bilgiKarti
                }
                .padding(.horizontal, Olcu.kenar).padding(.vertical, 8)
            }
            .navigationTitle("Zekat")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } } }
            .safeAreaInset(edge: .bottom) {
                BuyukKaydetCubugu(metin: "Zekat verdim, kaydet") { zekatVer = true }
            }
            .sheet(isPresented: $zekatVer) { SatisFormu(satisId: nil, varsayilanOdeme: "zekat") }
        }
    }

    private let renkZekat = Color(red: 0.18, green: 0.55, blue: 0.55)

    /// Koyu yeşil üst kart: bu sezon verilecek toplam ya da "tamamı verildi".
    private func ustKart(kalanlar: [String], verilenler: [String], bos: Bool) -> some View {
        let tamam = !bos && kalanlar.isEmpty
        return HStack(spacing: 14) {
            Image(systemName: tamam ? "checkmark.seal.fill" : "moon.stars.fill")
                .font(.system(size: 28, weight: .semibold)).foregroundStyle(Renk.ormanKoyu)
                .frame(width: 60, height: 60)
                .background(LinearGradient(colors: [Renk.acikBal, Renk.bal], startPoint: .top, endPoint: .bottom), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1.5))
                .shadow(color: Renk.bal.opacity(0.5), radius: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(bos ? "Bu sezon" : tamam ? "Bu sezonun zekatı" : "Bu sezon verilecek zekat")
                    .font(Yazi.kucuk).foregroundStyle(Color(white: 0.85))
                Text(bos ? "Hasat girişi yok" : tamam ? "Tamamı verildi" : kalanlar.joined(separator: " · "))
                    .font(Yazi.nunito(24, .heavy)).foregroundStyle(tamam ? Renk.acikBal : Renk.bal)
                    .lineLimit(2).minimumScaleFactor(0.6)
                Text(verilenler.isEmpty ? "Sezon hasadının %10'u (öşür)" : "Verilen: " + verilenler.joined(separator: " · "))
                    .font(Yazi.minik).foregroundStyle(Color(white: 0.8)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(LinearGradient(colors: [Renk.orman2, Renk.ormanKoyu], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Renk.bal.opacity(0.5)))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
        .accessibilityElement(children: .combine)
    }

    /// Ürün kartı: hasat, %10 borç, verilen; ilerleme çubuğu verilen/borç.
    private func urunKarti(_ s: ZekatSatiri) -> some View {
        let u = s.u, z = s.z
        let oran = z.borc > 0 ? min(1, z.verilen / z.borc) : 1
        return DogaKart {
            HStack(spacing: 12) {
                UrunGorseli(urun: u, boyut: 56, yaricap: 14).padding(.leading, 12).padding(.top, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(u.temizAd).font(Yazi.nunito(18, .bold)).foregroundStyle(Renk.metin).lineLimit(1)
                    Text("Sezon hasadı \(miktar(z.hasat, u.unit))").font(Yazi.kucuk).foregroundStyle(Renk.metin2).lineLimit(1)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 1) {
                    if z.kalan > 0 {
                        Text(miktar(z.kalan, u.unit)).font(Yazi.nunito(20, .heavy)).foregroundStyle(Renk.orman)
                        Text("verilecek").font(Yazi.minik).foregroundStyle(Renk.metin3)
                    } else {
                        Label("Verildi", systemImage: "checkmark.circle.fill").font(Yazi.nunito(16, .heavy)).foregroundStyle(Renk.iyi)
                        Text("tamamı").font(Yazi.minik).foregroundStyle(Renk.metin3)
                    }
                }
            }
            GeometryReader { g in
                Capsule().fill(z.kalan > 0 ? renkZekat : Renk.iyi).frame(width: max(oran > 0 ? 14 : 0, g.size.width * oran))
            }
            .frame(height: 12)
            .background(Renk.krem2)
            .clipShape(Capsule())
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3).fill(Renk.krem2).frame(width: 9, height: 9)
                Text("Zekat (%10)").font(Yazi.kucuk).foregroundStyle(Renk.metin2)
                Spacer()
                Text(miktar(z.borc, u.unit)).font(Yazi.kucukOrta).foregroundStyle(Renk.metin)
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3).fill(z.kalan > 0 ? renkZekat : Renk.iyi).frame(width: 9, height: 9)
                Text("Verilen").font(Yazi.kucuk).foregroundStyle(Renk.metin2)
                Spacer()
                Text(miktar(z.verilen, u.unit)).font(Yazi.kucukOrta).foregroundStyle(Renk.metin)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var bilgiKarti: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill").font(.system(size: 18)).foregroundStyle(Renk.bal)
            Text("Zekat, sezonda girilen hasadın %10'udur (öşür). Önceki sezondan devreden ve başlangıç stoğu dahil edilmez. Verdiğin zekatı alttaki düğmeyle kaydet: ödeme türü \"Zekat\" olan bir satış açılır, stoktan düşer ve burada verilen olarak görünür.")
                .font(Yazi.kucuk).foregroundStyle(Renk.metin2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Renk.kart.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Renk.krem2))
    }
}

/// Stok raporu (Android ile aynı): üstte değer/satış özeti; ürün başına giriş nereye gitti
/// (satış · hediye · zekat · rezerve · elde) çubuğu. Karta dokununca ürünün stok sayfası.
struct StokRaporuSayfasi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    @State private var acikUrun: KimlikKutusu?
    private let renkSatis = Renk.bilgi
    private let renkHediye = Renk.mor
    private let renkZekat = Color(red: 0.18, green: 0.55, blue: 0.55)
    private let renkRezerve = Renk.uyari
    private let renkElde = Renk.iyi

    var body: some View {
        let urunler = depo.urunler
        let satirlar = stokRaporu(depo.veri, urunler: urunler)
        let deger = satirlar.reduce(0.0) { $0 + max(0, $1.mevcut) * (depo.ayarlar.stockPrices[$1.urun] ?? 0) }
        let ciro = satirlar.reduce(0.0) { $0 + $1.satisTutar }
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        ozet("Eldeki stok değeri", tl(deger), "\(satirlar.filter { $0.mevcut > 0 }.count) üründe stok", koyu: true)
                        ozet("Toplam satış", tl(ciro), "Tüm sezonlar", koyu: false)
                    }
                    AkisDuzeni(aralik: 12) {
                        ForEach([(renkSatis, "Satış"), (renkHediye, "Hediye"), (renkZekat, "Zekat"), (renkRezerve, "Rezerve"), (renkElde, "Elde")], id: \.1) { r, a in
                            HStack(spacing: 5) { RoundedRectangle(cornerRadius: 3).fill(r).frame(width: 10, height: 10); Text(a).font(Yazi.etiket).foregroundStyle(Renk.metin2) }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Renk.kart.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    if satirlar.isEmpty {
                        Text("Henüz stok girişi yok. Hasat ya da stok girişi ekleyince rapor burada oluşur.")
                            .font(Yazi.govde).foregroundStyle(Renk.metin3).padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Renk.kart, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    ForEach(satirlar, id: \.urun) { r in
                        Button { acikUrun = KimlikKutusu(id: r.urun) } label: { urunKarti(r, urunler.first { $0.v == r.urun }) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Olcu.kenar).padding(.vertical, 8)
            }
            .navigationTitle("Stok Raporu")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } }
                ToolbarItem(placement: .topBarLeading) { RaporPaylasDugmesi() }
            }
            .sheet(item: $acikUrun) { UrunStokSayfasi(urunId: $0.id) }
        }
    }

    private func ozet(_ baslik: String, _ d: String, _ alt: String, koyu: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(baslik).font(Yazi.kucuk).foregroundStyle(koyu ? Color(white: 0.85) : Renk.metin2)
            Text(d).font(Yazi.nunito(23, .heavy)).foregroundStyle(koyu ? Renk.bal : Renk.orman).lineLimit(1).minimumScaleFactor(0.7)
            Text(alt).font(Yazi.minik).foregroundStyle(koyu ? Color(white: 0.8) : Renk.metin3).lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(koyu ? AnyShapeStyle(LinearGradient(colors: [Renk.orman2, Renk.ormanKoyu], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Renk.kart),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(koyu ? Renk.bal.opacity(0.5) : Renk.krem2))
    }

    private func urunKarti(_ r: UrunRaporSatiri, _ u: UrunTanimi?) -> some View {
        let b = u?.unit ?? ""
        let rz = rezerveMiktar(depo.veri, urun: r.urun, urunBirimi: Birim(rawValue: b))
        let fiyat = depo.ayarlar.stockPrices[r.urun] ?? 0
        let elde = max(0, r.mevcut - rz)
        let parcalar = [(r.satisMiktar, renkSatis), (r.hediye, renkHediye), (r.zekat, renkZekat), (rz, renkRezerve), (elde, renkElde)].filter { $0.0 > 0 }
        let toplam = max(r.giris, parcalar.reduce(0) { $0 + $1.0 }, 0.0001)
        return DogaKart {
            HStack(spacing: 12) {
                UrunGorseli(urun: u, boyut: 56, yaricap: 14).padding(.leading, 12).padding(.top, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(u?.temizAd ?? r.urun).font(Yazi.nunito(18, .bold)).foregroundStyle(Renk.metin).lineLimit(1)
                    Text("Toplam giriş \(miktar(r.giris, b))").font(Yazi.kucuk).foregroundStyle(Renk.metin2).lineLimit(1)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(miktar(r.mevcut, b)).font(Yazi.nunito(20, .heavy)).foregroundStyle(r.mevcut <= 0 ? Renk.metin3 : Renk.orman)
                    Text(fiyat > 0 && r.mevcut > 0 ? tl(r.mevcut * fiyat) : rz > 0 ? "satılabilir" : "mevcut").font(Yazi.minik).foregroundStyle(Renk.metin3)
                }
            }
            GeometryReader { g in
                HStack(spacing: 0) {
                    ForEach(Array(parcalar.enumerated()), id: \.offset) { _, p in
                        Rectangle().fill(p.1).frame(width: g.size.width * CGFloat(p.0 / toplam))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 14)
            .background(Renk.krem2)
            .clipShape(Capsule())
            if r.satisMiktar > 0 { satir(renkSatis, "Satış", miktar(r.satisMiktar, b), ek: tl(r.satisTutar)) }
            if r.hediye > 0 { satir(renkHediye, "Hediye", miktar(r.hediye, b)) }
            if r.zekat > 0 { satir(renkZekat, "Zekat", miktar(r.zekat, b)) }
            if rz > 0 { satir(renkRezerve, "Rezerve (ön sipariş)", miktar(rz, b)) }
            satir(renkElde, rz > 0 ? "Satılabilir" : "Elde", miktar(rz > 0 ? elde : r.mevcut, b))
        }
    }

    private func satir(_ r: Color, _ a: String, _ d: String, ek: String? = nil) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(r).frame(width: 9, height: 9)
            Text(a).font(Yazi.kucuk).foregroundStyle(Renk.metin2)
            Spacer()
            if let ek { Text(ek).font(Yazi.kucuk).foregroundStyle(Renk.metin3) }
            Text(d).font(Yazi.kucukOrta).foregroundStyle(Renk.metin)
        }
        .padding(.vertical, 2)
    }
}
