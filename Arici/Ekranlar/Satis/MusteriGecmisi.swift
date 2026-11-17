import AriCekirdek
import SwiftUI

/// Müşteri geçmişi (Bal Defterim): bir müşterinin tüm sezonlardaki satışları, toplamlar ve kalan alacak.
/// Satıra dokun → düzenle. Telefon varsa ara/WhatsApp.
struct MusteriGecmisiSayfasi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    @Environment(\.openURL) private var ac
    let musteri: String
    @State private var duzenlenen: String?

    var body: some View {
        let satislar = musteriGecmisi(depo.veri.satislar, musteri: musteri)
        let ucretli = satislar.filter { !["hediye", "zekat"].contains($0.payment ?? "") }
        let toplam = ucretli.reduce(0) { $0 + ($1.total ?? 0) }
        let alacak = bekleyenToplam(satislar: satislar)
        let telefon = satislar.compactMap(\.phone).first { !$0.isEmpty }
        let sezonlar = depo.veri.sezonlar
        let basHarf = String(musteri.split(separator: " ").prefix(2).compactMap(\.first)).uppercased(with: Locale(identifier: "tr"))
        let tarihler = satislar.compactMap { $0.date.map { String($0.prefix(10)) } }.filter { !$0.isEmpty }.sorted()
        NavigationStack {
            List {
                Section {
                    SayfaKahramaniMusteri(ad: musteri, basHarf: basHarf, aralik: tarihAraligi(tarihler)) {
                        HStack(spacing: 8) {
                            OzetKutucuk(simge: "cart", etiket: "Satış", deger: "\(satislar.count)", renk: Renk.orman2)
                            OzetKutucuk(simge: "banknote", etiket: "Toplam", deger: tl(toplam), renk: dahaAltin)
                            OzetKutucuk(simge: "creditcard", etiket: "Alacak", deger: tl(alacak), renk: alacak > 0 ? Renk.kotu : Renk.iyi)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        if let telefon {
                            HStack(spacing: 8) {
                                EylemDugmesi(simge: "phone.fill", metin: "Ara") {
                                    if let u = URL(string: "tel:\(telefon.filter { $0.isNumber || $0 == "+" })") { ac(u) }
                                }
                                EylemDugmesi(simge: "message.fill", metin: "WhatsApp", renk: Color(red: 0.15, green: 0.55, blue: 0.3)) {
                                    let metin = alacak > 0 ? "Merhaba \(musteri), \(tl(alacak)) tutarındaki bal ödemeniz hatırlatma olarak iletilir. Teşekkürler 🐝" : "Merhaba \(musteri) 🐝"
                                    let tel = telefon.filter(\.isNumber)
                                    let t = tel.hasPrefix("0") ? "90" + tel.dropFirst() : tel
                                    if let u = URL(string: "https://wa.me/\(t)?text=" + (metin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) { ac(u) }
                                }
                            }
                            Label(telefon, systemImage: "phone").font(Yazi.minik).foregroundStyle(Renk.metin2)
                        }
                    }
                }
                .listeBasligi()
                ForEach(gruplar(satislar, sezonlar: sezonlar), id: \.ad) { g in
                    Section {
                        ForEach(g.satislar, id: \.id) { s in
                            Button { duzenlenen = s.id } label: { satir(s) }.buttonStyle(.plain)
                        }
                    } header: {
                        Label(g.ad, systemImage: "calendar").font(Yazi.etiket)
                    }
                }
            }
            .navigationTitle("Müşteri")
            .navigationBarTitleDisplayMode(.inline)
            .formArkaplani()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } } }
            .sheet(item: Binding(get: { duzenlenen.map { KimlikKutusu(id: $0) } }, set: { duzenlenen = $0?.id })) { SatisFormu(satisId: $0.id) }
        }
    }

    private struct Grup { let ad: String; let satislar: [Satis] }

    /// Satışları sezon adına göre gruplar (yeni sezon üstte).
    private func gruplar(_ satislar: [Satis], sezonlar: [Sezon]) -> [Grup] {
        let sirali = sezonlar.sorted { sezonBaslangici($0) > sezonBaslangici($1) }
        var sira: [String] = []
        var g: [String: [Satis]] = [:]
        for s in satislar {
            let d = s.date ?? ""
            let ad = sirali.first { sezonBaslangici($0) <= d }?.name ?? String(d.prefix(4))
            if g[ad] == nil { sira.append(ad) }
            g[ad, default: []].append(s)
        }
        return sira.map { Grup(ad: $0.isEmpty ? "Tarihsiz" : $0, satislar: g[$0]!) }
    }

    private func satir(_ s: Satis) -> some View {
        HStack(spacing: 10) {
            UrunGorseli(urun: satisStokUrunu(s).flatMap { p in depo.urunler.first { $0.v == p } }, boyut: 38, yaricap: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.etiket(urunler: depo.urunler)).font(Yazi.govdeOrta)
                Text([s.date.map { kisaTarih($0) }, s.orderStatus == "preorder" ? "ön sipariş" : nil, s.note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Yazi.etiket).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(tl(s.total ?? 0)).font(Yazi.nunito(15, .bold))
                switch s.payment {
                case "pending": Rozet(metin: "Bekliyor", tur: .kotu)
                case "partial": Rozet(metin: "\(tl(kalan(s.ham))) kaldı", tur: .uyari)
                case "hediye": Rozet(metin: "Hediye", tur: .bilgi)
                case "zekat": Rozet(metin: "Zekat", tur: .mor)
                default: Rozet(metin: "Ödendi", tur: .iyi)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func kutu(_ deger: String, _ ad: String, renk: Color = Renk.metin) -> some View {
        VStack(spacing: 2) {
            Text(deger).font(Yazi.nunito(17, .bold)).foregroundStyle(renk).lineLimit(1).minimumScaleFactor(0.6)
            Text(ad).font(Yazi.etiket).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private func tarihAraligi(_ t: [String]) -> String {
    guard let ilk = t.first, let son = t.last else { return "Satış kaydı yok" }
    func uzun(_ x: String) -> String { "\(kisaTarih(x)) \(x.prefix(4))" }
    return ilk == son ? uzun(ilk) : "\(uzun(ilk)) – \(uzun(son))"
}

/// Müşteri başlık kartı: yapraklı zemin, ad + tarih aralığı, sağda baş harfli renkli daire.
private struct SayfaKahramaniMusteri<Icerik: View>: View {
    let ad: String
    let basHarf: String
    let aralik: String
    @ViewBuilder var icerik: Icerik
    var body: some View {
        DogaKart {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ad).font(Yazi.nunito(21, .bold)).foregroundStyle(Renk.orman).lineLimit(2)
                    Text(aralik).font(Yazi.minik).foregroundStyle(Renk.metin2)
                }
                .padding(.leading, 40)
                Spacer(minLength: 0)
                Text(basHarf).font(Yazi.nunito(21, .bold)).foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(MusteriKartiGorunumu.renkler[ad.unicodeScalars.reduce(0) { $0 + Int($1.value) } % MusteriKartiGorunumu.renkler.count], in: Circle())
                    .overlay(Circle().strokeBorder(Renk.bal, lineWidth: 2))
            }
            icerik
        }
    }
}
