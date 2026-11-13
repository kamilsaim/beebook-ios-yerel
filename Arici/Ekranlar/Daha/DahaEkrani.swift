import AriCekirdek
import SwiftUI

enum DahaSayfa: String, Hashable, CaseIterable {
    case ariSutu, envanter, giderler, raporlar, sezonlar, hava, yedek, arazi, ayarlar
    var ad: String {
        switch self {
        case .ariSutu: return "Arı Sütü"
        case .envanter: return "Envanter"
        case .giderler: return "Giderler"
        case .raporlar: return "Raporlar"
        case .sezonlar: return "Sezonlar"
        case .hava: return "Hava"
        case .yedek: return "Yedek"
        case .arazi: return "Arazi"
        case .ayarlar: return "Ayarlar"
        }
    }
    var gorsel: String {
        switch self {
        case .ariSutu: return "IkonAriSutu"
        case .envanter: return "IkonEnvanter"
        case .giderler: return "DurumDuzenle"
        case .raporlar: return "IkonRaporlar"
        case .sezonlar: return "IkonSezon"
        case .hava: return "IkonHava"
        case .yedek: return "IkonCevrimdisi"
        case .arazi: return "IkonArazi"
        case .ayarlar: return "DurumPasif"
        }
    }
}

let varsayilanGiderTurleri: [(String, String)] = [("yem", "🌾 Yem"), ("seker", "🍬 Şeker"), ("ilac", "💊 İlaç / Varroa"), ("mazot", "⛽ Mazot / Yakıt"), ("ekipman", "🔧 Ekipman"), ("diger", "📦 Diğer")]

extension VeriDeposu {
    /// `{v, l}` gider türleri (web getExpenseTypes).
    var giderTurleri: [(v: String, l: String)] {
        if let l = ayarlar.expenseTypes, !l.isEmpty {
            return l.compactMap { k in k["v"]?.metinDegeri.map { ($0, k["l"]?.metinDegeri ?? $0) } }
        }
        return varsayilanGiderTurleri.map { (v: $0.0, l: $0.1) }
    }
    func giderTurAdi(_ v: String?) -> String {
        guard let v else { return "Gider" }
        return giderTurleri.first { $0.v == v }?.l ?? v
    }
}

struct DahaEkrani: View {
    @Environment(MenuDurumu.self) private var menu
    @State private var yol = NavigationPath()

