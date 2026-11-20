import AriCekirdek
import SwiftUI

/// Ana arı üretim serisi ayrıntısı (yenilogoo/anaarıüretim): seri kartı, gelişim şeridi, gelişim takvimi,
/// üretim özeti ve meme başına durum ızgarası. Memeye dokun → durumunu değiştir (kovana aktarırken kovan seçilir).
struct SeriDetayi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var geri
    let seriId: String
    @State private var duzenle = false
    @State private var secilenMeme: MemeSecimi?
    @State private var liste = false
    @State private var sayiAlani: SayiAlani?
    @State private var siradakine = true
    @State private var topluDurum: String?

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
                        Image(systemName: "rosette").font(.system(size: 20, weight: .semibold)).foregroundStyle(Renk.acikBal)
                            .frame(width: 40, height: 40).background(Renk.bal.opacity(0.25), in: Circle()).overlay(Circle().strokeBorder(Renk.bal))
                        Text("Ana Arı Üretimi").font(Yazi.nunito(26, .bold)).foregroundStyle(Renk.krem)
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
            .sheet(item: $secilenMeme) { k in
                let m = s.memeler.first { $0.id == k.id } ?? k.meme
                MemeDurumPenceresi(
                    baslik: "Meme \(etiket(s, m))",
                    sira: (s.memeler.firstIndex { $0.id == m.id } ?? 0) + 1, toplam: s.memeler.count,
                    durum: m.status ?? "pending", durumMetni: durumMetni(m), hedef: m.targetHive, siradakine: $siradakine
                ) { d, kovan in durumYaz(m, d, kovan: kovan) }
            }
            .sheet(item: $sayiAlani) { a in
                let g = s.grafted.map { Int($0) } ?? 0
                let t = s.accepted.map { Int($0) } ?? 0
                switch a {
                case .asilanan:
                    SayiPenceresi(baslik: "Aşılanan larva", ilk: s.grafted.map { Int($0) }, hizli: [10, 15, 20, 25, 30, 40, 60], aciklama: nil) { sayiYaz(a, $0) }
                case .tutan:
                    SayiPenceresi(baslik: "Tutan (meme)", ilk: s.accepted.map { Int($0) }, hizli: tutanOnerileri(g),
                                  aciklama: g > 0 ? "Aşılanan \(g) · memeler bu sayıya göre listelenir" : "Memeler bu sayıya göre listelenir") { sayiYaz(a, $0) }
                case .cikan:
                    SayiPenceresi(baslik: "Çıkan ana", ilk: s.emerged.map { Int($0) }, hizli: cikanOnerileri(t),
                                  aciklama: t > 0 ? "Tutan \(t) · çıkmayanlar listeden düşer" : nil) { sayiYaz(a, $0) }
                }
            }
            .confirmationDialog(topluDurum.map { "Bekleyen memelerin hepsi \"\($0 == "satildi" ? "Satıldı" : "Öldü")\" olsun mu?" } ?? "",
                                isPresented: Binding(get: { topluDurum != nil }, set: { if !$0 { topluDurum = nil } }), titleVisibility: .visible) {
                if let d = topluDurum {
                    Button("Evet", role: d == "oldu" ? .destructive : nil) { topluYaz(d) }
                }
            }
        } else {
            BosDurum(simge: "crown", baslik: "Seri silindi").onAppear { geri() }
        }
    }

    // MARK: Parçalar

    private func seriKarti(_ s: AnaSeri) -> some View {
        DogaKart {
            HStack(spacing: 12) {
                Image("UrunAnaari").resizable().scaledToFill().frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Renk.bal, lineWidth: 1.5))
                    .padding(.leading, 18).padding(.top, 8)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(s.name ?? "Seri").font(Yazi.nunito(21, .bold)).foregroundStyle(Renk.orman).lineLimit(1)
                        Spacer(minLength: 4)
                        Rozet(metin: s.status == "completed" ? "Tamamlandı" : s.status == "failed" ? "Başarısız" : "Aktif",
                              tur: s.status == "failed" ? .kotu : s.status == "completed" ? .notr : .iyi)
                    }
                    bilgi("calendar", "Transfer: " + (s.transfer.map { kisaTarih($0) } ?? "—"))
                    bilgi("square.stack.3d.up", "Damızlık: " + (depo.kovan(s.motherHive).map { "Kovan \($0.num)" } ?? "—")
                          + (depo.kovan(s.starterHive).map { " · Başlatıcı: \($0.num)" } ?? ""))
                    bilgi("ladybug", [s.race, s.generation].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                          + (s.grafted.map { " · \(Int($0)) larva" } ?? ""))
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
            BolumBasligi(simge: "chart.line.uptrend.xyaxis", baslik: "Gelişim Takvimi", kucuk: true)
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
            BolumBasligi(simge: "chart.bar.fill", baslik: "Üretim", kucuk: true)
            ozetSatir("Aşılanan", s.grafted.map { Int($0) } ?? 0, Renk.metin, alan: .asilanan)
            ozetSatir("Tutan", s.accepted.map { Int($0) } ?? m.count, Renk.orman2, alan: .tutan)
            ozetSatir("Çıkan", s.emerged.map { Int($0) } ?? 0, Renk.bal, alan: .cikan)
            ozetSatir("Kovanda", m.filter { $0.status == "kovana_aktarildi" }.count, Renk.iyi)
            ozetSatir("Satıldı", m.filter { $0.status == "satildi" }.count, Renk.bilgi)
            ozetSatir("Bekleyen", m.filter { ($0.status ?? "pending") == "pending" }.count, Renk.uyari)
        }
        .frame(width: 162)
    }

    /// `alan` verilirse satır dokunulabilir: sayıyı hızlıca düzelt (memeler tutan/çıkana göre boyutlanır).
    private func ozetSatir(_ ad: String, _ sayi: Int, _ renk: Color, alan: SayiAlani? = nil) -> some View {
        let icerik = HStack(spacing: 6) {
            Circle().fill(renk).frame(width: 8, height: 8)
            Text(ad).font(Yazi.kucuk).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Text(alan != nil && sayi == 0 ? "—" : "\(sayi)").font(Yazi.nunito(18, .bold)).foregroundStyle(renk)
            if alan != nil { Image(systemName: "pencil").font(.system(size: 10, weight: .bold)).foregroundStyle(renk.opacity(0.7)) }
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(renk.opacity(alan != nil ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(renk.opacity(alan != nil ? 0.45 : 0.2)))
        return Group {
            if let alan { Button { sayiAlani = alan } label: { icerik }.buttonStyle(.plain) } else { icerik }
        }
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
                Text("Tutan (meme) sayısını girince memeler burada listelenir.")
                    .font(Yazi.kucuk).foregroundStyle(Renk.metin3)
                Button { sayiAlani = .tutan } label: {
                    Text("Tutan sayısını gir").font(Yazi.govdeOrta).foregroundStyle(Renk.acikBal)
                        .frame(maxWidth: .infinity, minHeight: 48).background(Renk.orman2, in: Capsule())
                }
                .buttonStyle(.plain)
            } else if liste {
                ForEach(m, id: \.id) { me in
                    Button { secilenMeme = MemeSecimi(meme: me) } label: {
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
                        Button { secilenMeme = MemeSecimi(meme: me) } label: { memeKutusu(s, me) }.buttonStyle(.plain)
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
            let bekleyen = m.filter { ($0.status ?? "pending") == "pending" }.count
            if bekleyen > 1 {
                HStack(spacing: 6) {
                    Text("Bekleyen \(bekleyen) memenin hepsi:").font(Yazi.etiket).foregroundStyle(Renk.metin2)
                    Spacer(minLength: 2)
                    topluDugme("cart.fill", "Satıldı", Renk.bilgi) { topluDurum = "satildi" }
                    topluDugme("xmark", "Öldü", Renk.kotu) { topluDurum = "oldu" }
                }
                .padding(.top, 6)
            }
            Text("Memeye dokun: durumunu seç, sıradaki kendiliğinden açılır").font(Yazi.minik).foregroundStyle(Renk.metin3).frame(maxWidth: .infinity)
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

    private func topluDugme(_ simge: String, _ ad: String, _ renk: Color, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Label(ad, systemImage: simge).font(Yazi.kucukOrta).foregroundStyle(renk)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(renk.opacity(0.13), in: Capsule()).overlay(Capsule().strokeBorder(renk.opacity(0.5)))
        }
        .buttonStyle(.plain)
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
        // "Sıradakine geç" açıksa bir sonraki meme açılır
        let liste = depo.veri.seriler.first { $0.id == seriId }?.memeler ?? []
        if siradakine, let j = liste.firstIndex(where: { $0.id == m.id }), j + 1 < liste.count {
            secilenMeme = MemeSecimi(meme: liste[j + 1])
        } else {
            secilenMeme = nil
        }
    }

    /// Sonuç sayısını yaz; tutan/çıkan değişince meme listesi de boyutlanır.
    private func sayiYaz(_ alan: SayiAlani, _ n: Int?) {
        depo.degistir { v in
            var l = v.seriler
            guard let i = l.firstIndex(where: { $0.id == seriId }) else { return }
            var x = l[i]
            switch alan {
            case .asilanan: x.grafted = n.map { Double($0) }
            case .tutan: x.accepted = n.map { Double($0) }
            case .cikan: x.emerged = n.map { Double($0) }
            }
            if alan != .asilanan {
                let c = x.emerged.map { Int($0) }
                x.memeler = memeleriBoyutla(x.memeler, tutan: x.accepted.map { Int($0) } ?? 0, cikan: (c ?? 0) > 0 ? c : nil)
            }
            x.sold = Double(x.memeler.filter { $0.status == "satildi" }.count)
            l[i] = x
            v.seriler = l
        }
    }

    private func topluYaz(_ d: String) {
        depo.degistir { v in
            var l = v.seriler
            guard let i = l.firstIndex(where: { $0.id == seriId }) else { return }
            var mm = l[i].memeler
            for j in mm.indices where (mm[j].status ?? "pending") == "pending" { mm[j].status = d; mm[j].targetHive = "" }
            l[i].memeler = mm
            l[i].sold = Double(mm.filter { $0.status == "satildi" }.count)
            v.seriler = l
        }
        topluDurum = nil
    }
}

enum SayiAlani: String, Identifiable {
    case asilanan, tutan, cikan
    var id: String { rawValue }
}

/// Ayrıntıdan tek sayıyı (aşılanan/tutan/çıkan) hızlıca düzeltme penceresi.
struct SayiPenceresi: View {
    @Environment(\.dismiss) private var kapat
    let baslik: String
    let ilk: Int?
    let hizli: [Int]
    let aciklama: String?
    let kaydet: (Int?) -> Void
    @State private var deger = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(baslik).font(Yazi.kartBaslik).foregroundStyle(Renk.metin)
            if let aciklama { Text(aciklama).font(Yazi.kucuk).foregroundStyle(Renk.metin3) }
            SayiGirisi(etiket: "Sayı", deger: $deger, hizli: hizli)
            HStack(spacing: 10) {
                Button { kapat() } label: {
                    Text("Vazgeç").font(Yazi.govdeOrta).foregroundStyle(Renk.metin).frame(maxWidth: .infinity, minHeight: 48).background(Renk.krem2, in: Capsule())
                }
                Button { kaydet(Int(deger)); kapat() } label: {
                    Text("Kaydet").font(Yazi.govdeOrta).foregroundStyle(Renk.acikBal).frame(maxWidth: .infinity, minHeight: 48).background(Renk.orman2, in: Capsule())
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Renk.kart)
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.visible)
        .onAppear { deger = ilk.flatMap { $0 > 0 ? String($0) : nil } ?? "" }
    }
}

/// Meme durumu: renkli büyük düğmeler; kovana aktarırken kovan listesi aynı pencerede açılır. Seçince (isteğe bağlı) sıradaki meme.
struct MemeDurumPenceresi: View {
    @Environment(VeriDeposu.self) private var depo
    let baslik: String
    let sira: Int
    let toplam: Int
    let durum: String
    let durumMetni: String
    let hedef: String?
    @Binding var siradakine: Bool
    let sec: (String, String?) -> Void
    @State private var kovanListesi = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(baslik).font(Yazi.kartBaslik).foregroundStyle(Renk.metin)
                Spacer()
                Text("\(sira) / \(toplam)").font(Yazi.kucuk).foregroundStyle(Renk.metin3)
            }
            if kovanListesi {
                Button { kovanListesi = false } label: { Label("Geri", systemImage: "chevron.left").font(Yazi.kucukOrta).foregroundStyle(Renk.orman2) }.buttonStyle(.plain)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(kovanlar, id: \.id) { k in
                            Button { sec("kovana_aktarildi", k.id) } label: {
                                HStack(spacing: 10) {
                                    Image(k.gorselAdi).resizable().scaledToFit().frame(width: 34, height: 34)
                                    Text("Kovan \(k.num)").font(Yazi.govdeOrta).foregroundStyle(Renk.metin)
                                    Text(k.anaDurumMetni).font(Yazi.kucuk).foregroundStyle(k.sorunlu ? Renk.kotu : Renk.metin2)
                                    Spacer()
                                    if k.id == hedef { Image(systemName: "checkmark").foregroundStyle(Renk.orman2) }
                                }
                                .padding(.vertical, 7).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
            } else {
                Text("Şu an: \(durumMetni)").font(Yazi.kucuk).foregroundStyle(renk(durum))
                secenek("crown.fill", "Kovana aktarıldı…", "kovana_aktarildi") { kovanListesi = true }
                secenek("cart.fill", "Satıldı", "satildi") { sec("satildi", nil) }
                secenek("xmark", "Öldü / başarısız", "oldu") { sec("oldu", nil) }
                secenek("hourglass", "Bekliyor", "pending") { sec("pending", nil) }
                Button { siradakine.toggle() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: siradakine ? "checkmark.circle.fill" : "circle").foregroundStyle(siradakine ? Renk.orman2 : Renk.metin3)
                        Text("Seçince sıradaki memeye geç").font(Yazi.kucuk).foregroundStyle(Renk.metin2)
                    }
                }
                .buttonStyle(.plain).padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Renk.kart)
        .presentationDetents(kovanListesi ? [.large] : [.height(440)])
        .presentationDragIndicator(.visible)
    }

    private var kovanlar: [Kovan] {
        depo.veri.kovanlar.filter { !$0.arisiz }.sorted {
            let o1 = $0.sorunlu ? 0 : ["bakire", "new", "meme"].contains($0.queenStatus ?? "") ? 1 : 2
            let o2 = $1.sorunlu ? 0 : ["bakire", "new", "meme"].contains($1.queenStatus ?? "") ? 1 : 2
            return (o1, $0.numara) < (o2, $1.numara)
        }
    }

    private func renk(_ d: String) -> Color {
        switch d { case "kovana_aktarildi": return Renk.iyi; case "satildi": return Renk.bilgi; case "oldu": return Renk.kotu; default: return Renk.uyari }
    }

    private func secenek(_ simge: String, _ ad: String, _ d: String, _ f: @escaping () -> Void) -> some View {
        let r = renk(d)
        let secili = durum == d
        return Button(action: f) {
            HStack(spacing: 12) {
                Image(systemName: simge).font(.system(size: 18, weight: .semibold)).foregroundStyle(r).frame(width: 24)
                Text(ad).font(Yazi.govdeOrta).foregroundStyle(Renk.metin)
                Spacer()
            }
            .padding(.horizontal, 14).frame(minHeight: 52)
            .background(r.opacity(secili ? 0.28 : 0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(r.opacity(secili ? 0.9 : 0.4), lineWidth: secili ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
