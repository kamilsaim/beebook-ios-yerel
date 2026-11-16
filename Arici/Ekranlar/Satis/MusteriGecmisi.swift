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
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 0) {
                        kutu("\(satislar.count)", "Satış")
                        kutu(tl(toplam), "Toplam")
                        kutu(tl(alacak), "Alacak", renk: alacak > 0 ? Renk.kotu : Renk.metin)
                    }
                    if let telefon {
                        HStack {
                            Button { if let u = URL(string: "tel:\(telefon.filter { $0.isNumber || $0 == "+" })") { ac(u) } } label: {
                                Label(telefon, systemImage: "phone.fill")
                            }
                            Spacer()
                        }
                    }
                }
                ForEach(gruplar(satislar, sezonlar: sezonlar), id: \.ad) { g in
                    Section(g.ad) {
                        ForEach(g.satislar, id: \.id) { s in
                            Button { duzenlenen = s.id } label: { satir(s) }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(musteri)
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
            UrunGorseli(urun: satisStokUrunu(s).flatMap { p in depo.urunler.first { $0.v == p } }, boyut: 34, yaricap: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.etiket(urunler: depo.urunler)).font(Yazi.govdeOrta)
                Text([s.date.map { kisaTarih($0) }, s.orderStatus == "preorder" ? "ön sipariş" : nil, s.note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Yazi.etiket).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(tl(s.total ?? 0)).font(Yazi.kucukOrta)
                switch s.payment {
                case "pending": Text("Bekliyor").font(Yazi.minik).foregroundStyle(Renk.kotu)
                case "partial": Text("\(tl(kalan(s.ham))) kaldı").font(Yazi.minik).foregroundStyle(Renk.uyari)
                case "hediye": Text("Hediye").font(Yazi.minik).foregroundStyle(Renk.bilgi)
                case "zekat": Text("Zekat").font(Yazi.minik).foregroundStyle(Renk.mor)
                default: Text("Ödendi").font(Yazi.minik).foregroundStyle(Renk.iyi)
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
