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
    @State private var rapor = false

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
                hediyeZekat(baslik: "Hediye", simge: "gift", odeme: "hediye", urunler: urunler)
                hediyeZekat(baslik: "Zekat", simge: "moon.stars", odeme: "zekat", urunler: urunler)
            }
            otomatikBilgi
            hareketler(urunler)
        }
        .sheet(item: $urunForm) { UrunFormu(urunId: $0.id) }
        .sheet(isPresented: $yeniUrun) { UrunFormu(urunId: nil) }
        .sheet(isPresented: $giris) { StokGirisFormu() }
        .sheet(isPresented: $zekat) { ZekatSayfasi() }
        .sheet(isPresented: $rapor) { StokRaporuSayfasi() }
    }

    // MARK: Ürün stok özeti

    private func urunOzeti(_ urunler: [UrunTanimi]) -> some View {
        let toplam = urunler.reduce(0) { $0 + max(0, stokSeviyesi(depo.veri, urun: $1.v)) * (depo.ayarlar.stockPrices[$1.v] ?? 0) }
        let eklenebilir = urunEklenebilir(depo.ayarlar)
        return Kart {
            HStack {
                Image(systemName: "shippingbox.fill").foregroundStyle(Renk.bal)
                Text("Ürün Stok Özeti").font(Yazi.kartBaslik)
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
                        Button { urunForm = KimlikKutusu(id: u.v) } label: { urunKutusu(u, stokSeviyesi(depo.veri, urun: u.v)) }.buttonStyle(.plain)
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
        return Kart {
            HStack {
                Image(systemName: "cart").foregroundStyle(Renk.orman2)
                Text("Son Satışlar").font(Yazi.kartBaslik)
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
        switch s.payment {
        case "pending": Rozet(metin: "Bekliyor", tur: .uyari)
        case "partial": Rozet(metin: "Kısmi", tur: .uyari)
        case "hediye": Rozet(metin: "Hediye", tur: .mor)
        case "zekat": Rozet(metin: "Zekat", tur: .bilgi)
        default: Rozet(metin: "Ödendi", tur: .iyi)
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
        let son = depo.veri.stokKayitlari.sorted { ($0.date ?? "") > ($1.date ?? "") }.prefix(6)
        return Kart {
            HStack {
                Image(systemName: "arrow.left.arrow.right").foregroundStyle(Renk.orman2)
                Text("Stok Hareketleri").font(Yazi.kartBaslik)
                Spacer()
                Button("Rapor") { rapor = true }.font(Yazi.etiket).foregroundStyle(Renk.orman2)
            }
            if son.isEmpty { Text("Henüz stok hareketi yok.").font(Yazi.kucuk).foregroundStyle(Renk.metin3) }
            ForEach(Array(son), id: \.id) { k in
                let giris = k.action == "in"
                let ad = urunler.first { $0.v == k.product }?.temizAd ?? (k.product ?? "Ürün")
                HStack(spacing: 8) {
                    Image(systemName: giris ? "arrow.up" : "arrow.down").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(giris ? Renk.iyi : Renk.kotu)
                        .frame(width: 26, height: 26).background((giris ? Renk.iyi : Renk.kotu).opacity(0.14), in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ad + " · " + (giris ? (k.milkId != nil ? "Hasat" : "Giriş") : (k.saleId != nil ? "Satış" : "Çıkış")))
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
            }
        }
    }

    // MARK: Gider özeti (bu ay)

    private var giderOzeti: some View {
        let buAy = depo.sezonda(depo.veri.giderler)
        let sezonAdi = depo.veri.sezonlar.first { $0.id == depo.ayarlar.activeSeason }?.name ?? "Sezon"
        let toplam = buAy.reduce(0) { $0 + ($1.amount ?? 0) }
        let turler = Dictionary(grouping: buAy, by: { $0.type ?? "diger" })
            .map { GiderTuru(ad: depo.giderTurAdi($0.key), tutar: $0.value.reduce(0) { $0 + ($1.amount ?? 0) }) }
            .sorted { $0.tutar > $1.tutar }
        return Kart {
            HStack {
                Image(systemName: "doc.text").foregroundStyle(Renk.orman2)
                Text("Gider Özeti").font(Yazi.kartBaslik)
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
struct StokGirisFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    @State private var urunId = ""
    @State private var miktarDeger: Double = 0
    @State private var tarih = Date()
    @State private var not = ""
    @State private var fiyat: Double = 0

    var body: some View {
        let urunler = depo.urunler
        let birim = urunler.first { $0.v == urunId }?.unit ?? ""
        NavigationStack {
            Form {
                Picker("Ürün", selection: $urunId) { ForEach(urunler.filter { $0.pasif != true || $0.v == urunId }, id: \.v) { Text($0.temizAd).tag($0.v) } }
                HStack { TextField("Miktar", value: $miktarDeger, format: .number).keyboardType(.decimalPad); Text(birim).foregroundStyle(.secondary) }
                DatePicker("Tarih", selection: $tarih, displayedComponents: .date)
                HStack { Text("Birim fiyat"); TextField("₺", value: $fiyat, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                TextField("Not (ör. Yaz hasadı)", text: $not)
            }
            .navigationTitle("Stok Girişi")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        depo.degistir { v in
                            var k = StokKaydi(["id": .metin(yeniKimlik())])
                            k.product = urunId; k.action = "in"; k.amount = miktarDeger; k.unit = birim; k.date = bugunISO(tarih); k.note = not
                            v.stokKayitlari = v.stokKayitlari + [k]
                        }
                        if fiyat > 0 { depo.ayarDegistir { a in var p = a.stockPrices; p[urunId] = fiyat; a.stockPrices = p } }
                        kapat()
                    }
                    .disabled(urunId.isEmpty || miktarDeger <= 0)
                }
            }
            .onAppear {
                if urunId.isEmpty { urunId = urunler.first?.v ?? "" }
                fiyat = depo.ayarlar.stockPrices[urunId] ?? 0
            }
        }
        .presentationDetents([.medium, .large])
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
        NavigationStack {
            List {
                if satirlar.isEmpty {
                    Text("Bu sezon zekata tabi hasat girişi yok.").foregroundStyle(.secondary)
                }
                ForEach(satirlar) { satir in
                    let u = satir.u, z = satir.z
                    Section {
                        HStack {
                            UrunGorseli(urun: u, boyut: 40, yaricap: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(u.temizAd).font(Yazi.govdeOrta)
                                Text("Sezon hasadı \(miktar(z.hasat, u.unit))").font(Yazi.etiket).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(z.kalan > 0 ? miktar(z.kalan, u.unit) : "Verildi ✓").font(Yazi.nunito(18, .bold))
                                    .foregroundStyle(z.kalan > 0 ? Renk.metin : Renk.iyi)
                                Text(z.kalan > 0 ? "verilecek" : "tamamı").font(Yazi.minik).foregroundStyle(.secondary)
                            }
                        }
                        HStack {
                            Text("Zekat (%10) \(miktar(z.borc, u.unit))")
                            Spacer()
                            Text("Verilen \(miktar(z.verilen, u.unit))").foregroundStyle(Renk.iyi)
                        }
                        .font(Yazi.kucuk)
                    }
                }
                Section {
                    Button { zekatVer = true } label: { Label("Zekat verdim, kaydet", systemImage: "moon.stars") }
                } footer: {
                    Text("Zekat, sezonda girilen hasadın %10'udur (öşür). Önceki sezondan devreden ve başlangıç stoğu dahil edilmez. Verdiğin zekatı ödeme türü \"Zekat\" olan bir satış olarak kaydet; stoktan düşer, burada verilen olarak görünür.")
                }
            }
            .navigationTitle("Zekat")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } } }
            .sheet(isPresented: $zekatVer) { SatisFormu(satisId: nil, varsayilanOdeme: "zekat") }
        }
    }
}

struct StokRaporuSayfasi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    var body: some View {
        let urunler = depo.urunler
        NavigationStack {
            List {
                ForEach(stokRaporu(depo.veri, urunler: urunler), id: \.urun) { r in
                    let u = urunler.first { $0.v == r.urun }
                    let b = u?.unit ?? ""
                    Section {
                        satir("Toplam giriş", miktar(r.giris, b))
                        let rz = rezerveMiktar(depo.veri, urun: r.urun, urunBirimi: Birim(rawValue: b))
                        satir("Satış", "\(miktar(r.satisMiktar, b)) · \(tl(r.satisTutar))")
                        if r.hediye > 0 { satir("Hediye", miktar(r.hediye, b)) }
                        if r.zekat > 0 { satir("Zekat", miktar(r.zekat, b)) }
                        if rz > 0 { satir("Rezerve (ön sipariş)", miktar(rz, b)) }
                        satir(rz > 0 ? "Satılabilir" : "Mevcut", miktar(r.mevcut, b)).bold()
                    } header: {
                        HStack { UrunGorseli(urun: u, boyut: 24, yaricap: 6); Text(u?.temizAd ?? r.urun) }
                    }
                }
            }
            .navigationTitle("Stok Raporu")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } }
                ToolbarItem(placement: .topBarLeading) { RaporPaylasDugmesi() }
            }
        }
    }
    private func satir(_ a: String, _ b: String) -> some View { HStack { Text(a); Spacer(); Text(b).foregroundStyle(.secondary) } }
}

