import SwiftUI
import Charts
import AriCekirdek

// Android SatisSayfalari.kt ile aynı: ortak satış satırı, ay satışları, satış raporu, hediye/zekat kayıtları,
// dokunulabilir aylık satış grafiği.

private let ayAdlari = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]

/// "2026-11" → "Kasım 2026".
func ayAdi(_ onek: String) -> String {
    let p = onek.split(separator: "-")
    guard p.count >= 2, let a = Int(p[1]), (1...12).contains(a) else { return onek }
    return "\(ayAdlari[a - 1]) \(p[0])"
}

/// Satış rozeti tek yerden: ön sipariş / hediye / zekat / kısmi / bekliyor / ödendi.
struct SatisRozeti: View {
    let s: Satis
    var body: some View {
        let on = s.orderStatus == "preorder"
        let p = s.payment ?? "paid"
        if on && (p == "pending" || p == "partial") { Rozet(metin: "Ön sipariş", tur: .uyari, simge: "hourglass") }
        else if p == "hediye" { Rozet(metin: "Hediye", tur: .mor, simge: "gift") }
        else if p == "zekat" { Rozet(metin: "Zekat", tur: .bilgi, simge: "moon.stars") }
        else if p == "partial" { Rozet(metin: "\(tl(kalan(s.ham))) kaldı", tur: .uyari) }
        else if p == "pending" { Rozet(metin: "Bekliyor", tur: .kotu) }
        else if on { Rozet(metin: "Ön sipariş", tur: .uyari, simge: "hourglass") }
        else { Rozet(metin: "Ödendi", tur: .iyi) }
    }
}

/// Ortak satış satırı: ürün görseli, müşteri, tarih · miktar ürün, tutar + rozet.
struct SatisKaydiSatiri: View {
    let s: Satis
    let urunler: [UrunTanimi]
    var tutarGoster = true
    var body: some View {
        HStack(spacing: 10) {
            UrunGorseli(urun: urunler.first { $0.v == satisStokUrunu(s) }, boyut: 44, yaricap: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.customer.flatMap { $0.isEmpty ? nil : $0 } ?? "Müşteri").font(Yazi.govdeOrta).foregroundStyle(Renk.metin).lineLimit(1)
                Text([s.date.map { kisaTarih($0) }, s.etiket(urunler: urunler)].compactMap { $0 }.joined(separator: " · "))
                    .font(Yazi.etiket).foregroundStyle(Renk.metin2).lineLimit(1)
                if let n = s.note, !n.isEmpty { Text(n).font(Yazi.minik).foregroundStyle(Renk.metin3).lineLimit(1) }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                if tutarGoster { Text(tl(s.total ?? 0)).font(Yazi.nunito(15, .heavy)).foregroundStyle(Renk.metin) }
                SatisRozeti(s: s)
            }
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Renk.metin3)
        }
        .contentShape(Rectangle())
    }
}

/// Son 6 ay satış grafiği; bir aya dokununca o ayın satışları açılır.
struct AylikSatisGrafigi: View {
    let aylik: [SatisOzeti.Ay]
    var yukseklik: CGFloat = 96
    @State private var acilan: KimlikKutusu?
    var body: some View {
        Chart(aylik) { a in
            BarMark(x: .value("Ay", a.ad), y: .value("₺", a.tutar))
                .foregroundStyle(LinearGradient(colors: [Renk.acikBal, Renk.bal], startPoint: .top, endPoint: .bottom))
                .cornerRadius(3)
        }
        .chartYAxis { AxisMarks(position: .leading) { _ in AxisValueLabel().font(.system(size: 8)) } }
        .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 8)) } }
        // chartXSelection kaydırma görünümü içinde tek dokunuşta seçmiyor (basılı tutma ister) →
        // dokunulan x'i ay adına çevirip doğrudan aç (Android AylikCubuklar tıklaması gibi).
        .chartOverlay { vekil in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onTapGesture { nokta in
                        guard let alan = vekil.plotFrame else { return }
                        let x = nokta.x - geo[alan].origin.x
                        guard let ad: String = vekil.value(atX: x), let a = aylik.first(where: { $0.ad == ad }) else { return }
                        acilan = KimlikKutusu(id: a.id)
                    }
            }
        }
        .frame(height: yukseklik)
        .sheet(item: $acilan) { AySatislariSayfasi(onek: $0.id) }
        .accessibilityHint("Bir aya dokun: o ayın satışları açılır")
    }
}

// MARK: Ay satışları

