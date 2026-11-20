import AriCekirdek
import SwiftUI

// Android `Kovanlar.kt › MuayeneFormu / BalSagimiFormu` ile aynı: Vızvız'dan gelince (`taslak`) alanlar dolu,
// anlaşılmayan alan boş (—) kalır, tahmin yazılmaz. Altta büyük Kaydet (son dokunuş kullanıcıda).

extension VeriDeposu {
    var varroaIlaclari: [String] {
        if let l = ayarlar.varroaTreatments, !l.isEmpty { return l }
        return varsayilanVarroaIlaclari
    }
}

private let varroaIslemAdi = ["takildi": "şerit takıldı", "cikarildi": "şerit çıkarıldı", "uygulandi": "uygulandı"]

/// "Amitraz şerit takıldı · 12 akar"
func varroaOzeti(_ m: Muayene) -> String? {
    let islem = m.varroaAction.map { a in [m.varroaTreatment, varroaIslemAdi[a] ?? a].compactMap { $0 }.joined(separator: " ") }
    let sayi = m.varroaCount.map { $0 == 0 ? "akar yok" : "\(Int($0)) akar" }
    let s = [islem, sayi].compactMap { $0 }.joined(separator: " · ")
    return s.isEmpty ? nil : s
}

func muayeneOzeti(_ m: Muayene) -> String {
    var p: [String] = []
    if let q = m.queenSeen { p.append(q ? "Ana görüldü" : "Ana görülmedi") }
    if m.eggs == true { p.append("Yumurta var") }
    if let a = m.openBrood { p.append(a ? "Açık yavru var" : "Açık yavru yok") }
    if let k = m.cappedBrood { p.append(k ? "Kapalı yavru var" : "Kapalı yavru yok") }
    if let b = m.brood { p.append("Yavru: " + (["duzenli": "düzenli", "seyrek": "seyrek", "yok": "yok"][b] ?? b)) }
    if let s = m.strength, let g = Int(s.trimmingCharacters(in: .whitespaces)) { p.append("Güç: \(g >= 4 ? "güçlü" : g == 3 ? "orta" : "zayıf")") }
    if let f = m.feeding, !f.isEmpty { p.append("Besleme: \(f)") }
    if let v = varroaOzeti(m) { p.append("Varroa: \(v)") }
    return p.joined(separator: " · ")
}

private func sayiCoz(_ s: String) -> Double? { Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }
private func ondalikMetni(_ d: Double) -> String {
    d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d).replacingOccurrences(of: ".", with: ",")
}

/// Formun altında büyük, başparmakla rahat basılan Kaydet.
/// Etkin: koyu yeşil zemin + bal rengi yazı (krem formda ve bal tonlu kartlarda net); pasif: beyaz zemin + ne eksik olduğu.
struct BuyukKaydetCubugu: View {
    var metin = "Kaydet"
    var etkin = true
    var ipucu: String? = nil
    let kaydet: () -> Void
    var body: some View {
        Button(action: kaydet) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark").font(.system(size: 20, weight: .bold))
                Text(etkin || ipucu == nil ? metin : ipucu!).font(etkin || ipucu == nil ? Yazi.nunito(19, .heavy) : Yazi.govdeOrta).lineLimit(1)
            }
            .foregroundStyle(etkin ? Renk.acikBal : Renk.metin2)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(etkin ? AnyShapeStyle(LinearGradient(colors: [Renk.orman2, Renk.ormanKoyu], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white), in: Capsule())
            .overlay(Capsule().strokeBorder(etkin ? Renk.bal : Renk.metin3.opacity(0.5), lineWidth: etkin ? 1.5 : 1))
            .shadow(color: .black.opacity(etkin ? 0.3 : 0), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!etkin)
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
        .background(LinearGradient(colors: [Renk.krem.opacity(0), Renk.krem], startPoint: .top, endPoint: .center).ignoresSafeArea())
    }
}

