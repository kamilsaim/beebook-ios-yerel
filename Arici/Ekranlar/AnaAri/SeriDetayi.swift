import AriCekirdek
import SwiftUI

/// Ana arı üretim serisi ayrıntısı (yenilogoo/anaarıüretim): seri kartı, gelişim şeridi, gelişim takvimi,
/// üretim özeti ve meme başına durum ızgarası. Memeye dokun → durumunu değiştir (kovana aktarırken kovan seçilir).
struct SeriDetayi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var geri
    let seriId: String
    @State private var duzenle = false
    @State private var secilenMeme: Meme?
    @State private var kovanSecimi: MemeSecimi?
    @State private var liste = false

    var body: some View {
        if let s = depo.veri.seriler.first(where: { $0.id == seriId }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button { geri() } label: { Label("Ana Arı", systemImage: "chevron.left").font(Yazi.govdeOrta).foregroundStyle(Renk.bal) }
                        Spacer()
                        CamDugme(simge: "pencil") { duzenle = true }.accessibilityLabel("Seriyi düzenle")
                    }
                    VStack(spacing: 2) {
                        Image(systemName: "crown.fill").font(.system(size: 22)).foregroundStyle(Renk.bal)
                        Text("Ana Arı Üretimi").font(Yazi.logo(32)).foregroundStyle(Renk.krem)
                        Text("Gelişim takibi ve dağıtım").font(Yazi.kucuk).foregroundStyle(Color(white: 0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    seriKarti(s)
                    if s.transfer != nil {
                        GelisimSeridi(seri: s, koyuZemin: true).padding(.vertical, 4)
                    }
                    HStack(alignment: .top, spacing: 10) {
                        takvim(s)
                        ozet(s)
                    }
                    memeler(s)
                }
                .padding(.horizontal, Olcu.kenar)
                .padding(.bottom, Olcu.altCubukPayi)
            }
            .scrollIndicators(.hidden)
            .background(SayfaArkaplani(gorsel: "SayfaCicek", koyuluk: 1))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $duzenle) { SeriFormu(seriId: s.id) }
            .confirmationDialog(secilenMeme.map { "Meme \(etiket(s, $0))" } ?? "", isPresented: Binding(get: { secilenMeme != nil }, set: { if !$0 { secilenMeme = nil } }), titleVisibility: .visible) {
                if let m = secilenMeme {
                    Button("Kovana aktarıldı…") { kovanSecimi = MemeSecimi(meme: m); secilenMeme = nil }
                    Button("Satıldı") { durumYaz(m, "satildi") }
                    Button("Bekliyor") { durumYaz(m, "pending") }
                    Button("Öldü / başarısız", role: .destructive) { durumYaz(m, "oldu") }
                }
            }
            .sheet(item: $kovanSecimi) { k in let m = k.meme; KovanSecici(baslik: "Meme \(etiket(s, m))", secili: m.targetHive) { kovanId in durumYaz(m, "kovana_aktarildi", kovan: kovanId) } }
        } else {
            BosDurum(simge: "crown", baslik: "Seri silindi").onAppear { geri() }
        }
    }

    // MARK: Parçalar

    private func seriKarti(_ s: AnaSeri) -> some View {
        Kart {
            HStack(spacing: 12) {
                Image("UrunAnaari").resizable().scaledToFill().frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(s.name ?? "Seri").font(Yazi.logo(26)).foregroundStyle(Renk.orman).lineLimit(1)
                        Spacer(minLength: 4)
                        Rozet(metin: s.status == "completed" ? "Tamamlandı" : s.status == "failed" ? "Başarısız" : "Aktif",
                              tur: s.status == "failed" ? .kotu : s.status == "completed" ? .notr : .iyi)
                    }
                    bilgi("calendar", "Transfer: " + (s.transfer.map { kisaTarih($0) } ?? "—"))
                    bilgi("archivebox", "Damızlık: " + (depo.kovan(s.motherHive).map { "Kovan \($0.num)" } ?? "—")
                          + (depo.kovan(s.starterHive).map { " · Başlatıcı: \($0.num)" } ?? ""))
                    bilgi("scope", [s.race, s.generation].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                          + (s.grafted.map { " · \(Int($0)) larva aşılandı" } ?? ""))
                }
            }
        }
    }

    private func bilgi(_ simge: String, _ metin: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: simge).font(.system(size: 12)).foregroundStyle(Color(red: 0.8, green: 0.55, blue: 0.05)).frame(width: 16)
            Text(metin).font(Yazi.kucuk).foregroundStyle(Renk.metin2).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private func takvim(_ s: AnaSeri) -> some View {
        let adimlar = s.transfer.map { gelisimTakvimi(transfer: $0) } ?? []
        let aktif = s.transfer.map { aktifAdimIndeksi(transfer: $0, bugun: bugunISO()) } ?? -1
        return Kart(dolgu: 12) {
            HStack(spacing: 6) {
                Image(systemName: "calendar").foregroundStyle(Renk.orman2)
                Text("Gelişim Takvimi").font(Yazi.kucukOrta)
            }
            if adimlar.isEmpty { Text("Transfer tarihi yok").font(Yazi.etiket).foregroundStyle(Renk.metin3) }
            ForEach(Array(adimlar.enumerated()), id: \.offset) { i, a in
                HStack(spacing: 6) {
                    Image(systemName: i < aktif ? "checkmark.circle.fill" : i == aktif ? "circle.inset.filled" : "circle")
                        .font(.system(size: 13)).foregroundStyle(i < aktif ? Renk.iyi : i == aktif ? Renk.bal : Renk.metin3)
                    Text(kisaTarih(a.tarih)).font(Yazi.etiket).foregroundStyle(Renk.metin2).frame(width: 48, alignment: .leading)
                    Text(a.ad).font(i == aktif ? Yazi.kucukOrta : Yazi.kucuk).lineLimit(1).minimumScaleFactor(0.8)
                }
                .padding(.vertical, 2).padding(.horizontal, 4)
                .background(i == aktif ? Renk.bal.opacity(0.2) : .clear, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func ozet(_ s: AnaSeri) -> some View {
        let m = s.memeler
        return Kart(dolgu: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill").foregroundStyle(Renk.bal)
                Text("Üretim Özeti").font(Yazi.kucukOrta)
            }
            ozetSatir("Aşılanan", s.grafted.map { Int($0) } ?? 0, Renk.metin)
            ozetSatir("Tutan", s.accepted.map { Int($0) } ?? m.count, Renk.orman2)
            ozetSatir("Kovanda", m.filter { $0.status == "kovana_aktarildi" }.count, Renk.iyi)
            ozetSatir("Satıldı", m.filter { $0.status == "satildi" }.count, Renk.bilgi)
            ozetSatir("Bekleyen", m.filter { ($0.status ?? "pending") == "pending" }.count, Renk.uyari)
        }
        .frame(width: 150)
    }

    private func ozetSatir(_ ad: String, _ sayi: Int, _ renk: Color) -> some View {
        HStack {
            Text(ad).font(Yazi.kucuk)
            Spacer()
            Text("\(sayi)").font(Yazi.nunito(18, .bold)).foregroundStyle(renk)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Renk.kart, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func memeler(_ s: AnaSeri) -> some View {
        let m = s.memeler
        return Kart(dolgu: 12) {
            HStack {
                Image(systemName: "hexagon.fill").foregroundStyle(Renk.bal)
                Text("Meme Başına Durum").font(Yazi.kartBaslik)
                Spacer()
                Text("\(m.count) meme").font(Yazi.etiket).foregroundStyle(Renk.metin3)
                Picker("", selection: $liste) {
                    Image(systemName: "square.grid.3x3").tag(false)
                    Image(systemName: "list.bullet").tag(true)
                }
                .pickerStyle(.segmented).frame(width: 84)
            }
            if m.isEmpty {
                Text("Tutan (meme) sayısını girince memeler burada listelenir. Kalem simgesiyle seriyi düzenle.")
                    .font(Yazi.kucuk).foregroundStyle(Renk.metin3)
            } else if liste {
                ForEach(m, id: \.id) { me in
                    Button { secilenMeme = me } label: {
                        HStack {
                            durumSimgesi(me.status).frame(width: 22)
                            Text(etiket(s, me)).font(Yazi.kucukOrta)
                            Spacer()
                            Text(durumMetni(me)).font(Yazi.kucuk).foregroundStyle(durumRengi(me.status))
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                    ForEach(m, id: \.id) { me in
                        Button { secilenMeme = me } label: { memeKutusu(s, me) }.buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: 10) {
                lejant("crown.fill", Renk.iyi, "Kovanda", m.filter { $0.status == "kovana_aktarildi" }.count)
                lejant("cart.fill", Renk.bilgi, "Satıldı", m.filter { $0.status == "satildi" }.count)
                lejant("hourglass", Renk.uyari, "Bekliyor", m.filter { ($0.status ?? "pending") == "pending" }.count)
                lejant("xmark", Renk.kotu, "Öldü", m.filter { $0.status == "oldu" }.count)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            Text("Memeye dokun: durumunu değiştir").font(Yazi.minik).foregroundStyle(Renk.metin3).frame(maxWidth: .infinity)
        }
    }

    private func memeKutusu(_ s: AnaSeri, _ m: Meme) -> some View {
        let renk = durumRengi(m.status)
        return VStack(spacing: 2) {
            Text(etiket(s, m)).font(Yazi.nunito(10, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            durumSimgesi(m.status).font(.system(size: 15))
            Text(kisaDurum(m)).font(Yazi.nunito(10)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(Renk.metin)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(renk.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(renk.opacity(0.45)))
        .accessibilityElement(children: .combine)
    }

    private func lejant(_ simge: String, _ renk: Color, _ ad: String, _ sayi: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: simge).font(.system(size: 11)).foregroundStyle(renk)
            Text("\(ad) (\(sayi))").font(Yazi.minik).foregroundStyle(Renk.metin2)
        }
    }

    // MARK: Durum

    @ViewBuilder
    private func durumSimgesi(_ d: String?) -> some View {
        switch d {
        case "kovana_aktarildi": Image(systemName: "crown.fill").foregroundStyle(Renk.iyi)
        case "satildi": Image(systemName: "cart.fill").foregroundStyle(Renk.bilgi)
        case "oldu": Image(systemName: "xmark").foregroundStyle(Renk.kotu)
        default: Image(systemName: "hourglass").foregroundStyle(Renk.uyari)
        }
    }

    private func durumRengi(_ d: String?) -> Color {
        switch d {
        case "kovana_aktarildi": return Renk.iyi
        case "satildi": return Renk.bilgi
        case "oldu": return Renk.kotu
        default: return Renk.uyari
        }
    }

    private func kisaDurum(_ m: Meme) -> String {
        switch m.status {
        case "kovana_aktarildi": return depo.kovan(m.targetHive).map { "K-\($0.num)" } ?? "Kovanda"
        case "satildi": return "Satıldı"
        case "oldu": return "Öldü"
        default: return "Bekliyor"
        }
    }

    private func durumMetni(_ m: Meme) -> String {
        m.status == "kovana_aktarildi" ? (depo.kovan(m.targetHive).map { "Kovan \($0.num)" } ?? "Kovana aktarıldı") : kisaDurum(m)
    }

    /// "A-26-03" biçimi: seri adı + iki haneli meme no.
    private func etiket(_ s: AnaSeri, _ m: Meme) -> String {
        let no = Int(m.num ?? "").map { String(format: "%02d", $0) } ?? (m.num ?? "")
        let ad = (s.name ?? "").replacingOccurrences(of: "Seri ", with: "")
        return ad.isEmpty ? no : "\(ad)-\(no)"
    }

    private func durumYaz(_ m: Meme, _ durum: String, kovan: String? = nil) {
        depo.degistir { v in
            var l = v.seriler
            guard let i = l.firstIndex(where: { $0.id == seriId }) else { return }
            var mm = l[i].memeler
            guard let j = mm.firstIndex(where: { $0.id == m.id }) else { return }
            mm[j].status = durum
            mm[j].targetHive = durum == "kovana_aktarildi" ? (kovan ?? "") : ""
            l[i].memeler = mm
            l[i].sold = Double(mm.filter { $0.status == "satildi" }.count)
            v.seriler = l
        }
        secilenMeme = nil
    }
}

/// Sayfa (sheet) için kimlikli sarmalayıcı (Meme çekirdekte Identifiable değil).
struct MemeSecimi: Identifiable {
    let meme: Meme
    var id: String { meme.id }
}

/// Meme aktarılacak kovanı seçme (anasız ve bakire kovanlar üstte).
struct KovanSecici: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let baslik: String
    let secili: String?
    let sec: (String) -> Void
    var body: some View {
        let kovanlar = depo.veri.kovanlar.filter { !$0.arisiz }.sorted {
            let o1 = $0.sorunlu ? 0 : ["bakire", "new", "meme"].contains($0.queenStatus ?? "") ? 1 : 2
            let o2 = $1.sorunlu ? 0 : ["bakire", "new", "meme"].contains($1.queenStatus ?? "") ? 1 : 2
            return (o1, $0.numara) < (o2, $1.numara)
        }
        NavigationStack {
            List(kovanlar, id: \.id) { k in
                Button { sec(k.id); kapat() } label: {
                    HStack {
                        Image(k.gorselAdi).resizable().scaledToFit().frame(width: 34, height: 34)
                        Text("Kovan \(k.num)").font(Yazi.govdeOrta)
                        Text(k.anaDurumMetni).font(Yazi.kucuk).foregroundStyle(k.sorunlu ? Renk.kotu : .secondary)
                        Spacer()
                        if k.id == secili { Image(systemName: "checkmark").foregroundStyle(Renk.orman2) }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(baslik)
            .navigationBarTitleDisplayMode(.inline)
            .formArkaplani()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Gelişim şeridi (Transfer → … → Dağıtım). Seri kartı ve seri ayrıntısında ortak.
struct GelisimSeridi: View {
    let seri: AnaSeri
    var koyuZemin = false
    var body: some View {
        let adimlar = seri.transfer.map { gelisimTakvimi(transfer: $0) } ?? []
        let aktif = seri.transfer.map { aktifAdimIndeksi(transfer: $0, bugun: bugunISO()) } ?? -1
        let yazi = koyuZemin ? Renk.krem : Renk.metin2
        let soluk = koyuZemin ? Color(white: 0.75) : Renk.metin3
        if !adimlar.isEmpty {
            ZStack(alignment: .top) {
                GeometryReader { g in
                    Capsule().fill(koyuZemin ? Color.white.opacity(0.25) : Renk.krem2).frame(height: 3).offset(y: 13).padding(.horizontal, 20)
                    Capsule().fill(Renk.iyi)
                        .frame(width: max(0, (g.size.width - 40) * CGFloat(max(0, aktif)) / CGFloat(adimlar.count - 1)), height: 3)
                        .offset(x: 20, y: 13)
                }
                HStack(alignment: .top) {
                    ForEach(Array(adimlar.enumerated()), id: \.offset) { i, a in
                        VStack(spacing: 4) {
                            ZStack {
                                Circle().fill(i < aktif ? Renk.iyi : i == aktif ? Renk.bal : Renk.kart).frame(width: 28, height: 28)
                                    .overlay(Circle().strokeBorder(i <= aktif ? .clear : Renk.krem2, lineWidth: 2))
                                    .shadow(color: i == aktif ? Renk.bal.opacity(0.7) : .clear, radius: 6)
                                if i < aktif { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white) }
                                else { Text("\(i + 1)").font(Yazi.minik).foregroundStyle(i == aktif ? Renk.orman : Renk.metin3) }
                            }
                            Text(a.ad).font(Yazi.minik).foregroundStyle(yazi)
                            Text(kisaTarih(a.tarih)).font(Yazi.nunito(10)).foregroundStyle(soluk)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 70)
        }
    }
}