struct AySatislariSayfasi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let onek: String
    @State private var duzenle: KimlikKutusu?

    var body: some View {
        let l = depo.veri.satislar.filter { ($0.date ?? "").hasPrefix(onek) }.sorted { ($0.date ?? "") > ($1.date ?? "") }
        let ucretli = l.filter { !["hediye", "zekat"].contains($0.payment ?? "") }
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        OzetKutucuk(simge: "banknote", etiket: "Satış", deger: tl(ucretli.reduce(0) { $0 + ($1.total ?? 0) }), renk: Renk.orman2)
                        OzetKutucuk(simge: "checkmark.seal", etiket: "Tahsil", deger: tl(ucretli.reduce(0) { $0 + odenen($1.ham) }), renk: Renk.iyi)
                        OzetKutucuk(simge: "doc.text", etiket: "Alacak", deger: tl(bekleyenToplam(satislar: l)), renk: Renk.kotu)
                    }
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                if l.isEmpty {
                    Text("Bu ayda satış yok.").foregroundStyle(Renk.metin3)
                } else {
                    Section {
                        ForEach(l, id: \.id) { s in
                            Button { duzenle = KimlikKutusu(id: s.id) } label: { SatisKaydiSatiri(s: s, urunler: depo.urunler) }.buttonStyle(.plain)
                        }
                    } header: { Label("\(l.count) satış", systemImage: "cart") } footer: { Text("Dokun: satışı düzenle.") }
                }
            }
            .navigationTitle("\(ayAdi(onek)) satışları")
            .navigationBarTitleDisplayMode(.inline)
            .formArkaplani()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } } }
            .sheet(item: $duzenle) { SatisFormu(satisId: $0.id) }
        }
    }
}

// MARK: Satış raporu