/// Vızvız'ın duyduğu cümle: formun başında "kontrol et" notu.
struct ViziltiNotu: View {
    let metin: String
    var body: some View {
        HStack(spacing: 10) {
            Vizilti(cirpiyor: false, konusuyor: ViziltiSes.paylasilan.konusuyor).frame(width: 38, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text("Vızvız doldurdu — kontrol et, sonra Kaydet").font(Yazi.kucukOrta).foregroundStyle(Renk.orman)
                Text("“\(metin)”").font(Yazi.kucuk).foregroundStyle(Renk.metin2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Renk.bal.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Renk.bal.opacity(0.5)))
    }
}

/// Üç durumlu alan: Vızvız anlamadıysa (nil) "— / Var / Yok" seçimi, sonra anahtar.
private struct UcDurum: View {
    let baslik: String
    let evet: String
    let hayir: String
    @Binding var deger: Bool?
    var body: some View {
        if let d = deger {
            Toggle(baslik, isOn: Binding(get: { d }, set: { deger = $0 })).tint(Renk.orman2)
        } else {
            Picker(baslik, selection: Binding(get: { 0 }, set: { deger = $0 == 1 ? true : $0 == 2 ? false : nil })) {
                Text("—").tag(0); Text(evet).tag(1); Text(hayir).tag(2)
            }
            .pickerStyle(.segmented)
        }
    }
}

/// Muayene formu (`inspections`). Güç 1–5; kovanın gücünü de günceller. Kovan çerçevesi `frames`, kat otomatik;
/// "N gün sonra bak" → tarihli iş; şerit takınca +42 gün "şeridi çıkar" işi.
struct MuayeneFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let kovanId: String
    var taslak: ViziltiSonuc? = nil

    @State private var tarih = Date()
    @State private var anaGoruldu: Bool? = true
    @State private var yumurta: Bool? = true
    @State private var acikYavru: Bool? = true
    @State private var kapaliYavru: Bool? = true
    @State private var yavru: String? = "duzenli"
    @State private var guc: Int? = 4
    @State private var besleme = ""
    @State private var not = ""
    @State private var cerceve = 0
    @State private var eskiCerceve = 0
    @State private var varroaSayi = ""
    @State private var varroaIslem = ""
    @State private var varroaIlac = ""
    @State private var seritHatirlat = true
    @State private var seritTarih = Calendar.current.date(byAdding: .day, value: VARROA_SERIT_GUN, to: Date()) ?? Date()
    @State private var hatirlat = false
    @State private var hatirlatTarih = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var hazir = false

    private var kovan: Kovan? { depo.kovan(kovanId) }

