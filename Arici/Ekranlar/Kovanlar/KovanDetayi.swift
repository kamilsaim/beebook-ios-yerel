import AriCekirdek
import SwiftUI

struct KovanDetayi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var geri
    let kovanId: String
    @State private var duzenle = false
    @State private var muayene = false

    var body: some View {
        if let k = depo.kovan(kovanId) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button { geri() } label: {
                            Label("Kovanlar", systemImage: "chevron.left").font(Yazi.govdeOrta).foregroundStyle(Renk.bal)
                        }
                        Spacer()
                        CamDugme(simge: "pencil") { duzenle = true }
                    }
                    HStack(alignment: .bottom, spacing: 12) {
                        Image(k.gorselAdi).resizable().scaledToFit().frame(width: 128, height: 128)
                            .shadow(color: .black.opacity(0.45), radius: 10, y: 10)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kovan \(k.num)").font(Yazi.nunito(28, .bold)).foregroundStyle(Renk.krem)
                            Text([k.type, "\(k.katSayisi) kat", k.frames.map { "\(Int($0)) çerçeve" }].compactMap { $0 }.joined(separator: " · "))
                                .font(Yazi.kucuk).foregroundStyle(Color(white: 0.8))
                            if let g = k.gucMetni { Rozet(metin: g, tur: g == "Zayıf" ? .kotu : g == "Orta" ? .uyari : .iyi) }
                        }
                    }
                    anaKarti(k)
                    eylemler(k)
                    muayeneKarti(k)
                    if let n = k.notes, !n.isEmpty {
                        Kart { KartBasligi(baslik: "Notlar"); Text(n).font(Yazi.govde) }
                    }
                }
                .padding(.horizontal, Olcu.kenar)
                .padding(.bottom, Olcu.altCubukPayi)
            }
            .scrollIndicators(.hidden)
            .background(LinearGradient(colors: [Renk.orman, Color(red: 0.04, green: 0.19, blue: 0.15)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $duzenle) { KovanFormu(kovanId: k.id) }
            .sheet(isPresented: $muayene) { MuayeneFormu(kovanId: k.id) }
        } else {
            BosDurum(simge: "archivebox", baslik: "Kovan silindi").onAppear { geri() }
        }
    }

    private func anaKarti(_ k: Kovan) -> some View {
        let seri = depo.veri.seriler.first { s in s.memeler.contains { $0.targetHive == k.id } }
        return Kart {
            HStack(spacing: 12) {
                Image("UrunAnaari").resizable().scaledToFill().frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("ANA ARI").font(Yazi.minik).foregroundStyle(Renk.metin3)
                    HStack(spacing: 7) {
                        Text(k.anaDurumMetni).font(Yazi.nunito(19, .bold))
                        if k.anaNoktasiGoster { AnaNoktasi(renk: k.queenColor) }
                    }
                }
                Spacer()
                Rozet(metin: k.sorunlu ? "Müdahale" : k.yasliAna ? "Değişim önerilir" : "Sağlıklı",
                      tur: k.sorunlu ? .kotu : k.yasliAna ? .uyari : .iyi)
            }
            Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                GridRow { hucre("Irk", k.race); hucre("Kuşak", k.generation) }
                GridRow {
                    hucre("Ana yılı", k.year.map { y in Int(y).map { "\(y) · \(renkAdi(anaRengi(yil: $0)))" } ?? y })
                    hucre("Kaynak", seri?.name)
                }
            }
            .background(Renk.krem2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 4)
        }
    }

    private func hucre(_ e: String, _ d: String?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(e.uppercased(with: Locale(identifier: "tr"))).font(Yazi.minik).foregroundStyle(Renk.metin3)
            Text((d?.isEmpty == false ? d : nil) ?? "—").font(Yazi.govdeOrta)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11).padding(.vertical, 9)
        .background(Renk.kart)
    }

    private func renkAdi(_ k: String) -> String {
        ["white": "beyaz", "yellow": "sarı", "red": "kırmızı", "green": "yeşil", "blue": "mavi"][k] ?? k
    }

    private func eylemler(_ k: Kovan) -> some View {
        HStack(spacing: 8) {
            eylem("DurumDuzenle", "Muayene") { muayene = true }
            eylem("DurumKatEkle", "Kat ekle") { katDegistir(k, 1) }.disabled(k.katSayisi >= 4)
            eylem("DurumKatCikar", "Kat çıkar") { katDegistir(k, -1) }.disabled(k.katSayisi <= 1)
            eylem("IkonArazi", "Düzenle") { duzenle = true }
        }
    }

    private func eylem(_ g: String, _ ad: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            VStack(spacing: 4) {
                Image(g).resizable().scaledToFit().frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(ad).font(Yazi.etiket).foregroundStyle(Renk.krem)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func katDegistir(_ k: Kovan, _ d: Int) {
        depo.degistir { v in
            var l = v.kovanlar
            if let i = l.firstIndex(where: { $0.id == k.id }) { l[i].floors = Double(max(1, min(4, k.katSayisi + d))); v.kovanlar = l }
        }
    }

    private func muayeneKarti(_ k: Kovan) -> some View {
        let liste = depo.veri.muayeneler.filter { $0.hiveId == k.id }.sorted { ($0.date ?? "") > ($1.date ?? "") }
        return Kart {
            KartBasligi(baslik: "Muayeneler", baglanti: "＋ Yeni") { muayene = true }
            if liste.isEmpty {
                Text("Henüz muayene kaydı yok.").font(Yazi.kucuk).foregroundStyle(Renk.metin3)
            }
            ForEach(liste.prefix(6), id: \.id) { m in
                VStack(alignment: .leading, spacing: 2) {
                    Text(kisaTarih(m.date ?? "")).font(Yazi.kucukOrta)
                    Text(muayeneOzeti(m)).font(Yazi.kucuk).foregroundStyle(Renk.metin2)
                    if let n = m.note, !n.isEmpty { Text(n).font(Yazi.kucuk).foregroundStyle(Renk.metin3) }
                }
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Divider().overlay(Renk.krem2) }
                .contextMenu {
                    Button(role: .destructive) { depo.degistir { v in v.muayeneler = v.muayeneler.filter { $0.id != m.id } } } label: { Label("Sil", systemImage: "trash") }
                }
            }
        }
    }
}