struct SatisRaporuSayfasi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    @State private var musteri: KimlikKutusu?

    var body: some View {
        let satislar = depo.sezonda(depo.veri.satislar)
        let urunler = depo.urunler
        let ucretli = satislar.filter { !["hediye", "zekat"].contains($0.payment ?? "") }
        let bekleyen = musteriKartlari(satislar).filter { $0.kalanTutar > 0 }
        let ozet = SatisOzeti(depo: depo)
        let gruplar = satisRaporu(satislar).sorted { $0.satisTl > $1.satisTl }
        let enCok = max(1, gruplar.map(\.satisTl).max() ?? 1)
        NavigationStack {
            Form {
                Section {
                    SayfaKahramani(gorsel: "SimgeRapor", baslik: "Satış Raporu", alt: "\(satislar.count) kayıt · \(ucretli.count) ücretli satış") {
                        HStack(spacing: 8) {
                            OzetKutucuk(simge: "banknote", etiket: "Toplam satış", deger: tl(ucretli.reduce(0) { $0 + ($1.total ?? 0) }), renk: Renk.orman2)
                            OzetKutucuk(simge: "checkmark.seal", etiket: "Tahsil edilen", deger: tl(ucretli.reduce(0) { $0 + odenen($1.ham) }), renk: Renk.iyi)
                        }
                        HStack(spacing: 8) {
                            OzetKutucuk(simge: "doc.text", etiket: "Alacak", deger: tl(bekleyenToplam(satislar: satislar)), renk: Renk.kotu)
                            OzetKutucuk(simge: "hourglass", etiket: "Ön sipariş", deger: "\(satislar.filter { $0.orderStatus == "preorder" }.count)", renk: Renk.uyari)
                        }
                    }
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())

                Section {
                    if ozet.aylik.allSatisfy({ $0.tutar == 0 }) { Text("Son 6 ayda satış yok.").foregroundStyle(Renk.metin3) }
                    else { AylikSatisGrafigi(aylik: ozet.aylik, yukseklik: 120).padding(.vertical, 6) }
                } header: { Label("Aylık satış", systemImage: "chart.bar") } footer: { Text("Bir aya dokun: o ayın satışları açılır.") }

                Section {
                    if gruplar.isEmpty { Text("Bu sezon satış yok.").foregroundStyle(Renk.metin3) }
                    ForEach(gruplar, id: \.anahtar) { g in
                        let u = g.anahtar.hasPrefix("urun_") ? urunler.first { $0.v == String(g.anahtar.dropFirst(5)) } : nil
                        let ad = u?.temizAd ?? (g.anahtar.hasPrefix("urun_") ? String(g.anahtar.dropFirst(5)) : ["tur_queen": "Ana Arı", "tur_bee": "Arı Satışı", "tur_milk": "Arı Sütü"][g.anahtar] ?? "Diğer")
                        HStack(spacing: 10) {
                            UrunGorseli(urun: u, boyut: 44, yaricap: 12)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack { Text(ad).font(Yazi.govdeOrta).lineLimit(1); Spacer(); Text(tl(g.satisTl)).font(Yazi.nunito(15, .heavy)) }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Renk.krem2)
                                        Capsule().fill(LinearGradient(colors: [Renk.acikBal, Renk.bal], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: max(4, geo.size.width * g.satisTl / enCok))
                                    }
                                }
                                .frame(height: 6)
                                Text("\(miktar(g.satis, g.unit ?? "")) satış · \(g.satisAdet) kayıt" + (g.hediye > 0 ? " · \(miktar(g.hediye, g.unit ?? "")) hediye" : "") + (g.zekat > 0 ? " · \(miktar(g.zekat, g.unit ?? "")) zekat" : ""))
                                    .font(Yazi.etiket).foregroundStyle(Renk.metin2)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: { Label("Ürünlere göre", systemImage: "shippingbox") }

                if !bekleyen.isEmpty {
                    Section {
                        ForEach(bekleyen) { k in
                            Button { musteri = KimlikKutusu(id: k.musteri) } label: {
                                HStack(spacing: 10) {
                                    Text(k.musteri.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased(with: Locale(identifier: "tr")))
                                        .font(Yazi.nunito(14, .heavy)).foregroundStyle(Renk.acikBal)
                                        .frame(width: 38, height: 38)
                                        .background(LinearGradient(colors: [Renk.orman2, Renk.orman], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(k.musteri).font(Yazi.govdeOrta).foregroundStyle(Renk.metin).lineLimit(1)
                                        Text("\(kisaTarih(k.tarih)) · \(k.satirlar.count) satış").font(Yazi.etiket).foregroundStyle(Renk.metin2)
                                    }
                                    Spacer()
                                    Text(tl(k.kalanTutar)).font(Yazi.nunito(15, .heavy)).foregroundStyle(Renk.kotu)
                                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Renk.metin3)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: { Label("Bekleyen ödemeler (\(bekleyen.count))", systemImage: "doc.text") } footer: { Text("Dokun: müşteri geçmişi.") }
                }
            }
            .navigationTitle("Satış Raporu")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } }
                ToolbarItem(placement: .topBarLeading) { RaporPaylasDugmesi() }
            }
            .sheet(item: $musteri) { MusteriGecmisiSayfasi(musteri: $0.id) }
        }
    }
}

// MARK: Stok › Hediye / Zekat kayıtları

struct OdemeKayitlariSayfasi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let tur: String
    @State private var duzenle: KimlikKutusu?
    @State private var zekatVer = false

    var body: some View {
        let zekat = tur == "zekat"
        let baslik = zekat ? "Zekat kayıtları" : "Hediye kayıtları"
        let l = depo.sezonda(depo.veri.satislar).filter { $0.payment == tur }.sorted { ($0.date ?? "") > ($1.date ?? "") }
        let gruplar = Dictionary(grouping: l, by: { "\(satisStokUrunu($0) ?? "")|\($0.unit ?? "")" })
            .map { (anahtar: $0.key, toplam: $0.value.reduce(0) { $0 + ($1.qty ?? 0) }) }
            .sorted { $0.toplam > $1.toplam }
        let musteriSayisi = Set(l.compactMap { $0.customer?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }).count
        NavigationStack {
            Form {
                Section {
                    SayfaKahramani(gorsel: zekat ? "SimgeZekat" : "SimgeHediye", baslik: baslik, alt: zekat ? "Bu sezon verilen zekatlar" : "Bu sezon verilen hediyeler") {
                        HStack(spacing: 8) {
                            OzetKutucuk(simge: zekat ? "moon.stars" : "gift", etiket: "Kayıt", deger: "\(l.count)", renk: zekat ? Renk.bilgi : Renk.mor)
                            OzetKutucuk(simge: "person.2", etiket: "Müşteri", deger: "\(musteriSayisi)", renk: Renk.orman2)
                        }
                    }
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())

                if !gruplar.isEmpty {
                    Section {
                        ForEach(gruplar, id: \.anahtar) { g in
                            let p = g.anahtar.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                            let u = depo.urunler.first { $0.v == p[0] }
                            HStack(spacing: 10) {
                                UrunGorseli(urun: u, boyut: 36, yaricap: 10)
                                Text(u?.temizAd ?? (p[0].isEmpty ? "Diğer" : p[0])).font(Yazi.govde)
                                Spacer()
                                Text(miktar(g.toplam, p.count > 1 ? p[1] : "")).font(Yazi.nunito(15, .heavy))
                            }
                        }
                    } header: { Label("Ürünlere göre", systemImage: "shippingbox") }
                }

                if l.isEmpty {
                    Text("Bu sezon \(zekat ? "zekat" : "hediye") kaydı yok.").foregroundStyle(Renk.metin3)
                } else {
                    Section {
                        ForEach(l, id: \.id) { s in
                            Button { duzenle = KimlikKutusu(id: s.id) } label: { SatisKaydiSatiri(s: s, urunler: depo.urunler, tutarGoster: false) }.buttonStyle(.plain)
                        }
                    } header: { Label("Kayıtlar (\(l.count))", systemImage: "doc.text") } footer: { Text("Dokun: düzenle (miktar, ürün, tarih). Değişiklik stoğa da yansır.") }
                }
                if zekat {
                    Section { Button { zekatVer = true } label: { Label("Zekat verdim, kaydet", systemImage: "moon.stars") } }
                }
            }
            .navigationTitle(baslik)
            .navigationBarTitleDisplayMode(.inline)
            .formArkaplani()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } } }
            .sheet(item: $duzenle) { SatisFormu(satisId: $0.id) }
            .sheet(isPresented: $zekatVer) { SatisFormu(satisId: nil, varsayilanOdeme: "zekat") }
        }
    }
}
