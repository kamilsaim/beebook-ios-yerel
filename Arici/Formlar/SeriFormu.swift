import AriCekirdek
import SwiftUI

/// Ana arı serisi ekle/düzenle + sonuç girişi (web saveSeries / updateResultQueenList / updateResultEmergedList).
struct SeriFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let seriId: String?

    @State private var ad = ""
    @State private var irk = ""
    @State private var kusak = ""
    @State private var damizlik = ""
    @State private var baslatici = ""
    @State private var transfer = Date()
    @State private var graft = ""
    @State private var tutan = ""
    @State private var cikan = ""
    @State private var durum = "active"
    @State private var not = ""
    @State private var memeler: [Meme] = []
    @State private var yuklendi = false
    @State private var silOnay = false

    var body: some View {
        NavigationStack {
            Form {
                Section { onizleme }.listeBasligi()
                Section(header: Label("Seri", systemImage: "rosette")) {
                    TextField("Seri adı (ör. Seri A-26)", text: $ad)
                    Picker("Damızlık kovan", selection: $damizlik) { Text("—").tag(""); ForEach(kovanlar, id: \.id) { Text("Kovan \($0.num)").tag($0.id) } }
                        .onChange(of: damizlik) { _, id in
                            // Damızlığın ırkı/kuşağı boş alanlara kendiliğinden gelir
                            if let k = depo.kovan(id) {
                                if irk.isEmpty { irk = k.race ?? "" }
                                if kusak.isEmpty { kusak = kusakDuzelt(k.generation) }
                            }
                        }
                    CipSecici(baslik: "Irk", secenekler: (depo.irklar + (irk.isEmpty || depo.irklar.contains(irk) ? [] : [irk])).map { ($0, $0) }, secili: irk) { irk = irk == $0 ? "" : $0 }
                    CipSecici(baslik: "Kuşak", secenekler: (kusakSecenekleri + (kusak.isEmpty || kusakSecenekleri.contains(kusak) ? [] : [kusak])).map { ($0, $0) }, secili: kusak) { kusak = kusak == $0 ? "" : $0 }
                    Picker("Başlatıcı kovan", selection: $baslatici) { Text("—").tag(""); ForEach(kovanlar, id: \.id) { Text("Kovan \($0.num)").tag($0.id) } }
                    DatePicker("Larva transferi", selection: $transfer, displayedComponents: .date)
                    CipSecici(baslik: nil, secenekler: [(0, "Bugün"), (1, "Dün"), (2, "2 gün önce"), (3, "3 gün önce")],
                              secili: (0...3).first { Calendar.current.isDate(transfer, inSameDayAs: Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? Date()) }) {
                        transfer = Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? Date()
                    }
                }
                Section(header: Label("Sonuç", systemImage: "chart.bar"), footer: Text("Sonra seri sayfasından da sayılara dokunup düzeltebilirsin.")) {
                    SayiGirisi(etiket: "Aşılanan", deger: $graft, hizli: [10, 15, 20, 25, 30, 40, 60], alt: "Transfer edilen larva")
                    SayiGirisi(etiket: "Tutan (meme)", deger: $tutan, hizli: tutanOnerileri(Int(graft) ?? 0), alt: (Int(graft) ?? 0) > 0 ? "Hepsi, %90 … %50" : nil)
                    SayiGirisi(etiket: "Çıkan", deger: $cikan, hizli: cikanOnerileri(Int(tutan) ?? 0), alt: "Çıkmayanlar listeden düşer")
                    if let g = Int(graft), let t = Int(tutan), g > 0, t > 0 {
                        HStack { Text("Tutma oranı"); Spacer(); Text("%\(Int((Double(t) * 100 / Double(g)).rounded()))").font(Yazi.nunito(16, .bold)).foregroundStyle(t * 100 / g >= 60 ? Renk.iyi : Renk.uyari) }
                    }
                    Picker("Durum", selection: $durum) { Text("Aktif").tag("active"); Text("Tamamlandı").tag("completed"); Text("Başarısız").tag("failed") }
                        .pickerStyle(.segmented)
                }
                if !memeler.isEmpty {
                    Section(header: Label("Memeler (\(memeler.count))", systemImage: "hexagon")) {
                        ForEach($memeler, id: \.id) { $m in
                            HStack {
                                Text("Meme \(m.num ?? "")").frame(width: 80, alignment: .leading)
                                Picker("", selection: Binding(get: { m.status ?? "pending" }, set: { m.status = $0 })) {
                                    Text("Bekliyor").tag("pending"); Text("Kovana aktarıldı").tag("kovana_aktarildi"); Text("Satıldı").tag("satildi"); Text("Öldü").tag("oldu")
                                }
                            }
                            if m.status == "kovana_aktarildi" {
                                Picker("Hedef kovan", selection: Binding(get: { m.targetHive ?? "" }, set: { m.targetHive = $0 })) {
                                    Text("—").tag(""); ForEach(kovanlar, id: \.id) { Text("Kovan \($0.num)").tag($0.id) }
                                }
                            }
                        }
                    }
                }
                Section(header: Label("Not", systemImage: "note.text")) { TextField("Not", text: $not, axis: .vertical) }
                if seriId != nil { Section { Button("Seriyi sil", role: .destructive) { silOnay = true } } }
            }
            .navigationTitle(seriId == nil ? "Yeni Seri" : "Seri")
            .formArkaplani(klavye: false)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { memeListesiniGuncelle(); kaydet(); kapat() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Bitti") { memeListesiniGuncelle(); UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
            }
            .safeAreaInset(edge: .bottom) { BuyukKaydetCubugu { memeListesiniGuncelle(); kaydet(); kapat() } }
            .confirmationDialog("Seri silinsin mi?", isPresented: $silOnay, titleVisibility: .visible) {
                Button("Sil", role: .destructive) { depo.degistir { v in v.seriler = v.seriler.filter { $0.id != seriId } }; kapat() }
            }
            .onAppear(perform: yukle)
        }
    }

    private var kovanlar: [Kovan] { depo.veri.kovanlar.sorted { $0.numara < $1.numara } }


    /// Canlı önizleme: ad, ırk · kuşak, çıkım tarihi ve durum.
    private var onizleme: some View {
        let adimlar = gelisimTakvimi(transfer: bugunISO(transfer))
        return HStack(spacing: 12) {
            Image("UrunAnaari").resizable().scaledToFill().frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Renk.bal, lineWidth: 1.5))
                .padding(.leading, 14).padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(ad.isEmpty ? (seriId == nil ? "Yeni seri" : "Seri") : ad).font(Yazi.nunito(20, .bold)).foregroundStyle(Renk.orman).lineLimit(1)
                Text([irk, kusak].filter { !$0.isEmpty }.joined(separator: " · ").isEmpty ? "Irk seçilmedi" : [irk, kusak].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Yazi.kucuk).foregroundStyle(Renk.metin2).lineLimit(1)
                HStack(spacing: 5) {
                    if let son = adimlar.last { Rozet(metin: "Çıkım \(kisaTarih(son.tarih))", simge: "calendar", arkaRenk: Renk.bal.opacity(0.2)) }
                    Rozet(metin: durum == "completed" ? "Tamamlandı" : durum == "failed" ? "Başarısız" : "Aktif", tur: durum == "failed" ? .kotu : durum == "completed" ? .notr : .iyi)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 18)
        .dogaZemini()
    }

    /// Tutan sayısı kadar meme; çıkan girildiyse min(çıkan, tutan)'a kısalır, gerekirse tekrar büyür (web v2.4).
    private func memeListesiniGuncelle() {
        memeler = memeleriBoyutla(memeler, tutan: Int(tutan) ?? 0, cikan: Int(cikan))
    }

    private func yukle() {
        guard !yuklendi else { return }
        yuklendi = true
        guard let s = depo.veri.seriler.first(where: { $0.id == seriId }) else { ad = seriAdiOnerisi(depo.veri.seriler); return }
        ad = s.name ?? ""; irk = s.race ?? ""; kusak = kusakDuzelt(s.generation); damizlik = s.motherHive ?? ""; baslatici = s.starterHive ?? ""
        transfer = isoTarih(s.transfer) ?? Date()
        graft = s.grafted.map { String(Int($0)) } ?? ""; tutan = s.accepted.map { String(Int($0)) } ?? ""
        cikan = s.emerged.flatMap { $0 > 0 ? String(Int($0)) : nil } ?? ""
        durum = s.status ?? "active"; not = s.notes ?? ""; memeler = s.memeler
    }

    private func kaydet() {
        depo.degistir { v in
            var l = v.seriler
            let i = l.firstIndex { $0.id == seriId }
            var s = i.map { l[$0] } ?? AnaSeri(["id": .metin(yeniKimlik())])
            s.name = ad.isEmpty ? "Seri" : ad; s.race = irk; s.generation = kusak
            s.motherHive = damizlik; s.starterHive = baslatici; s.transfer = bugunISO(transfer)
            s.grafted = Double(graft); s.accepted = Double(tutan); s.emerged = Double(cikan)
            s.sold = Double(memeler.filter { $0.status == "satildi" }.count)
            s.status = durum; s.notes = not; s.memeler = memeler
            if let i { l[i] = s } else { l.append(s) }
            v.seriler = l
        }
    }
}

