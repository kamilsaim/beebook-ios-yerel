import AriCekirdek
import SwiftUI

/// Satış formundaki bir ürün kalemi.
struct SatisKalemi: Identifiable, Equatable {
    let id = UUID()
    var urunId: String
    var birim: Birim
    var miktar: Double
    var fiyat: Double
    var toplamElle: Double?
}

/// Yeni satış (çok ürünlü, aynı batchId) ya da tek satır düzenleme (web saveSale).
struct SatisFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let satisId: String?

    @State private var musteri = ""
    @State private var telefon = ""
    @State private var tarih = Date()
    @State private var kalemler: [SatisKalemi] = []
    @State private var odeme = "paid"
    @State private var odenen = ""
    @State private var onSiparis = false
    @State private var not = ""
    @State private var yuklendi = false

    private var urunler: [UrunTanimi] { depo.urunler }
    private var ucretsiz: Bool { odeme == "hediye" || odeme == "zekat" }

    var body: some View {
        NavigationStack {
            Form {
                Section("Müşteri") {
                    TextField("Ad", text: $musteri).textInputAutocapitalization(.words)
                    if !oneriler.isEmpty {
                        ScrollView(.horizontal) {
                            HStack { ForEach(oneriler, id: \.self) { o in Button(o) { musteriSec(o) }.buttonStyle(.bordered).tint(Renk.orman2) } }
                        }
                        .scrollIndicators(.hidden)
                    }
                    TextField("Telefon (isteğe bağlı)", text: $telefon).keyboardType(.phonePad)
                    DatePicker("Tarih", selection: $tarih, displayedComponents: .date)
                }
                ForEach($kalemler) { $k in
                    Section(kalemler.count > 1 ? "Ürün \((kalemler.firstIndex(of: k) ?? 0) + 1)" : "Ürün") {
                        KalemDuzenleyici(kalem: $k, urunler: urunler, ucretsiz: ucretsiz)
                        if kalemler.count > 1 {
                            Button("Bu ürünü çıkar", role: .destructive) { kalemler.removeAll { $0.id == k.id } }
                        }
                    }
                }
                if satisId == nil {
                    Section { Button { kalemEkle() } label: { Label("Başka ürün ekle", systemImage: "plus.circle") } }
                }
                Section("Ödeme") {
                    Picker("Ödeme", selection: $odeme) {
                        Text("Ödendi").tag("paid"); Text("Bekliyor").tag("pending"); Text("Kısmi").tag("partial")
                        Text("Hediye").tag("hediye"); Text("Zekat").tag("zekat")
                    }
                    .pickerStyle(.menu)
                    if odeme == "partial" { TextField("Ödenen tutar (₺)", text: $odenen).keyboardType(.decimalPad) }
                    Toggle("Ön sipariş (teslim edilmedi)", isOn: $onSiparis)
                    TextField("Not", text: $not, axis: .vertical)
                }
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Toplam").font(Yazi.etiket).foregroundStyle(.secondary)
                            Text(kalemler.map { miktar($0.miktar, $0.birim.rawValue) + " " + ad($0.urunId) }.joined(separator: " + "))
                                .font(Yazi.kucuk).lineLimit(2)
                        }
                        Spacer()
                        Text(tl(genelToplam)).font(Yazi.nunito(24, .bold)).foregroundStyle(Renk.bal)
                    }
                }
                .listRowBackground(Renk.orman)
            }
            .navigationTitle(satisId == nil ? "Yeni Satış" : "Satışı Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { kaydet(); kapat() }
                        .disabled(kalemler.isEmpty || kalemler.contains { $0.miktar <= 0 } || (!ucretsiz && kalemler.contains { tutar($0) <= 0 }))
                }
            }
            .onAppear(perform: yukle)
        }
    }

    // MARK: Hesap

    private func tutar(_ k: SatisKalemi) -> Double { ucretsiz ? 0 : (k.toplamElle ?? k.miktar * k.fiyat) }
    private var genelToplam: Double { kalemler.reduce(0) { $0 + tutar($1) } }
    private func ad(_ id: String) -> String { urunler.first { $0.v == id }?.temizAd ?? id }

    private var oneriler: [String] {
        let a = musteri.trimmingCharacters(in: .whitespaces).lowercased()
        let tum = Array(Set(depo.veri.satislar.compactMap(\.customer).filter { !$0.isEmpty }))
        return tum.filter { a.isEmpty || ($0.lowercased().contains(a) && $0.lowercased() != a) }.sorted().prefix(6).map { $0 }
    }

    private func musteriSec(_ ad: String) {
        musteri = ad
        if telefon.isEmpty, let t = depo.veri.satislar.first(where: { $0.customer == ad && ($0.phone?.isEmpty == false) })?.phone { telefon = t }
    }

    private func kalemEkle() {
        guard let u = urunler.first else { return }
        let b = Birim(rawValue: u.unit) ?? .kg
        kalemler.append(SatisKalemi(urunId: u.v, birim: b, miktar: b == .gr || b == .ml ? 100 : 1, fiyat: depo.ayarlar.stockPrices[u.v] ?? 0))
    }

    // MARK: Yükle / kaydet

    private func yukle() {
        guard !yuklendi else { return }
        yuklendi = true
        if let s = depo.veri.satislar.first(where: { $0.id == satisId }) {
            musteri = s.customer ?? ""; telefon = s.phone ?? ""; tarih = isoTarih(s.date) ?? Date()
            odeme = s.payment ?? "paid"; odenen = s.paidAmount.map { String($0) } ?? ""
            onSiparis = s.orderStatus == "preorder"; not = s.note ?? ""
            let uid = satisStokUrunu(s) ?? (s.type ?? "other")
            let qty = s.qty ?? 0, fiyat = s.price ?? 0
            let elle = abs((s.total ?? 0) - qty * fiyat) > 0.009 && (s.total ?? 0) > 0 ? s.total : nil
            kalemler = [SatisKalemi(urunId: uid, birim: Birim(rawValue: s.unit ?? "") ?? .kg, miktar: qty, fiyat: fiyat, toplamElle: elle)]
        } else {
            kalemEkle()
        }
    }

    /// Ürün → web satış türü (bal ürünleri honey + honeyType, arı sütü milk, ana arı queen, diğerleri other).
    private func tur(_ urunId: String) -> (String, String?) {
        switch urunId {
        case "suzme_bal", "petek_bal", "karakovan_bal": return ("honey", urunId)
        case "ari_sutu": return ("milk", nil)
        case "ana_ari": return ("queen", nil)
        default: return ("other", nil)
        }
    }

    private func kaydet() {
        let musteriAd = musteri.trimmingCharacters(in: .whitespaces)
        let paid = odeme == "partial" ? Double(odenen.replacingOccurrences(of: ",", with: ".")) ?? 0 : nil
        let urunBirimleri = Dictionary(urunler.map { ($0.v, Birim(rawValue: $0.unit)) }, uniquingKeysWith: { a, _ in a })
        depo.degistir { v in
            var l = v.satislar
            let batch: String? = satisId == nil && kalemler.count > 1 ? yeniKimlik() : nil
            for k in kalemler {
                let i = satisId.flatMap { id in l.firstIndex { $0.id == id } }
                let onceki = i.map { l[$0] }
                var s = onceki ?? Satis(["id": .metin(yeniKimlik())])
                let (t, honey) = tur(k.urunId)
                s.type = t
                s.honeyType = honey
                s.product = k.urunId
                s.customer = musteriAd
                s.phone = telefon.isEmpty ? nil : telefon
                s.date = bugunISO(tarih)
                s.qty = k.miktar
                s.unit = k.birim.rawValue
                s.price = ucretsiz ? 0 : k.fiyat
                s.total = tutar(k)
                s.payment = odeme
                s.paidAmount = paid
                s.note = not
                s.orderStatus = onSiparis ? "preorder" : "delivered"
                if let batch { s.batchId = batch }
                if let i { l[i] = s } else { l.append(s) }
                v.satislar = l
                satisStokunuYaz(&v, satis: s, onceki: onceki, urunBirimi: urunBirimleri[k.urunId] ?? nil, kimlik: { yeniKimlik() })
                l = v.satislar
            }
        }
        // Birim fiyatı ayara kaydet (web: stok fiyatı satışta otomatik dolar)
        let yeniFiyatlar = kalemler.filter { $0.fiyat > 0 && !ucretsiz }
        if !yeniFiyatlar.isEmpty {
            depo.ayarDegistir { a in var p = a.stockPrices; for k in yeniFiyatlar { p[k.urunId] = k.fiyat }; a.stockPrices = p }
        }
    }
}

