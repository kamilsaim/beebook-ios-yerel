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
    var varsayilanOdeme: String? = nil

    @State private var musteri = ""
    @State private var telefon = ""
    @State private var tarih = Date()
    @State private var kalemler: [SatisKalemi] = []
    @State private var odeme = "paid"
    @State private var odenen = ""
    @State private var onSiparis = false
    @State private var not = ""
    @State private var yuklendi = false
    @State private var rehber = false

    private var urunler: [UrunTanimi] { depo.urunler }
    private var ucretsiz: Bool { odeme == "hediye" || odeme == "zekat" }

    var body: some View {
        NavigationStack {
            Form {
                Section { satisOzeti }.listeBasligi()
                Section {
                    HStack {
                        Image(systemName: "person").foregroundStyle(kartAltin).frame(width: 22)
                        TextField("Müşteri adı", text: $musteri).textInputAutocapitalization(.words)
                        Button { rehber = true } label: {
                            Label("Rehber", systemImage: "person.crop.rectangle").font(Yazi.kucukOrta).foregroundStyle(Renk.orman2)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Renk.orman2.opacity(0.12), in: Capsule())
                                .overlay(Capsule().strokeBorder(Renk.orman2.opacity(0.25)))
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Rehberden kişi seç")
                    }
                    .background(RehberSecici(acik: $rehber) { ad, tel in
                        musteri = ad
                        if let tel, !tel.isEmpty { telefon = tel }
                    }.frame(width: 0, height: 0))
                    if !oneriler.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 6) {
                                ForEach(oneriler, id: \.self) { o in
                                    Button { musteriSec(o) } label: {
                                        HStack(spacing: 6) {
                                            Text(String(o.split(separator: " ").prefix(2).compactMap(\.first)).uppercased(with: Locale(identifier: "tr")))
                                                .font(Yazi.nunito(11, .bold)).foregroundStyle(.white)
                                                .frame(width: 26, height: 26)
                                                .background(MusteriKartiGorunumu.renkler[o.unicodeScalars.reduce(0) { $0 + Int($1.value) } % MusteriKartiGorunumu.renkler.count], in: Circle())
                                            Text(o).font(Yazi.kucukOrta).foregroundStyle(Renk.metin).lineLimit(1)
                                        }
                                        .padding(.leading, 4).padding(.trailing, 12).padding(.vertical, 4)
                                        .background(Renk.kart, in: Capsule())
                                        .overlay(Capsule().strokeBorder(Renk.krem2))
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                    HStack {
                        Image(systemName: "phone").foregroundStyle(kartAltin).frame(width: 22)
                        TextField("Telefon (isteğe bağlı)", text: $telefon).keyboardType(.phonePad)
                    }
                    HStack {
                        Image(systemName: "calendar").foregroundStyle(kartAltin).frame(width: 22)
                        DatePicker("Tarih", selection: $tarih, displayedComponents: .date)
                    }
                } header: { Label("Müşteri", systemImage: "person") }
                ForEach($kalemler) { $k in
                    Section(header: Label(kalemler.count > 1 ? "Ürün \((kalemler.firstIndex(of: k) ?? 0) + 1)" : "Ürün", systemImage: "basket")) {
                        KalemDuzenleyici(kalem: $k, urunler: urunler.filter { $0.pasif != true || $0.v == k.urunId }, ucretsiz: ucretsiz)
                        if kalemler.count > 1 {
                            Button("Bu ürünü çıkar", role: .destructive) { kalemler.removeAll { $0.id == k.id } }
                        }
                    }
                }
                if satisId == nil {
                    Section { EylemDugmesi(simge: "cart.badge.plus", metin: "Başka ürün ekle") { kalemEkle() } }.listeBasligi()
                }
                Section(header: Label("Ödeme", systemImage: "banknote")) {
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
            .formArkaplani()
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

    /// Üst özet: müşteri baş harfleri + canlı toplam.
    private var satisOzeti: some View {
        let ad = musteri.trimmingCharacters(in: .whitespaces)
        let bas = String(ad.split(separator: " ").prefix(2).compactMap(\.first)).uppercased(with: Locale(identifier: "tr"))
        return HStack(spacing: 12) {
            Group {
                if bas.isEmpty { Image(systemName: "person").font(.system(size: 22)).foregroundStyle(Renk.metin3) }
                else { Text(bas).font(Yazi.nunito(19, .bold)).foregroundStyle(.white) }
            }
            .frame(width: 52, height: 52)
            .background(ad.isEmpty ? Renk.krem2 : MusteriKartiGorunumu.renkler[ad.unicodeScalars.reduce(0) { $0 + Int($1.value) } % MusteriKartiGorunumu.renkler.count], in: Circle())
            .overlay(Circle().strokeBorder(Renk.bal, lineWidth: 2))
            .padding(.leading, 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(ad.isEmpty ? "Müşteri seç" : ad).font(Yazi.nunito(18, .bold)).foregroundStyle(Renk.orman).lineLimit(1)
                Text("\(kalemler.count) ürün · \(kisaTarih(bugunISO(tarih)))").font(Yazi.minik).foregroundStyle(Renk.metin2)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 0) {
                Text("Toplam").font(Yazi.minik).foregroundStyle(Renk.metin2)
                Text(tl(genelToplam)).font(Yazi.nunito(22, .bold)).foregroundStyle(dahaAltin).lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
        .dogaZemini()
    }

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
        guard let u = depo.aktifUrunler.first ?? urunler.first else { return }
        let b = Birim(rawValue: u.unit) ?? .kg
        kalemler.append(SatisKalemi(urunId: u.v, birim: b, miktar: b == .gr || b == .ml ? 100 : 1, fiyat: depo.ayarlar.stockPrices[u.v] ?? 0))
    }

    // MARK: Yükle / kaydet

    private func yukle() {
        guard !yuklendi else { return }
        yuklendi = true
        if satisId == nil, let v = varsayilanOdeme { odeme = v }
        if let s = depo.veri.satislar.first(where: { $0.id == satisId }) {
            musteri = s.customer ?? ""; telefon = s.phone ?? ""; tarih = isoTarih(s.date) ?? Date()
            odeme = s.payment ?? "paid"; odenen = s.paidAmount.map { $0 == $0.rounded() ? String(Int($0)) : String($0).replacingOccurrences(of: ".", with: ",") } ?? ""
            onSiparis = s.orderStatus == "preorder"; not = s.note ?? ""
            // Stok ürünü olmayan eski satış (arı/ana arı/diğer): türü korunur, product yazılmaz
            let uid = satisStokUrunu(s) ?? "tur:" + (s.type ?? "other")
            let qty = s.qty ?? 0, fiyat = s.price ?? 0
            let elle = abs((s.total ?? 0) - qty * fiyat) > 0.009 && (s.total ?? 0) > 0 ? s.total : nil
            kalemler = [SatisKalemi(urunId: uid, birim: Birim(rawValue: s.unit ?? "") ?? .kg, miktar: qty, fiyat: fiyat, toplamElle: elle)]
        } else {
            kalemEkle()
        }
    }

    /// Ürün → web satış türü (bal ürünleri honey + honeyType, arı sütü milk, ana arı queen, diğerleri other).
    private func tur(_ urunId: String, onceki: Satis?) -> (String, String?) {
        // Düzenlenen satış bal türündeyse özel bal ürünü de honey + honeyType olarak kalır
        if onceki?.type == "honey", urunId != "ari_sutu", urunId != "ana_ari" { return ("honey", urunId) }
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
                if k.urunId.hasPrefix("tur:") {
                    s.type = String(k.urunId.dropFirst(4))   // stok ürünü değil: tür korunur, product yazılmaz
                } else {
                    let (t, honey) = tur(k.urunId, onceki: onceki)
                    s.type = t
                    s.honeyType = honey
                    s.product = k.urunId
                }
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
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
            ForEach(urunler, id: \.v) { u in
                let secili = kalem.urunId == u.v
                let stok = stokSeviyesi(depo.veri, urun: u.v)
                let sekil = RoundedRectangle(cornerRadius: 14, style: .continuous)
                Button { sec(u) } label: {
                    VStack(spacing: 2) {
                        UrunGorseli(urun: u, boyut: 48, yaricap: 12)
                        Text(u.temizAd).font(Yazi.nunito(12, .bold)).lineLimit(1).minimumScaleFactor(0.8)
                        Text(miktar(stok, u.unit)).font(Yazi.nunito(10)).foregroundStyle(stok <= 0 ? Renk.kotu : Renk.metin3).lineLimit(1)
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
            }
        }
        .padding(.vertical, 4)
        Picker("Birim", selection: Binding(get: { kalem.birim }, set: { birimDegis($0) })) {
            ForEach(Birim.uyumlular(urunBirimi), id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        HStack(spacing: 10) {
            adimDugmesi("minus") { kalem.miktar = max(adim, ((kalem.miktar - adim) * 100).rounded() / 100); kalem.toplamElle = nil }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("0", value: $kalem.miktar, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .font(Yazi.nunito(28, .bold)).frame(maxWidth: 110).onChange(of: kalem.miktar) { _, _ in kalem.toplamElle = nil }
                Text(kalem.birim.rawValue).font(Yazi.nunito(16, .bold)).foregroundStyle(dahaAltin)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Renk.bal.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Renk.bal.opacity(0.35)))
            adimDugmesi("plus") { kalem.miktar = ((kalem.miktar + adim) * 100).rounded() / 100; kalem.toplamElle = nil }
        }
        if !ucretsiz {
            HStack(spacing: 8) {
                fiyatAlani("tag", "Birim fiyat (₺/\(kalem.birim.rawValue))", $kalem.fiyat, vurgu: false)
                fiyatAlani("banknote", "Tutar (₺)", Binding(get: { kalem.toplamElle ?? kalem.miktar * kalem.fiyat }, set: { kalem.toplamElle = $0 }), vurgu: true)
            }
        }
        if urun != nil {
            let mevcut = stokSeviyesi(depo.veri, urun: kalem.urunId)
            let dusen = Birim.cevir(kalem.miktar, kalem.birim, urunBirimi) ?? kalem.miktar
            let eksi = mevcut - dusen < 0
            HStack(spacing: 6) {
                Image(systemName: "shippingbox").foregroundStyle(eksi ? Renk.kotu : Renk.iyi)
                Text(eksi ? "Stok yetmiyor" : "Stok").font(Yazi.kucukOrta).foregroundStyle(eksi ? Renk.kotu : Renk.metin)
                Spacer()
                Text(miktar(mevcut, urunBirimi.rawValue)).foregroundStyle(.secondary)
                Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(Renk.metin3)
                Text(miktar(mevcut - dusen, urunBirimi.rawValue)).font(Yazi.nunito(13, .bold)).foregroundStyle(eksi ? Renk.kotu : Renk.metin)
            }
            .font(Yazi.kucuk)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background((eksi ? Renk.kotu : Renk.iyi).opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func adimDugmesi(_ simge: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Image(systemName: simge).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(LinearGradient(colors: [Renk.orman2, Renk.orman], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                .overlay(Circle().strokeBorder(Renk.bal.opacity(0.5)))
        }
        .buttonStyle(.borderless)
    }

    private func fiyatAlani(_ simge: String, _ etiket: String, _ deger: Binding<Double>, vurgu: Bool) -> some View {
        let sekil = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(alignment: .leading, spacing: 4) {
            Label(etiket, systemImage: simge).font(Yazi.minik).foregroundStyle(Renk.metin2).lineLimit(1).minimumScaleFactor(0.8)
            TextField("0", value: deger, format: .number).keyboardType(.decimalPad).font(Yazi.nunito(18, .bold))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(vurgu ? Renk.orman2.opacity(0.08) : Renk.kart, in: sekil)
        .overlay(sekil.strokeBorder(vurgu ? Renk.orman2.opacity(0.35) : Renk.krem2))
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