struct SatisRaporuSayfasi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    var body: some View {
        let satislar = depo.sezonda(depo.veri.satislar)
        let urunler = depo.urunler
        let bekleyen = musteriKartlari(satislar).filter { $0.kalanTutar > 0 }
        NavigationStack {
            List {
                Section {
                    HStack { Text("Toplam gelir"); Spacer(); Text(tl(satislar.reduce(0) { $0 + ($1.total ?? 0) })).bold() }
                    HStack { Text("Bekleyen"); Spacer(); Text(tl(bekleyenToplam(satislar: satislar))).foregroundStyle(Renk.kotu) }
                }
                Section("Ürünlere göre") {
                    ForEach(satisRaporu(satislar), id: \.anahtar) { g in
                        let ad = g.anahtar.hasPrefix("urun_") ? (urunler.first { $0.v == String(g.anahtar.dropFirst(5)) }?.temizAd ?? String(g.anahtar.dropFirst(5)))
                            : ["tur_queen": "Ana Arı", "tur_bee": "Arı Satışı", "tur_milk": "Arı Sütü"][g.anahtar] ?? "Diğer"
                        VStack(alignment: .leading, spacing: 3) {
                            HStack { Text(ad).bold(); Spacer(); Text(tl(g.satisTl)) }
                            Text("\(miktar(g.satis, g.unit ?? "")) satış · \(g.satisAdet) kayıt" + (g.hediye > 0 ? " · \(miktar(g.hediye, g.unit ?? "")) hediye" : "") + (g.zekat > 0 ? " · \(miktar(g.zekat, g.unit ?? "")) zekat" : ""))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if !bekleyen.isEmpty {
                    Section("Bekleyen ödemeler") {
                        ForEach(bekleyen) { k in HStack { Text(k.musteri); Spacer(); Text(tl(k.kalanTutar)).foregroundStyle(Renk.kotu) } }
                    }
                }
            }
            .navigationTitle("Satış Raporu")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } }
                ToolbarItem(placement: .topBarLeading) { RaporPaylasDugmesi() }
            }
        }
    }
}