/// Bir kalem: görselli ürün kutuları, uyumlu birim seçici, ± adım, fiyat, toplam, kalan stok.
struct KalemDuzenleyici: View {
    @Environment(VeriDeposu.self) private var depo
    @Binding var kalem: SatisKalemi
    let urunler: [UrunTanimi]
    let ucretsiz: Bool

    private var urun: UrunTanimi? { urunler.first { $0.v == kalem.urunId } }
    private var urunBirimi: Birim { Birim(rawValue: urun?.unit ?? "") ?? kalem.birim }
    private var adim: Double { switch kalem.birim { case .kg, .lt: return 0.5; case .gr, .ml: return 50; case .adet: return 1 } }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 7)], spacing: 7) {
            ForEach(urunler, id: \.v) { u in
                Button { sec(u) } label: {
                    VStack(spacing: 3) {
                        UrunGorseli(urun: u, boyut: 40, yaricap: 10)
                        Text(u.temizAd).font(Yazi.minik).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .padding(.vertical, 6).frame(maxWidth: .infinity)
                    .background(kalem.urunId == u.v ? Color(red: 1, green: 0.95, blue: 0.81) : Renk.kart, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(kalem.urunId == u.v ? Renk.bal : Renk.krem2, lineWidth: 2))
                    .foregroundStyle(Renk.metin)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        Picker("Birim", selection: Binding(get: { kalem.birim }, set: { birimDegis($0) })) {
            ForEach(Birim.uyumlular(urunBirimi), id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        HStack {
            Button { kalem.miktar = max(adim, ((kalem.miktar - adim) * 100).rounded() / 100); kalem.toplamElle = nil } label: { Image(systemName: "minus.circle.fill").font(.system(size: 34)) }
                .buttonStyle(.plain).foregroundStyle(Renk.orman2)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("0", value: $kalem.miktar, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .font(Yazi.nunito(30, .bold)).frame(maxWidth: 120).onChange(of: kalem.miktar) { _, _ in kalem.toplamElle = nil }
                Text(kalem.birim.rawValue).font(Yazi.govdeOrta).foregroundStyle(.secondary)
            }
            Spacer()
            Button { kalem.miktar = ((kalem.miktar + adim) * 100).rounded() / 100; kalem.toplamElle = nil } label: { Image(systemName: "plus.circle.fill").font(.system(size: 34)) }
                .buttonStyle(.plain).foregroundStyle(Renk.orman2)
        }
        if !ucretsiz {
            HStack {
                Text("Birim fiyat")
                Spacer()
                TextField("0", value: $kalem.fiyat, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 110)
                Text("₺ / \(kalem.birim.rawValue)").foregroundStyle(.secondary)
            }
            HStack {
                Text("Tutar")
                Spacer()
                TextField("0", value: Binding(get: { kalem.toplamElle ?? kalem.miktar * kalem.fiyat }, set: { kalem.toplamElle = $0 }), format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 110)
                Text("₺").foregroundStyle(.secondary)
            }
        }
        if urun != nil {
            let mevcut = stokSeviyesi(depo.veri, urun: kalem.urunId)
            let dusen = Birim.cevir(kalem.miktar, kalem.birim, urunBirimi) ?? kalem.miktar
            HStack {
                Text("Stok")
                Spacer()
                Text("\(miktar(mevcut, urunBirimi.rawValue)) → ").foregroundStyle(.secondary)
                Text(miktar(mevcut - dusen, urunBirimi.rawValue)).foregroundStyle(mevcut - dusen < 0 ? Renk.kotu : .primary)
            }
            .font(Yazi.kucuk)
        }
    }

    private func sec(_ u: UrunTanimi) {
        kalem.urunId = u.v
        let b = Birim(rawValue: u.unit) ?? .adet
        kalem.birim = b
        kalem.miktar = b == .gr || b == .ml ? 100 : 1
        kalem.fiyat = depo.ayarlar.stockPrices[u.v] ?? 0
        kalem.toplamElle = nil
    }

    private func birimDegis(_ b: Birim) {
        let eski = kalem.birim
        kalem.miktar = (Birim.cevir(kalem.miktar, eski, b) ?? kalem.miktar)
        kalem.fiyat = (Birim.cevir(kalem.fiyat, b, eski) ?? kalem.fiyat)
        kalem.birim = b
        kalem.toplamElle = nil
    }
}
