import AriCekirdek
import SwiftUI

/// Ana Arı: kovanlardaki anaların ırk/yaş özeti + üretim serileri (gelişim takvimi, meme durumları).
struct AnaAriEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var yeniSeri = false
    @State private var yol = NavigationPath()

    var body: some View {
        NavigationStack(path: $yol) {
        SekmeKaydirma(arka: "SayfaCicek", koyuluk: 0.95) {
            ManzaraBasligi {
                HStack { Marka(kucuk: true); Spacer(); CamDugme(simge: "plus") { yeniSeri = true }.accessibilityLabel("Yeni seri") }
                BuyukBaslik(metin: "Ana Arı", alt: "Kovanlardaki analar ve üretim serileri")
            }
            VStack(spacing: 12) {
                IrkOzeti()
                let seriler = depo.veri.seriler.sorted { s1, s2 in
                    (s1.status == "active" ? 0 : 1, s2.transfer ?? "") < (s2.status == "active" ? 0 : 1, s1.transfer ?? "")
                }
                if seriler.isEmpty {
                    BosDurum(simge: "crown", baslik: "Henüz üretim serisi yok", alt: "Sağ üstteki + ile larva transferini kaydet.")
                }
                ForEach(seriler, id: \.id) { s in
                    SeriKarti(seri: s).contentShape(Rectangle()).onTapGesture { yol.append(s.id) }
                }
            }
            .padding(.horizontal, Olcu.kenar)
            .padding(.top, 12)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: String.self) { id in SeriDetayi(seriId: id) }
        }
        .sheet(isPresented: $yeniSeri) { SeriFormu(seriId: nil) }
    }
}

struct KimlikKutusu: Identifiable { let id: String }

struct IrkOzeti: View {
    @Environment(VeriDeposu.self) private var depo
    private let renkler: [Color] = [Renk.orman2, Renk.bal, Renk.bilgi, Color(red: 0.6, green: 0.42, blue: 0.23), Renk.mor, Color(red: 0.4, green: 0.6, blue: 0.5)]

    var body: some View {
        let kovanlar = depo.veri.kovanlar.filter { $0.queenStatus != "empty" }
        let anali = kovanlar.filter { $0.queenStatus != "no" }
        let gruplar = Dictionary(grouping: anali) { ($0.race?.isEmpty == false ? $0.race! : "Belirsiz") }
            .map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
        let anasiz = kovanlar.count - anali.count
        let toplam = max(1, kovanlar.count)
        let buYil = Calendar.current.component(.year, from: Date())
        Kart {
            KartBasligi(baslik: "Kovanlardaki analar", baglanti: "\(kovanlar.count) kovan")
            GeometryReader { g in
                HStack(spacing: 0) {
                    ForEach(Array(gruplar.enumerated()), id: \.offset) { i, gr in
                        renkler[i % renkler.count].frame(width: g.size.width * CGFloat(gr.1) / CGFloat(toplam))
                    }
                    if anasiz > 0 { Renk.kotu.frame(width: g.size.width * CGFloat(anasiz) / CGFloat(toplam)) }
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())
            FlowLayout(aralik: 10) {
                ForEach(Array(gruplar.enumerated()), id: \.offset) { i, gr in
                    etiket(renkler[i % renkler.count], "\(gr.0) \(gr.1)")
                }
                if anasiz > 0 { etiket(Renk.kotu, "Anasız \(anasiz)") }
            }
            HStack(spacing: 6) {
                ForEach((buYil - 4...buYil).reversed(), id: \.self) { y in
                    VStack(spacing: 2) {
                        AnaNoktasi(renk: anaRengi(yil: y))
                        Text("\(anali.filter { $0.anaYili == y }.count)").font(Yazi.nunito(17, .bold))
                        Text(String(y)).font(Yazi.minik).foregroundStyle(Renk.metin2)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(Renk.kart, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func etiket(_ r: Color, _ m: String) -> some View {
        HStack(spacing: 4) { RoundedRectangle(cornerRadius: 3).fill(r).frame(width: 9, height: 9); Text(m).font(Yazi.etiket).foregroundStyle(Renk.metin2) }
    }
}

struct SeriKarti: View {
    @Environment(VeriDeposu.self) private var depo
    let seri: AnaSeri
    var body: some View {
        let m = seri.memeler
        Kart {
            HStack(spacing: 12) {
                Image("UrunAnaari").resizable().scaledToFill().frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(seri.name ?? "Seri").font(Yazi.nunito(18, .bold))
                    Text([seri.race, seri.generation].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                         + (depo.kovan(seri.motherHive).map { " · Damızlık: Kovan \($0.num)" } ?? ""))
                        .font(Yazi.kucuk).foregroundStyle(Renk.metin3)
                    if let t = seri.transfer { Text("Transfer: \(kisaTarih(t))").font(Yazi.kucuk).foregroundStyle(Renk.metin3) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Rozet(metin: seri.status == "completed" ? "Tamamlandı" : seri.status == "failed" ? "Başarısız" : "Aktif",
                          tur: seri.status == "failed" ? .kotu : seri.status == "completed" ? .notr : .iyi)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Renk.metin3)
                }
            }
            GelisimSeridi(seri: seri)
            if !m.isEmpty {
                HStack(spacing: 8) {
                    sayac("\(m.filter { $0.status == "kovana_aktarildi" }.count)", "Kovana", Renk.iyi)
                    sayac("\(m.filter { $0.status == "satildi" }.count)", "Satıldı", Renk.bilgi)
                    sayac("\(m.filter { ($0.status ?? "pending") == "pending" }.count)", "Bekliyor", Renk.metin)
                    sayac("\(m.filter { $0.status == "oldu" }.count)", "Öldü", Renk.kotu)
                }
            }
        }
    }

    private func sayac(_ d: String, _ e: String, _ r: Color) -> some View {
        VStack(spacing: 1) { Text(d).font(Yazi.nunito(20, .bold)).foregroundStyle(r); Text(e).font(Yazi.minik).foregroundStyle(Renk.metin2) }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(Renk.kart, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Basit akış yerleşimi (etiketler satır sonunda kayar).
struct FlowLayout: Layout {
    var aralik: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 300
        var x: CGFloat = 0, y: CGFloat = 0, satir: CGFloat = 0
        for s in subviews {
            let b = s.sizeThatFits(.unspecified)
            if x + b.width > w, x > 0 { x = 0; y += satir + 6; satir = 0 }
            x += b.width + aralik; satir = max(satir, b.height)
        }
        return CGSize(width: w, height: y + satir)
    }
    func placeSubviews(in r: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = r.minX, y = r.minY, satir: CGFloat = 0
        for s in subviews {
            let b = s.sizeThatFits(.unspecified)
            if x + b.width > r.maxX, x > r.minX { x = r.minX; y += satir + 6; satir = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += b.width + aralik; satir = max(satir, b.height)
        }
    }
}