    var body: some View {
        NavigationStack {
            Form {
                if let taslak { Section { ViziltiNotu(metin: taslak.metin) }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
                DatePicker("Tarih", selection: $tarih, displayedComponents: .date)
                Section("Ana arı") {
                    UcDurum(baslik: "Ana görüldü", evet: "Görüldü", hayir: "Görülmedi", deger: $anaGoruldu)
                    UcDurum(baslik: "Yumurta / genç larva", evet: "Yumurta var", hayir: "Yok", deger: $yumurta)
                    UcDurum(baslik: "Açık yavru var", evet: "Açık yavru var", hayir: "Yok", deger: $acikYavru)
                    UcDurum(baslik: "Kapalı yavru var", evet: "Kapalı yavru var", hayir: "Yok", deger: $kapaliYavru)
                }
                Section("Koloni") {
                    Picker("Yavru", selection: Binding(get: { yavru ?? "" }, set: { yavru = $0.isEmpty ? nil : $0 })) {
                        if yavru == nil { Text("—").tag("") }
                        Text("Düzenli").tag("duzenli"); Text("Seyrek").tag("seyrek"); Text("Yok").tag("yok")
                    }
                    .pickerStyle(.segmented)
                    CipSecici(baslik: guc == nil ? "Güç: — (Vızvız anlamadı)" : "Güç", secenekler: [(1, "1 Çok zayıf"), (2, "2 Zayıf"), (3, "3 Orta"), (4, "4 Güçlü"), (5, "5 Çok güçlü")], secili: guc) { guc = $0 }
                    Stepper(value: $cerceve, in: 0...40) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cerceve != eskiCerceve ? "Kovan çerçevesi: \(cerceveYazi(eskiCerceve)) → \(cerceveYazi(cerceve))" : "Kovan çerçevesi: \(cerceveYazi(cerceve))")
                            if cerceve != eskiCerceve {
                                let eskiKat = kovan?.katSayisi ?? 1, yeniKat = otomatikKat(cerceve)
                                Text(yeniKat != eskiKat ? "Kat: \(eskiKat) → \(yeniKat) (çerçeveye göre)" : "Kat: \(yeniKat)").font(Yazi.minik).foregroundStyle(Renk.metin3)
                            }
                        }
                    }
                }
                Section {
                    TextField("Akar sayısı (düşen / sayılan)", text: $varroaSayi).keyboardType(.numberPad)
                    Picker("İşlem", selection: $varroaIslem) {
                        Text("—").tag(""); Text("Şerit tak").tag("takildi"); Text("Şerit çıkar").tag("cikarildi"); Text("Uygula").tag("uygulandi")
                    }
                    .pickerStyle(.segmented)
                    if !varroaIslem.isEmpty {
                        let l = depo.varroaIlaclari
                        Picker("İlaç / yöntem", selection: $varroaIlac) {
                            ForEach(l + (varroaIlac.isEmpty || l.contains(varroaIlac) ? [] : [varroaIlac]), id: \.self) { Text($0).tag($0) }
                        }
                    }
                    if varroaIslem == "takildi" {
                        Toggle("Şeridi çıkarmayı hatırlat", isOn: $seritHatirlat).tint(Renk.orman2)
                        if seritHatirlat { DatePicker("Çıkarma tarihi", selection: $seritTarih, displayedComponents: .date) }
                    }
                } header: { Label("Varroa", systemImage: "ladybug") }
                Section("Besleme ve not") {
                    TextField("Besleme (ör. 1 lt şurup)", text: $besleme)
                    TextField("Not", text: $not, axis: .vertical)
                }
                Section("Tekrar bakılacak") {
                    Toggle("Hatırlat", isOn: $hatirlat).tint(Renk.orman2)
                    if hatirlat { DatePicker("Tarih", selection: $hatirlatTarih, displayedComponents: .date) }
                }
            }
            .navigationTitle(kovan.map { "Kovan \($0.num) · Muayene" } ?? "Muayene")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { kaydet() } }
            }
            .safeAreaInset(edge: .bottom) { BuyukKaydetCubugu { kaydet() } }
        }
        .onAppear(perform: doldur)
    }

    private func cerceveYazi(_ n: Int) -> String { n == 0 ? "—" : String(n) }

    private func doldur() {
        guard !hazir else { return }
        hazir = true
        eskiCerceve = Int(kovan?.frames ?? 0)
        cerceve = taslak?.cerceve ?? eskiCerceve
        varroaIlac = taslak?.varroaIlac ?? depo.varroaIlaclari.first ?? ""
        guard let t = taslak else { return }
        anaGoruldu = t.anaGoruldu; yumurta = t.yumurta; acikYavru = t.acikYavru; kapaliYavru = t.kapaliYavru
        yavru = t.yavru; guc = t.guc
        besleme = t.besleme ?? ""
        not = [t.anaYok ? "Ana yok" : nil, t.not].compactMap { $0 }.joined(separator: ". ")
        varroaSayi = t.varroaSayi.map(String.init) ?? ""
        varroaIslem = t.varroaIslem ?? ""
        if let g = t.gunSonra { hatirlat = true; hatirlatTarih = Calendar.current.date(byAdding: .day, value: g, to: Date()) ?? Date() }
    }

    private func kaydet() {
        let g = guc.map(String.init)
        let num = kovan?.num ?? ""
        depo.degistir { v in
            var m = Muayene(["id": .metin(yeniKimlik())])
            m.hiveId = kovanId; m.date = bugunISO(tarih)
            m.queenSeen = anaGoruldu; m.eggs = yumurta; m.openBrood = acikYavru; m.cappedBrood = kapaliYavru
            m.brood = yavru; m.strength = g
            m.feeding = besleme.isEmpty ? nil : besleme
            m.note = not.isEmpty ? nil : not
            m.varroaCount = sayiCoz(varroaSayi)
            m.varroaAction = varroaIslem.isEmpty ? nil : varroaIslem
            m.varroaTreatment = varroaIslem.isEmpty || varroaIlac.isEmpty ? nil : varroaIlac
            v.muayeneler = v.muayeneler + [m]
            var isler = v.isler
            if varroaIslem == "takildi" && seritHatirlat {
                isler.append(Is(["id": .metin(yeniKimlik()), "text": .metin("Kovan \(num) varroa şeridini çıkar" + (varroaIlac.isEmpty ? "" : " (\(varroaIlac))")),
                                 "done": .bool(false), "dueDate": .metin(bugunISO(seritTarih)), "scope": .metin(num), "hiveIds": .dizi([.metin(kovanId)])]))
            }
            if hatirlat {
                isler.append(Is(["id": .metin(yeniKimlik()), "text": .metin("Kovan \(num) kontrol"), "done": .bool(false),
                                 "dueDate": .metin(bugunISO(hatirlatTarih)), "scope": .metin(num), "hiveIds": .dizi([.metin(kovanId)])]))
            }
            v.isler = isler
            var l = v.kovanlar
            if let i = l.firstIndex(where: { $0.id == kovanId }) {
                if let g { l[i].strength = g }
                if cerceve != eskiCerceve { l[i].frames = cerceve == 0 ? nil : Double(cerceve); l[i].floors = Double(otomatikKat(cerceve)) }
                v.kovanlar = l
            }
        }
        if taslak != nil { ViziltiSes.paylasilan.cal("vizilti_kaydettim") }
        kapat()
    }
}

