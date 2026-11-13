import AriCekirdek
import SwiftUI

/// Satış › Stok: ürün kartları (kendi biriminde), ürün ekle (20 sınırı), stok girişi, zekat, rapor.
struct StokGorunumu: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var urunForm: KimlikKutusu?
    @State private var yeniUrun = false
    @State private var giris = false
    @State private var zekat = false
    @State private var rapor = false

    var body: some View {
        let urunler = depo.urunler
        let eklenebilir = urunEklenebilir(depo.ayarlar)
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                kapsul("Stok girişi", "plus") { giris = true }
                kapsul("Zekat", "moon.stars") { zekat = true }
                kapsul("Rapor", "chart.bar") { rapor = true }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(urunler, id: \.v) { u in
                    Button { urunForm = KimlikKutusu(id: u.v) } label: { kart(u) }.buttonStyle(.plain)
                }
                Button { yeniUrun = true } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 30, weight: .medium))
                        Text("Ürün ekle").font(Yazi.govdeOrta)
                        Text(eklenebilir ? "kg · lt · gr · adet" : "En fazla \(ozelUrunSiniri) ürün").font(Yazi.etiket).opacity(0.8)
                    }
                    .foregroundStyle(Renk.bal)
                    .frame(maxWidth: .infinity, minHeight: 190)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Renk.bal.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
                }
                .buttonStyle(.plain)
                .disabled(!eklenebilir)
                .opacity(eklenebilir ? 1 : 0.5)
            }
        }
        .sheet(item: $urunForm) { UrunFormu(urunId: $0.id) }
        .sheet(isPresented: $yeniUrun) { UrunFormu(urunId: nil) }
        .sheet(isPresented: $giris) { StokGirisFormu() }
        .sheet(isPresented: $zekat) { ZekatSayfasi() }
        .sheet(isPresented: $rapor) { StokRaporuSayfasi() }
    }

    private func kart(_ u: UrunTanimi) -> some View {
        let mevcut = stokSeviyesi(depo.veri, urun: u.v)
        return VStack(alignment: .leading, spacing: 4) {
            UrunGorseli(urun: u, boyut: 150, yaricap: 14)
                .frame(maxWidth: .infinity).frame(height: 110).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            HStack(spacing: 4) {
                Text(u.temizAd).font(Yazi.govdeOrta).lineLimit(1)
                if u.unit == "lt" || u.unit == "ml" { Rozet(metin: u.unit.uppercased(), tur: .bilgi) }
            }
            Text(miktar(mevcut, u.unit)).font(Yazi.nunito(21, .bold)).foregroundStyle(mevcut <= 0 ? Renk.metin3 : Renk.metin)
            if let f = depo.ayarlar.stockPrices[u.v], f > 0 { Text("\(tl(f)) / \(u.unit)").font(Yazi.etiket).foregroundStyle(Renk.metin3) }
        }
        .padding(10)
        .background(Renk.krem, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 9, y: 6)
        .foregroundStyle(Renk.metin)
        .accessibilityElement(children: .combine)
    }

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
                Picker("Ürün", selection: $urunId) { ForEach(urunler, id: \.v) { Text($0.temizAd).tag($0.v) } }
                HStack { TextField("Miktar", value: $miktarDeger, format: .number).keyboardType(.decimalPad); Text(birim).foregroundStyle(.secondary) }
                DatePicker("Tarih", selection: $tarih, displayedComponents: .date)
                HStack { Text("Birim fiyat"); TextField("₺", value: $fiyat, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                TextField("Not (ör. Yaz hasadı)", text: $not)
            }
            .navigationTitle("Stok Girişi")
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

/// Zekat: her ürünün mevcut stoğunun %10'u (web showZekatModal).
struct ZekatSayfasi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    var body: some View {
        NavigationStack {
            List {
                Section(footer: Text("Zekat, ürünün güncel stoğunun %10'u olarak hesaplanır.")) {
                    ForEach(depo.urunler, id: \.v) { u in
                        let m = stokSeviyesi(depo.veri, urun: u.v)
                        if m > 0 {
                            HStack {
                                UrunGorseli(urun: u, boyut: 36, yaricap: 9)
                                VStack(alignment: .leading) { Text(u.temizAd); Text("Mevcut \(miktar(m, u.unit))").font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                Text(miktar(zekatMiktari(m), u.unit)).font(.headline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Zekat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } } }
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
                        satir("Satış", "\(miktar(r.satisMiktar, b)) · \(tl(r.satisTutar))")
                        if r.hediye > 0 { satir("Hediye", miktar(r.hediye, b)) }
                        if r.zekat > 0 { satir("Zekat", miktar(r.zekat, b)) }
                        satir("Mevcut", miktar(r.mevcut, b)).bold()
                    } header: {
                        HStack { UrunGorseli(urun: u, boyut: 24, yaricap: 6); Text(u?.temizAd ?? r.urun) }
                    }
                }
            }
            .navigationTitle("Stok Raporu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } } }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } } }
        }
    }
}
