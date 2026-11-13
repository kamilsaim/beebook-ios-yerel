import AriCekirdek
import SwiftUI

enum SatisBolum: Hashable { case satislar, stok }

/// Bir müşteri kartı = aynı `batchId` grubundaki satırlar (yoksa tek satır).
struct MusteriKarti: Identifiable {
    let id: String
    let satirlar: [Satis]
    var musteri: String { satirlar.first?.customer?.isEmpty == false ? satirlar.first!.customer! : "Müşteri" }
    var telefon: String? { satirlar.compactMap(\.phone).first { !$0.isEmpty } }
    var tarih: String { satirlar.compactMap(\.date).max() ?? "" }
    var toplam: Double { satirlar.reduce(0) { $0 + ($1.total ?? 0) } }
    var kalanTutar: Double { satirlar.reduce(0) { $0 + kalan($1.ham) } }
    var odeme: String { satirlar.first?.payment ?? "paid" }
    var onSiparis: Bool { satirlar.contains { $0.orderStatus == "preorder" } }
}

func musteriKartlari(_ satislar: [Satis]) -> [MusteriKarti] {
    var sira: [String] = []
    var g: [String: [Satis]] = [:]
    for s in satislar {
        let k = s.batchId?.isEmpty == false ? "b:" + s.batchId! : "s:" + s.id
        if g[k] == nil { sira.append(k) }
        g[k, default: []].append(s)
    }
    return sira.map { MusteriKarti(id: $0, satirlar: g[$0]!) }.sorted { $0.tarih > $1.tarih }
}