    var body: some View {
        NavigationStack(path: $yol) {
            SekmeKaydirma {
                ManzaraBasligi(gorsel: "ArkaDag") {
                    HStack { Marka(kucuk: true); Spacer() }
                    BuyukBaslik(metin: "Daha", alt: "Diğer bölümler ve ayarlar")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 16) {
                    ForEach(DahaSayfa.allCases, id: \.self) { s in
                        Button {
                            if s == .arazi { menu.git(.kovanlar); menu.araziIstegi += 1 } else { yol.append(s) }
                        } label: {
                            VStack(spacing: 6) {
                                Image(s.gorsel).resizable().scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .shadow(color: Renk.bal.opacity(0.3), radius: 8)
                                Text(s.ad).font(Yazi.kucukOrta).foregroundStyle(Renk.krem)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Olcu.kenar)
                .padding(.top, 14)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: DahaSayfa.self) { s in
                Group {
                    switch s {
                    case .ariSutu: AriSutuEkrani()
                    case .envanter: EnvanterEkrani()
                    case .giderler: GiderlerEkrani()
                    case .raporlar: RaporlarEkrani()
                    case .sezonlar: SezonlarEkrani()
                    case .hava: HavaEkrani()
                    case .yedek: YedekEkrani()
                    case .ayarlar: AyarlarEkrani()
                    case .arazi: EmptyView()
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Renk.orman.ignoresSafeArea())
                .navigationTitle(s.ad)
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(Renk.orman, for: .navigationBar)
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 90) }
            }
        }
    }
}

// MARK: - Arı sütü

struct AriSutuEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var form: KimlikKutusu?
    var body: some View {
        let hasatlar = depo.sezonda(depo.veri.hasatlar).sorted { ($0.date ?? "") > ($1.date ?? "") }
        List {
            Section {
                HStack { Text("Sezon toplamı"); Spacer(); Text(miktar(hasatlar.reduce(0) { $0 + ($1.amount ?? 0) }, "gr")).bold() }
                HStack { Text("Stokta"); Spacer(); Text(miktar(stokSeviyesi(depo.veri, urun: "ari_sutu"), "gr")) }
            }
            Section("Hasatlar") {
                if hasatlar.isEmpty { Text("Bu sezon hasat yok").foregroundStyle(.secondary) }
                ForEach(hasatlar, id: \.id) { h in
                    Button { form = KimlikKutusu(id: h.id) } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(miktar(h.amount ?? 0, "gr")).bold()
                                Text([kisaTarih(h.date ?? ""), h.hiveCount.map { "\(Int($0)) kovan" }, h.note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { idx in
                    let silinen = idx.map { hasatlar[$0].id }
                    depo.degistir { v in
                        v.hasatlar = v.hasatlar.filter { !silinen.contains($0.id) }
                        for id in silinen { hasatStokunuSil(&v, milkId: id) }
                    }
                }
            }
        }
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { form = KimlikKutusu(id: "") } label: { Image(systemName: "plus") } } }
        .sheet(item: $form) { HasatFormu(hasatId: $0.id.isEmpty ? nil : $0.id) }
    }
}

struct HasatFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let hasatId: String?
    @State private var miktarD: Double = 0
    @State private var tarih = Date()
    @State private var kovan: Double = 0
    @State private var not = ""
    var body: some View {
        NavigationStack {
            Form {
                HStack { Text("Miktar"); TextField("gr", value: $miktarD, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing); Text("gr").foregroundStyle(.secondary) }
                DatePicker("Tarih", selection: $tarih, displayedComponents: .date)
                HStack { Text("Kovan sayısı"); TextField("0", value: $kovan, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                TextField("Not", text: $not)
            }
            .navigationTitle(hasatId == nil ? "Yeni Hasat" : "Hasat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        depo.degistir { v in
                            var l = v.hasatlar
                            let i = l.firstIndex { $0.id == hasatId }
                            var h = i.map { l[$0] } ?? Hasat(["id": .metin(yeniKimlik())])
                            h.amount = miktarD; h.date = bugunISO(tarih); h.hiveCount = kovan > 0 ? kovan : nil; h.note = not
                            if let i { l[i] = h } else { l.append(h) }
                            v.hasatlar = l
                            // Bağsız eski hasatlarda stoğa dokunulmaz (web v2.6.10)
                            if i == nil || v.stokKayitlari.contains(where: { $0.milkId == h.id }) { hasatStokunuYaz(&v, hasat: h, kimlik: { yeniKimlik() }) }
                        }
                        kapat()
                    }
                    .disabled(miktarD <= 0)
                }
            }
            .onAppear {
                if let h = depo.veri.hasatlar.first(where: { $0.id == hasatId }) {
                    miktarD = h.amount ?? 0; tarih = isoTarih(h.date) ?? Date(); kovan = h.hiveCount ?? 0; not = h.note ?? ""
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Envanter

struct EnvanterEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var form: KimlikKutusu?
    private let durumlar = [("saglam", "Sağlam", RozetTuru.iyi), ("tamir", "Tamirde", .uyari), ("eksik", "Eksik", .kotu)]
    var body: some View {
        let l = depo.veri.envanter
        List {
            Section {
                HStack {
                    ForEach(durumlar, id: \.0) { d in
                        VStack { Text("\(l.filter { ($0.status ?? "saglam") == d.0 }.count)").font(.title3.bold()); Text(d.1).font(.caption) }.frame(maxWidth: .infinity)
                    }
                }
            }
            Section("Malzemeler") {
                if l.isEmpty { Text("Ballık, körük, elbise… ekle").foregroundStyle(.secondary) }
                ForEach(l, id: \.id) { k in
                    Button { form = KimlikKutusu(id: k.id) } label: {
                        HStack {
                            VStack(alignment: .leading) { Text(k.name ?? "").bold(); if let n = k.note, !n.isEmpty { Text(n).font(.caption).foregroundStyle(.secondary) } }
                            Spacer()
                            Text("\(Int(k.qty ?? 0))")
                            let d = durumlar.first { $0.0 == (k.status ?? "saglam") }
                            Rozet(metin: d?.1 ?? "", tur: d?.2 ?? .notr)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { idx in let s = idx.map { l[$0].id }; depo.degistir { v in v.envanter = v.envanter.filter { !s.contains($0.id) } } }
            }
        }
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { form = KimlikKutusu(id: "") } label: { Image(systemName: "plus") } } }
        .sheet(item: $form) { EnvanterFormu(kalemId: $0.id.isEmpty ? nil : $0.id) }
    }
}

struct EnvanterFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let kalemId: String?
    @State private var ad = ""
    @State private var adet: Double = 1
    @State private var durum = "saglam"
    @State private var not = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField("Ad (ör. Ballık)", text: $ad)
                Stepper("Adet: \(Int(adet))", value: $adet, in: 0...9999)
                Picker("Durum", selection: $durum) { Text("Sağlam").tag("saglam"); Text("Tamirde").tag("tamir"); Text("Eksik").tag("eksik") }.pickerStyle(.segmented)
                TextField("Not", text: $not)
            }
            .navigationTitle(kalemId == nil ? "Yeni Malzeme" : "Malzeme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        depo.degistir { v in
                            var l = v.envanter
                            let i = l.firstIndex { $0.id == kalemId }
                            var k = i.map { l[$0] } ?? EnvanterKalemi(["id": .metin(yeniKimlik())])
                            k.name = ad; k.qty = adet; k.status = durum; k.note = not
                            if let i { l[i] = k } else { l.append(k) }
                            v.envanter = l
                        }
                        kapat()
                    }.disabled(ad.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let k = depo.veri.envanter.first(where: { $0.id == kalemId }) { ad = k.name ?? ""; adet = k.qty ?? 1; durum = k.status ?? "saglam"; not = k.note ?? "" }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Giderler

struct GiderlerEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var form: KimlikKutusu?
    var body: some View {
        let g = depo.sezonda(depo.veri.giderler).sorted { ($0.date ?? "") > ($1.date ?? "") }
        List {
            Section("Sezon özeti") {
                HStack { Text("Toplam gider"); Spacer(); Text(tl(g.reduce(0) { $0 + ($1.amount ?? 0) })).bold() }
                ForEach(giderRaporu(g, turler: depo.giderTurleri.map(\.v)), id: \.tur) { r in
                    HStack { Text(depo.giderTurAdi(r.tur)); Spacer(); Text("\(r.adet) · \(tl(r.toplam))").foregroundStyle(.secondary) }
                }
            }
            Section("Kayıtlar") {
                if g.isEmpty { Text("Bu sezon gider yok").foregroundStyle(.secondary) }
                ForEach(g, id: \.id) { k in
                    Button { form = KimlikKutusu(id: k.id) } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(depo.giderTurAdi(k.type)).bold()
                                Text([kisaTarih(k.date ?? ""), k.desc].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(tl(k.amount ?? 0)).bold()
                                if kalan(k.ham) > 0 { Rozet(metin: "\(tl(kalan(k.ham))) kaldı", tur: .uyari) }
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    .swipeActions(edge: .leading) {
                        if kalan(k.ham) > 0 {
                            Button { depo.degistir { v in var l = v.giderler; if let i = l.firstIndex(where: { $0.id == k.id }) { l[i].payment = "paid"; l[i].paidAmount = nil; v.giderler = l } } } label: { Label("Ödendi", systemImage: "checkmark") }.tint(Renk.iyi)
                        }
                    }
                }
                .onDelete { idx in let s = idx.map { g[$0].id }; depo.degistir { v in v.giderler = v.giderler.filter { !s.contains($0.id) } } }
            }
        }
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { form = KimlikKutusu(id: "") } label: { Image(systemName: "plus") } } }
        .sheet(item: $form) { GiderFormu(giderId: $0.id.isEmpty ? nil : $0.id) }
    }
}

struct GiderFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let giderId: String?
    @State private var tur = "yem"
    @State private var tutar: Double = 0
    @State private var tarih = Date()
    @State private var aciklama = ""
    @State private var odeme = "paid"
    @State private var odenen: Double = 0
    var body: some View {
        NavigationStack {
            Form {
                Picker("Tür", selection: $tur) { ForEach(depo.giderTurleri, id: \.v) { Text($0.l).tag($0.v) } }
                HStack { Text("Tutar"); TextField("₺", value: $tutar, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                DatePicker("Tarih", selection: $tarih, displayedComponents: .date)
                TextField("Açıklama", text: $aciklama)
                Picker("Ödeme", selection: $odeme) { Text("Ödendi").tag("paid"); Text("Bekliyor").tag("pending"); Text("Kısmi").tag("partial") }.pickerStyle(.segmented)
                if odeme == "partial" { HStack { Text("Ödenen"); TextField("₺", value: $odenen, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) } }
            }
            .navigationTitle(giderId == nil ? "Yeni Gider" : "Gider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        depo.degistir { v in
                            var l = v.giderler
                            let i = l.firstIndex { $0.id == giderId }
                            var g = i.map { l[$0] } ?? Gider(["id": .metin(yeniKimlik())])
                            g.type = tur; g.amount = tutar; g.date = bugunISO(tarih); g.desc = aciklama; g.payment = odeme
                            g.paidAmount = odeme == "partial" ? odenen : nil
                            if let i { l[i] = g } else { l.append(g) }
                            v.giderler = l
                        }
                        kapat()
                    }.disabled(tutar <= 0)
                }
            }
            .onAppear {
                if let g = depo.veri.giderler.first(where: { $0.id == giderId }) {
                    tur = g.type ?? tur; tutar = g.amount ?? 0; tarih = isoTarih(g.date) ?? Date(); aciklama = g.desc ?? ""
                    odeme = g.payment ?? "paid"; odenen = g.paidAmount ?? 0
                } else { tur = depo.giderTurleri.first?.v ?? "yem" }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