/// Bal sağımı (sesle ve elle): alınan çerçeve × çerçeve başı kg = tahmini kg → stok girişi; kovanın çerçevesi düşer, kat yeniden hesaplanır.
struct BalSagimiFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let kovanId: String
    var taslak: ViziltiSonuc? = nil

    @State private var alinan = 0
    @State private var kgElle: String?
    @State private var urunId = ""
    @State private var stogaEkle = true
    @State private var tarih = Date()
    @State private var hazir = false

    private var kovan: Kovan? { depo.kovan(kovanId) }
    private var kgBasi: Double { ViziltiAyari.paylasilan.cerceveBasiKg }
    private var eskiCerceve: Int { Int(kovan?.frames ?? 0) }
    private var yeniCerceve: Int { max(0, eskiCerceve - alinan) }
    private var kgMetni: String { kgElle ?? (alinan > 0 ? ondalikMetni(balKgTahmini(alinan, kgBasi)) : "") }
    private var kg: Double { sayiCoz(kgMetni) ?? 0 }
    private var urunler: [UrunTanimi] { depo.urunler.filter { $0.pasif != true } }

    var body: some View {
        NavigationStack {
            Form {
                if let taslak { Section { ViziltiNotu(metin: taslak.metin) }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
                Section { kahraman }
                Section {
                    DatePicker("Tarih", selection: $tarih, displayedComponents: .date)
                    Stepper("Alınan çerçeve: \(alinan == 0 ? "—" : String(alinan))", value: $alinan, in: 0...40)
                    HStack {
                        Text(kgElle == nil && alinan > 0 ? "Tahmini bal (kg)" : "Bal (kg)")
                        Spacer()
                        TextField("kg", text: Binding(get: { kgMetni }, set: { kgElle = $0 })).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
                        if kgElle != nil && alinan > 0 { Button("Tahmine dön") { kgElle = nil }.font(Yazi.etiket).buttonStyle(.borderless) }
                    }
                } header: { Label("Sağım", systemImage: "drop") } footer: {
                    if kgElle == nil && alinan > 0 { Text("Ortalama: çerçeve başı \(ondalikMetni(kgBasi)) kg · Ayarlar › Vızvız'dan değişir") }
                }
                Section {
                    Toggle("Stoğa giriş olarak ekle", isOn: $stogaEkle).tint(Renk.orman2)
                    if stogaEkle && !urunler.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(urunler, id: \.v) { u in
                                    let secili = u.v == urunId
                                    Button { urunId = u.v } label: {
                                        VStack(spacing: 4) {
                                            UrunGorseli(urun: u, boyut: 40, yaricap: 10)
                                            Text(u.temizAd).font(Yazi.minik).foregroundStyle(secili ? Renk.orman : Renk.metin2).lineLimit(2).multilineTextAlignment(.center)
                                        }
                                        .frame(width: 84).padding(.vertical, 8)
                                        .background(secili ? Renk.bal.opacity(0.22) : .clear, in: RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(secili ? Renk.bal : Renk.krem2, lineWidth: secili ? 1.5 : 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: { Label("Stok", systemImage: "shippingbox") } footer: { if stogaEkle { Text("Stokta ürün girişi olarak görünür") } }
                if alinan > 0 && eskiCerceve > 0, let k = kovan {
                    Section {
                        HStack {
                            Spacer()
                            durum(k, kat: k.katSayisi, cerceve: eskiCerceve, etiket: "Şimdi")
                            Spacer()
                            Text("→").font(Yazi.nunito(26, .bold)).foregroundStyle(Renk.bal)
                            Spacer()
                            durum(k, kat: otomatikKat(yeniCerceve), cerceve: yeniCerceve, etiket: "Sağımdan sonra")
                            Spacer()
                        }
                    } header: { Label("Kovan", systemImage: "archivebox") } footer: { Text("Kaydedince kovanın çerçevesi ve katı güncellenir") }
                }
            }
            .navigationTitle(kovan.map { "Kovan \($0.num) · Bal sağımı" } ?? "Bal sağımı")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { kaydet() }.disabled(alinan == 0 && kg == 0) }
            }
            .safeAreaInset(edge: .bottom) { BuyukKaydetCubugu(etkin: alinan > 0 || kg > 0, ipucu: "Önce çerçeve ya da kg gir") { kaydet() } }
        }
        .onAppear {
            guard !hazir else { return }
            hazir = true
            alinan = taslak?.balCerceve ?? 0
            kgElle = taslak?.balKg.map(ondalikMetni)
            let l = urunler
            urunId = (l.first { $0.v.localizedCaseInsensitiveContains("suzme") || $0.l.localizedCaseInsensitiveContains("süzme") }
                ?? l.first { $0.v.localizedCaseInsensitiveContains("bal") || $0.l.localizedCaseInsensitiveContains("bal") } ?? l.first)?.v ?? ""
        }
    }

    private var kahraman: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let k = kovan { Image(k.gorselAdi).resizable().scaledToFit().frame(width: 92, height: 100) }
                Image("UrunSagim").resizable().scaledToFit().frame(width: 60, height: 60).offset(x: 12, y: 8)
            }
            .frame(width: 92, height: 100)
            VStack(alignment: .leading, spacing: 3) {
                Text(kovan.map { "Kovan \($0.num)" } ?? "Bal sağımı").font(Yazi.nunito(20, .heavy)).foregroundStyle(Renk.orman).lineLimit(1)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(kg > 0 ? ondalikMetni(kg) : "—").font(Yazi.nunito(34, .heavy)).foregroundStyle(Renk.uyari)
                    Text("kg bal").font(Yazi.govdeOrta).foregroundStyle(Renk.metin2)
                }
                HStack(spacing: 5) {
                    if alinan > 0 { Rozet(metin: "\(alinan) çerçeve", simge: "hexagon", arkaRenk: Renk.bal.opacity(0.22)) }
                    if kg > 0 { Rozet(metin: kgElle == nil ? "Tahmini" : "Tartıldı", tur: kgElle == nil ? .notr : .iyi) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private func durum(_ k: Kovan, kat: Int, cerceve: Int, etiket: String) -> some View {
        VStack(spacing: 2) {
            Image(kovanGorselAdi(tip: k.type ?? "", kat: kat)).resizable().scaledToFit().frame(width: 64, height: 70)
            Text(etiket).font(Yazi.minik).foregroundStyle(Renk.metin3)
            Text("\(cerceve == 0 ? "—" : String(cerceve)) çerçeve · \(kat) kat").font(Yazi.kucukOrta).foregroundStyle(Renk.metin)
        }
    }

    private func kaydet() {
        let kgDeger = kg, tahmini = kgElle == nil, a = alinan, yeni = yeniCerceve, eski = eskiCerceve
        let u = urunId, birim = depo.urunler.first { $0.v == urunId }?.unit ?? "kg"
        let num = kovan?.num
        depo.degistir { v in
            if stogaEkle && kgDeger > 0 && !u.isEmpty {
                var k = StokKaydi(["id": .metin(yeniKimlik()), "hiveId": .metin(kovanId)])
                k.product = u; k.action = "in"; k.amount = kgDeger; k.unit = birim; k.date = bugunISO(tarih)
                k.note = ["Bal sağımı", num.map { "Kovan \($0)" }, a > 0 ? "\(a) çerçeve" : nil, tahmini ? "tahmini" : nil].compactMap { $0 }.joined(separator: " · ")
                v.stokKayitlari = v.stokKayitlari + [k]
            }
            if a > 0 && eski > 0 {
                var l = v.kovanlar
                if let i = l.firstIndex(where: { $0.id == kovanId }) {
                    l[i].frames = yeni == 0 ? nil : Double(yeni); l[i].floors = Double(otomatikKat(yeni)); v.kovanlar = l
                }
            }
        }
        if taslak != nil { ViziltiSes.paylasilan.cal("vizilti_kaydettim") }
        kapat()
    }
}
