import AriCekirdek
import Charts
import SwiftUI

/// Ana sayfa "Özet ve Raporlar" (yenilogoo/anasayfa detay): sezon bal üretimi halkası,
/// aylık bal üretimi grafiği ve koloni sağlığı halkası. "Tüm Raporlar" rapor sayfasını açar.
struct OzetRaporKarti: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var raporlar = false

    var body: some View {
        let uretim = BalUretimi(depo: depo)
        let saglik = KoloniSagligi(kovanlar: depo.veri.kovanlar)
        Kart {
            HStack {
                Image(systemName: "chart.bar.fill").foregroundStyle(Renk.orman2)
                Text("Özet ve Raporlar").font(Yazi.kartBaslik)
                Spacer()
                Button { raporlar = true } label: {
                    HStack(spacing: 3) { Text("Tüm Raporlar"); Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)) }
                        .font(Yazi.etiket).padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Renk.kart, in: Capsule())
                        .overlay(Capsule().strokeBorder(Renk.krem2))
                }
                .buttonStyle(.plain).foregroundStyle(Renk.metin)
            }
            HStack(alignment: .top, spacing: 8) {
                kutu {
                    Halka(oran: uretim.oran, renk: Renk.bal, metin: uretim.oran.map { "%\(Int(($0 * 100).rounded()))" } ?? "—")
                    Text("Sezon bal üretimi").font(Yazi.minik).foregroundStyle(Renk.metin2).multilineTextAlignment(.center)
                    Text(miktar(uretim.buSezon, "kg")).font(Yazi.kucukOrta)
                    if let o = uretim.gecenSezon { Text("Geçen: \(miktar(o, "kg"))").font(Yazi.minik).foregroundStyle(Renk.metin3) }
                }
                kutu {
                    Text("Aylık bal (kg)").font(Yazi.minik).foregroundStyle(Renk.metin2)
                    if uretim.aylik.allSatisfy({ $0.kg == 0 }) {
                        Text("Bu sezon bal girişi yok").font(Yazi.minik).foregroundStyle(Renk.metin3)
                            .multilineTextAlignment(.center).frame(maxHeight: .infinity)
                    } else {
                        Chart(uretim.aylik) { a in
                            BarMark(x: .value("Ay", a.ad), y: .value("kg", a.kg))
                                .foregroundStyle(LinearGradient(colors: [Renk.acikBal, Renk.bal], startPoint: .top, endPoint: .bottom))
                                .cornerRadius(3)
                        }
                        .chartYAxis { AxisMarks(position: .leading) { _ in AxisValueLabel().font(.system(size: 8)) } }
                        .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 8)) } }
                        .frame(height: 78)
                    }
                }
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
                kutu {
                    Halka(oran: saglik.oran, renk: Renk.iyi, metin: saglik.oran.map { "%\(Int(($0 * 100).rounded()))" } ?? "—")
                    Text("Koloni sağlığı").font(Yazi.minik).foregroundStyle(Renk.metin2)
                    (Text("Sağlıklı ").foregroundStyle(Renk.metin2) + Text("\(saglik.saglikli)").foregroundStyle(Renk.iyi)).font(Yazi.minik)
                    (Text("Riskli ").foregroundStyle(Renk.metin2) + Text("\(saglik.riskli)").foregroundStyle(Renk.uyari)).font(Yazi.minik)
                }
            }
        }
        .sheet(isPresented: $raporlar) {
            NavigationStack {
                RaporlarEkrani()
                    .navigationTitle("Raporlar")
                    .navigationBarTitleDisplayMode(.inline)
                    .formArkaplani()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { raporlar = false } } }
            }
        }
    }

    private func kutu<I: View>(@ViewBuilder _ icerik: () -> I) -> some View {
        VStack(spacing: 4) { icerik() }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 132)
            .background(Renk.kart, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Renk.krem2))
            .accessibilityElement(children: .combine)
    }
}

