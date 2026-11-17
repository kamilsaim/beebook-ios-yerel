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
                    Picker("Irk", selection: $irk) { Text("—").tag(""); ForEach(depo.irklar + (irk.isEmpty || depo.irklar.contains(irk) ? [] : [irk]), id: \.self) { Text($0) } }
                    Picker("Kuşak", selection: $kusak) { Text("—").tag(""); ForEach(kusakSecenekleri + (kusak.isEmpty || kusakSecenekleri.contains(kusak) ? [] : [kusak]), id: \.self) { Text($0) } }
                    Picker("Damızlık kovan", selection: $damizlik) { Text("—").tag(""); ForEach(kovanlar, id: \.id) { Text("Kovan \($0.num)").tag($0.id) } }
                    Picker("Başlatıcı kovan", selection: $baslatici) { Text("—").tag(""); ForEach(kovanlar, id: \.id) { Text("Kovan \($0.num)").tag($0.id) } }
                    DatePicker("Larva transferi", selection: $transfer, displayedComponents: .date)
                }
                Section(header: Label("Sonuç", systemImage: "chart.bar"), footer: Text("Meme listesi Kaydet'te tutan/çıkan sayısına göre güncellenir.")) {
                    sayiAdimi("Aşılanan", $graft)
                    sayiAdimi("Tutan (meme)", $tutan)
                    sayiAdimi("Çıkan", $cikan)
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
            .confirmationDialog("Seri silinsin mi?", isPresented: $silOnay, titleVisibility: .visible) {
                Button("Sil", role: .destructive) { depo.degistir { v in v.seriler = v.seriler.filter { $0.id != seriId } }; kapat() }
            }
            .onAppear(perform: yukle)
        }
    }

    private var kovanlar: [Kovan] { depo.veri.kovanlar.sorted { $0.numara < $1.numara } }

    private func sayiAdimi(_ etiket: String, _ deger: Binding<String>) -> some View {
        Stepper(value: Binding(get: { Int(deger.wrappedValue) ?? 0 }, set: { deger.wrappedValue = $0 > 0 ? String($0) : "" }), in: 0...500) {
            HStack { Text(etiket); Spacer(); Text(deger.wrappedValue.isEmpty ? "—" : deger.wrappedValue).font(Yazi.nunito(17, .bold)).foregroundStyle(Renk.orman2) }
        }
    }

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
        let t = Int(tutan) ?? 0
        let hedef = Int(cikan).map { min($0, t) } ?? t
        if memeler.count > hedef { memeler = Array(memeler.prefix(hedef)) }
        while memeler.count < hedef {
            memeler.append(Meme(["id": .metin(yeniKimlik()), "num": .metin(String(memeler.count + 1)), "status": .metin("pending"), "targetHive": .metin("")]))
        }
    }

    private func yukle() {
        guard !yuklendi else { return }
        yuklendi = true
        guard let s = depo.veri.seriler.first(where: { $0.id == seriId }) else { return }
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