struct SatisEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(MenuDurumu.self) private var menu
    @State private var bolum: SatisBolum = .satislar
    @State private var filtre = "tumu"
    @State private var arama = ""
    @State private var yeniSatis = false
    @State private var duzenlenen: String?
    @State private var rapor = false
    @State private var silinecek: MusteriKarti?
    @State private var odemeAlinacak: MusteriKarti?
    @Environment(\.openURL) private var ac

    var body: some View {
        List {
            baslik
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .modifier(InceltmeIzleyici(durum: menu))
            if bolum == .satislar { satislarBolumu } else {
                StokGorunumu()
                    .listRowInsets(EdgeInsets(top: 12, leading: Olcu.kenar, bottom: 0, trailing: Olcu.kenar))
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            Color.clear.frame(height: Olcu.altCubukPayi).listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Renk.orman.ignoresSafeArea())
        .coordinateSpace(name: "kaydirma")
        .environment(\.defaultMinListRowHeight, 0)
        .overlay(alignment: .bottomTrailing) {
            if bolum == .satislar {
                Button { yeniSatis = true } label: {
                    Label("Satış", systemImage: "plus").font(Yazi.nunito(15, .bold))
                        .padding(.horizontal, 20).frame(height: 52)
                        .background(Renk.bal, in: Capsule()).foregroundStyle(Renk.ormanKoyu)
                        .shadow(color: .black.opacity(0.45), radius: 10, y: 8)
                }
                .padding(.trailing, 18).padding(.bottom, 106)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $yeniSatis) { SatisFormu(satisId: nil) }
        .sheet(item: Binding(get: { duzenlenen.map { KimlikKutusu(id: $0) } }, set: { duzenlenen = $0?.id })) { SatisFormu(satisId: $0.id) }
        .sheet(isPresented: $rapor) { SatisRaporuSayfasi() }
        .confirmationDialog("\(silinecek?.musteri ?? "") satışı silinsin mi?", isPresented: Binding(get: { silinecek != nil }, set: { if !$0 { silinecek = nil } }), titleVisibility: .visible) {
            Button("Sil", role: .destructive) { if let k = silinecek { sil(k) }; silinecek = nil }
        } message: { Text("Bağlı stok çıkışı da silinir.") }
        .confirmationDialog("Ödeme alındı mı?", isPresented: Binding(get: { odemeAlinacak != nil }, set: { if !$0 { odemeAlinacak = nil } }), titleVisibility: .visible) {
            Button("Tümü ödendi (\(tl(odemeAlinacak?.kalanTutar ?? 0)))") { if let k = odemeAlinacak { odendi(k) }; odemeAlinacak = nil }
            Button("Kısmi ödeme gir…") { if let k = odemeAlinacak { duzenlenen = k.satirlar.first?.id }; odemeAlinacak = nil }
        }
        .onChange(of: menu.yeniSatisIstegi) { _, _ in bolum = .satislar; yeniSatis = true }
    }

    private var baslik: some View {
        let sezon = depo.sezonda(depo.veri.satislar)
        return ManzaraBasligi(gorsel: "ArkaPetek") {
            HStack { Marka(kucuk: true); Spacer(); CamDugme(simge: "chart.bar") { rapor = true }.accessibilityLabel("Satış raporu") }
            BuyukBaslik(metin: "Satış", alt: "\(sezon.count) satış · \(tl(sezon.reduce(0) { $0 + ($1.total ?? 0) }))")
            Segment(secenekler: [(SatisBolum.satislar, "Satışlar"), (.stok, "Stok")], secili: $bolum).padding(.top, 12)
        }
    }

    @ViewBuilder
    private var satislarBolumu: some View {
        let sezon = depo.sezonda(depo.veri.satislar)
        let kartlar = musteriKartlari(sezon)
        let bekleyen = kartlar.filter { $0.kalanTutar > 0 }
        Group {
            if !bekleyen.isEmpty {
                Button { filtre = "bekleyen" } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bekleyen ödemeler").font(Yazi.govdeOrta)
                            Text("\(bekleyen.count) müşteri · kaydır, tahsil et").font(Yazi.etiket).foregroundStyle(Renk.metin3)
                        }
                        Spacer()
                        Text(tl(bekleyen.reduce(0) { $0 + $1.kalanTutar })).font(Yazi.nunito(19, .bold)).foregroundStyle(Renk.kotu)
                    }
                    .padding(14)
                    .background(LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.8), Color(red: 1, green: 0.89, blue: 0.63)], startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .foregroundStyle(Renk.metin)
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    cip("tumu", "Tümü \(kartlar.count)")
                    cip("bekleyen", "Bekleyen \(bekleyen.count)")
                    cip("onsiparis", "Ön sipariş \(kartlar.filter(\.onSiparis).count)")
                    cip("hediye", "Hediye/Zekat")
                }
            }
            .scrollIndicators(.hidden)
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color(white: 0.8))
                TextField("", text: $arama, prompt: Text("Müşteri ya da ürün ara").foregroundStyle(Color(white: 0.75))).foregroundStyle(.white)
            }
            .padding(.horizontal, 12).frame(height: 40)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .listRowInsets(EdgeInsets(top: 10, leading: Olcu.kenar, bottom: 0, trailing: Olcu.kenar))
        .listRowBackground(Color.clear).listRowSeparator(.hidden)

        let gosterilen = suz(kartlar)
        if gosterilen.isEmpty {
            BosDurum(simge: "cart", baslik: kartlar.isEmpty ? "Bu sezon satış yok" : "Eşleşen satış yok", alt: kartlar.isEmpty ? "＋ Satış ile ilk satışını kaydet." : nil)
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
        ForEach(gosterilen) { k in
            MusteriKartiGorunumu(kart: k, urunler: depo.urunler)
                .contentShape(Rectangle())
                .onTapGesture { duzenlenen = k.satirlar.first?.id }
                .listRowInsets(EdgeInsets(top: 10, leading: Olcu.kenar, bottom: 0, trailing: Olcu.kenar))
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { silinecek = k } label: { Label("Sil", systemImage: "trash") }
                    if k.kalanTutar > 0 {
                        Button { odemeAlinacak = k } label: { Label("Ödeme al", systemImage: "turkishlirasign.circle") }.tint(Renk.uyari)
                    }
                    if k.onSiparis {
                        Button { teslimEt(k) } label: { Label("Teslim et", systemImage: "checkmark.circle") }.tint(Renk.iyi)
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    if let t = k.telefon {
                        Button { ara(t) } label: { Label("Ara", systemImage: "phone.fill") }.tint(Renk.bilgi)
                        Button { whatsapp(t, k) } label: { Label("WhatsApp", systemImage: "message.fill") }.tint(Color(red: 0.15, green: 0.64, blue: 0.35))
                    }
                }
        }
        if !gosterilen.isEmpty {
            Text("Sola kaydır: teslim et, ödeme al, sil · Sağa kaydır: ara, WhatsApp")
                .font(Yazi.etiket).foregroundStyle(Color(white: 0.7)).frame(maxWidth: .infinity)
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
    }

    private func suz(_ k: [MusteriKarti]) -> [MusteriKarti] {
        var l = k
        switch filtre {
        case "bekleyen": l = l.filter { $0.kalanTutar > 0 }
        case "onsiparis": l = l.filter(\.onSiparis)
        case "hediye": l = l.filter { ["hediye", "zekat"].contains($0.odeme) }
        default: break
        }
        let a = arama.trimmingCharacters(in: .whitespaces).lowercased()
        if !a.isEmpty {
            l = l.filter { $0.musteri.lowercased().contains(a) || $0.satirlar.contains { $0.urunAdi(urunler: depo.urunler).lowercased().contains(a) || ($0.note ?? "").lowercased().contains(a) } }
        }
        return l
    }

    private func cip(_ id: String, _ ad: String) -> some View {
        Button { filtre = filtre == id ? "tumu" : id } label: {
            Text(ad).font(Yazi.kucukOrta).padding(.horizontal, 13).frame(height: 34)
                .foregroundStyle(filtre == id ? Renk.orman : Color(white: 0.9))
                .background(filtre == id ? Renk.krem : .white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func guncelle(_ k: MusteriKarti, _ f: @escaping (inout Satis) -> Void) {
        let idler = Set(k.satirlar.map(\.id))
        depo.degistir { v in
            var l = v.satislar
            for i in l.indices where idler.contains(l[i].id) { f(&l[i]) }
            v.satislar = l
        }
    }

    private func teslimEt(_ k: MusteriKarti) { guncelle(k) { $0.orderStatus = "delivered" } }

    /// Web markSalePaid: payment → paid, paidAmount silinir.
    private func odendi(_ k: MusteriKarti) {
        guncelle(k) { s in
            if s.payment == "pending" || s.payment == "partial" { s.payment = "paid"; s.paidAmount = nil }
        }
    }

    private func sil(_ k: MusteriKarti) {
        let idler = Set(k.satirlar.map(\.id))
        depo.degistir { v in
            v.satislar = v.satislar.filter { !idler.contains($0.id) }
            for id in idler { bagliStokuSil(&v, saleId: id) }
        }
    }

    private func temizTel(_ t: String) -> String {
        var d = t.filter(\.isNumber)
        if d.hasPrefix("0") { d = "90" + d.dropFirst() } else if d.count == 10 { d = "90" + d }
        return d
    }
    private func ara(_ t: String) { if let u = URL(string: "tel:\(t.filter { $0.isNumber || $0 == "+" })") { ac(u) } }
    private func whatsapp(_ t: String, _ k: MusteriKarti) {
        var mesaj = "Merhaba \(k.musteri),"
        if k.kalanTutar > 0 { mesaj += " \(tl(k.kalanTutar)) tutarındaki ödemenizi hatırlatmak isteriz." }
        let m = mesaj.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let u = URL(string: "https://wa.me/\(temizTel(t))?text=\(m)") { ac(u) }
    }
}

struct MusteriKartiGorunumu: View {
    let kart: MusteriKarti
    let urunler: [UrunTanimi]
    private static let renkler: [Color] = [Renk.orman2, Color(red: 0.6, green: 0.42, blue: 0.23), Renk.bilgi, Renk.kotu, Renk.mor, Renk.uyari]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(basHarf).font(Yazi.nunito(15, .semibold)).foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Self.renkler[kart.musteri.unicodeScalars.reduce(0) { $0 + Int($1.value) } % Self.renkler.count], in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(kart.musteri).font(Yazi.nunito(16, .bold))
                Text("\(kisaTarih(kart.tarih)) · \(kart.satirlar.count > 1 ? "\(kart.satirlar.count) ürün" : kart.onSiparis ? "ön sipariş" : "teslim edildi")")
                    .font(Yazi.etiket).foregroundStyle(Renk.metin3)
                ForEach(kart.satirlar, id: \.id) { s in
                    HStack(spacing: 6) {
                        UrunGorseli(urun: urunler.first { $0.v == satisStokUrunu(s) }, boyut: 22, yaricap: 6)
                        Text(s.etiket(urunler: urunler)).font(Yazi.kucuk).foregroundStyle(Renk.metin2)
                    }
                }
                .padding(.top, 3)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text(tl(kart.toplam)).font(Yazi.nunito(16, .bold))
                rozet
            }
        }
        .padding(12)
        .background(Renk.krem, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .foregroundStyle(Renk.metin)
        .accessibilityElement(children: .combine)
    }

    private var basHarf: String {
        let p = kart.musteri.split(separator: " ").prefix(2).compactMap(\.first)
        return String(p).uppercased(with: Locale(identifier: "tr"))
    }

    @ViewBuilder
    private var rozet: some View {
        switch kart.odeme {
        case "hediye": Rozet(metin: "Hediye", tur: .bilgi)
        case "zekat": Rozet(metin: "Zekat", tur: .mor)
        case "partial": Rozet(metin: "\(tl(kart.kalanTutar)) kaldı", tur: .uyari)
        case "pending": Rozet(metin: "Bekliyor", tur: .kotu)
        default: if kart.onSiparis { Rozet(metin: "Ön sipariş", tur: .uyari) } else { Rozet(metin: "Ödendi", tur: .iyi) }
        }
    }
}