// MARK: Ana arı yardımcıları (Android AnaAri.kt ile aynı)

/// Tutan sayısı kadar meme; çıkan girildiyse min(çıkan, tutan)'a kısalır, gerekirse tekrar büyür (web v2.4). Var olanların durumu korunur.
func memeleriBoyutla(_ liste: [Meme], tutan: Int, cikan: Int?) -> [Meme] {
    let hedef = cikan.map { min($0, tutan) } ?? tutan
    var l = Array(liste.prefix(max(0, hedef)))
    while l.count < hedef {
        l.append(Meme(["id": .metin(yeniKimlik()), "num": .metin(String(l.count + 1)), "status": .metin("pending"), "targetHive": .metin("")]))
    }
    return l
}

/// Tutan için hazır değerler: hepsi tuttu, %90 … %50.
func tutanOnerileri(_ asilanan: Int) -> [Int] {
    guard asilanan > 0 else { return [5, 10, 15, 20, 30] }
    var l: [Int] = []
    for o in [1.0, 0.9, 0.8, 0.7, 0.6, 0.5] {
        let n = Int((Double(asilanan) * o).rounded())
        if n > 0 && !l.contains(n) { l.append(n) }
    }
    return l
}

/// Çıkan için hazır değerler: hepsi çıktı, sonra birer eksik.
func cikanOnerileri(_ tutan: Int) -> [Int] { tutan <= 0 ? [] : (0...5).map { tutan - $0 }.filter { $0 > 0 } }

/// Yeni seriye ad önerisi: bu yıl açılan seri sayısına göre harf (Seri A-26, Seri B-26 …).
func seriAdiOnerisi(_ seriler: [AnaSeri]) -> String {
    let yil = Calendar.current.component(.year, from: Date())
    let n = seriler.filter { ($0.transfer ?? "").hasPrefix("\(yil)") }.count
    let harf = Character(UnicodeScalar(UInt8(65 + n % 26)))
    return "Seri \(harf)-\(yil % 100)"
}