/// Yüzde halkası.
struct Halka: View {
    let oran: Double?
    let renk: Color
    let metin: String
    var boyut: CGFloat = 54
    var body: some View {
        ZStack {
            Circle().stroke(renk.opacity(0.18), lineWidth: 6)
            Circle().trim(from: 0, to: min(1, max(0, oran ?? 0)))
                .stroke(renk, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(metin).font(Yazi.kucukOrta).foregroundStyle(Renk.metin)
        }
        .frame(width: boyut, height: boyut)
    }
}

/// Bal üretimi: bal ürünlerinin stok girişleri (kg'ye çevrilmiş). Satış/düşüm kayıtları sayılmaz.
struct BalUretimi {
    struct Ay: Identifiable { let id: String; let ad: String; let kg: Double }
    let buSezon: Double
    let gecenSezon: Double?
    let aylik: [Ay]
    /// Bu sezon / geçen sezon (geçen sezon yoksa nil).
    var oran: Double? { gecenSezon.flatMap { $0 > 0 ? buSezon / $0 : nil } }

    init(depo: VeriDeposu) {
        let balIdleri = Set(depo.urunler.filter { u in
            let ad = (u.v + " " + u.l).lowercased()
            return ad.contains("bal") && !ad.contains("balmumu") && ["kg", "gr"].contains(u.unit)
        }.map(\.v))
        let girisler = depo.veri.stokKayitlari.filter { $0.action == "in" && balIdleri.contains($0.product ?? "") }
        func kg(_ k: StokKaydi) -> Double { (k.amount ?? 0) / (k.unit == "gr" ? 1000 : 1) }

        let aralik = depo.aktifAralik
        let buSezonKayitlari = girisler.filter { sezonda($0.date, aralik) }
        buSezon = buSezonKayitlari.reduce(0) { $0 + kg($1) }

        // Geçen sezon: aktif sezondan önce başlayan en yakın sezon.
        let sezonlar = depo.veri.sezonlar.sorted { sezonBaslangici($0) < sezonBaslangici($1) }
        let aktifId = depo.ayarlar.activeSeason ?? sezonlar.last?.id
        if let i = sezonlar.firstIndex(where: { $0.id == aktifId }), i > 0 {
            let onceki = aktifSezonAraligi(depo.veri, aktif: sezonlar[i - 1].id)
            gecenSezon = girisler.filter { sezonda($0.date, onceki) }.reduce(0) { $0 + kg($1) }
        } else {
            gecenSezon = nil
        }

        // Son 6 ay (bugünden geriye), sezon içi girişler.
        let c = Calendar.current
        let adlar = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]
        aylik = (0..<6).reversed().compactMap { fark -> Ay? in
            guard let d = c.date(byAdding: .month, value: -fark, to: Date()) else { return nil }
            let y = c.component(.year, from: d), m = c.component(.month, from: d)
            let onek = String(format: "%04d-%02d", y, m)
            let toplam = buSezonKayitlari.filter { ($0.date ?? "").hasPrefix(onek) }.reduce(0) { $0 + kg($1) }
            return Ay(id: onek, ad: adlar[m - 1], kg: toplam)
        }
    }
}

/// Koloni sağlığı: arısızlar hariç; sağlıklı = ana var, yaşlı değil, zayıf değil.
struct KoloniSagligi {
    let saglikli: Int
    let riskli: Int
    var oran: Double? { saglikli + riskli > 0 ? Double(saglikli) / Double(saglikli + riskli) : nil }
    init(kovanlar: [Kovan]) {
        let canli = kovanlar.filter { !$0.arisiz }
        saglikli = canli.filter { $0.saglikDurumu == .saglikli }.count
        riskli = canli.count - saglikli
    }
}

enum SaglikDurumu { case saglikli, dikkat, mudahale, arisiz }

extension Kovan {
    /// Kovan kartı ve özet için durum: anasız → müdahale; bakire/meme/bilinmiyor/yaşlı/zayıf → dikkat.
    var saglikDurumu: SaglikDurumu {
        if arisiz { return .arisiz }
        if sorunlu { return .mudahale }
        if queenStatus != "yes" || yasliAna || gucMetni == "Zayıf" { return .dikkat }
        return .saglikli
    }
}