func muayeneOzeti(_ m: Muayene) -> String {
    var p: [String] = []
    if let q = m.queenSeen { p.append(q ? "Ana görüldü" : "Ana görülmedi") }
    if m.eggs == true { p.append("Yumurta var") }
    if let b = m.brood { p.append("Yavru: " + (["duzenli": "düzenli", "seyrek": "seyrek", "yok": "yok"][b] ?? b)) }
    if let s = m.strength, let g = Int(s) { p.append("Güç: \(g >= 4 ? "güçlü" : g == 3 ? "orta" : "zayıf")") }
    if let f = m.feeding, !f.isEmpty { p.append("Besleme: \(f)") }
    return p.joined(separator: " · ")
}

/// Muayene formu (v2.7.0 `inspections`). Güç kovanın 1–5 ölçeğiyle; kovanın gücünü de günceller.
struct MuayeneFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let kovanId: String
    @State private var tarih = Date()
    @State private var anaGoruldu = true
    @State private var yumurta = true
    @State private var yavru = "duzenli"
    @State private var guc = 4
    @State private var besleme = ""
    @State private var not = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Tarih", selection: $tarih, displayedComponents: .date)
                Section("Ana arı") {
                    Toggle("Ana görüldü", isOn: $anaGoruldu)
                    Toggle("Yumurta / genç larva", isOn: $yumurta)
                }
                Section("Koloni") {
                    Picker("Yavru", selection: $yavru) {
                        Text("Düzenli").tag("duzenli"); Text("Seyrek").tag("seyrek"); Text("Yok").tag("yok")
                    }
                    .pickerStyle(.segmented)
                    Stepper("Güç: \(guc)/5 · \(guc >= 4 ? "güçlü" : guc == 3 ? "orta" : "zayıf")", value: $guc, in: 1...5)
                }
                Section("Besleme ve not") {
                    TextField("Besleme (ör. 1 lt şurup)", text: $besleme)
                    TextField("Not", text: $not, axis: .vertical)
                }
            }
            .navigationTitle("Muayene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { kaydet(); kapat() } }
            }
        }
    }

    private func kaydet() {
        let g = String(guc)
        depo.degistir { v in
            var m = Muayene(["id": .metin(yeniKimlik())])
            m.hiveId = kovanId
            m.date = bugunISO(tarih)
            m.queenSeen = anaGoruldu
            m.eggs = yumurta
            m.brood = yavru
            m.strength = g
            m.feeding = besleme.isEmpty ? nil : besleme
            m.note = not.isEmpty ? nil : not
            v.muayeneler = v.muayeneler + [m]
            var l = v.kovanlar
            if let i = l.firstIndex(where: { $0.id == kovanId }) { l[i].strength = g; v.kovanlar = l }
        }
    }
}
