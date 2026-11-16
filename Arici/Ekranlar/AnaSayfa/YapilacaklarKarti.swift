import AriCekirdek
import SwiftUI

/// Takvimli yapılacaklar (web renderMiniCal gibi): aylık takvim + ay geçişi, seçili günün tüm işleri
/// (tamamlananlar dahil), "Tümü" ile tarihe göre gruplu tam liste (gecikenler uyarılı).
struct YapilacaklarKarti: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var secili = bugunISO()
    @State private var ay = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var formAcik = false
    @State private var tumu = false
    @State private var tamamlananlar = false
    @AppStorage("takvimAcik") private var takvimAcik = false

    private static let aylar = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]

    /// Ayın günleri; pazartesi başlangıçlı ızgara için baştaki boşluklar nil.
    private var gunler: [Date?] {
        let c = Calendar.current
        guard let aralik = c.range(of: .day, in: .month, for: ay) else { return [] }
        let bosluk = (c.component(.weekday, from: ay) + 5) % 7
        return Array(repeating: nil, count: bosluk) + aralik.compactMap { c.date(byAdding: .day, value: $0 - 1, to: ay) }
    }

    var body: some View {
        let isler = depo.veri.isler
        let tarihli = Dictionary(grouping: isler.filter { !($0.dueDate ?? "").isEmpty }, by: { String(($0.dueDate ?? "").prefix(10)) })
        let bugun = bugunISO()
        Kart {
            KartBasligi(baslik: "Yapılacaklar", baglanti: tumu ? "Takvim" : "Tümü") { tumu.toggle() }
            if tumu {
                tumListe(tarihli: tarihli, tarihsiz: isler.filter { ($0.dueDate ?? "").isEmpty }, bugun: bugun)
            } else {
                Button { withAnimation(.snappy) { takvimAcik.toggle() } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar").foregroundStyle(Renk.orman2)
                        Text(takvimAcik ? "Takvimi gizle" : "Takvimi göster").font(Yazi.kucukOrta)
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                            .rotationEffect(.degrees(takvimAcik ? 180 : 0))
                    }
                    .foregroundStyle(Renk.metin2)
                    .padding(.vertical, 6).padding(.horizontal, 10)
                    .background(Renk.kart, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                if takvimAcik {
                HStack {
                    Button { ayDegistir(-1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 32) }
                        .accessibilityLabel("Önceki ay")
                    Spacer()
                    Text("\(Self.aylar[Calendar.current.component(.month, from: ay) - 1]) \(String(Calendar.current.component(.year, from: ay)))")
                        .font(Yazi.govdeOrta)
                    Spacer()
                    Button { ayDegistir(1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 32) }
                        .accessibilityLabel("Sonraki ay")
                }
                .buttonStyle(.plain).foregroundStyle(Renk.orman2)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 3) {
                    ForEach(["Pt", "Sa", "Ça", "Pe", "Cu", "Ct", "Pz"], id: \.self) { Text($0).font(Yazi.minik).foregroundStyle(Renk.metin3) }
                    ForEach(Array(gunler.enumerated()), id: \.offset) { _, g in
                        if let g { gunHucresi(g, tarihli: tarihli, bugun: bugun) } else { Color.clear.frame(height: 40) }
                    }
                }
                }
                let gunun = tarihli[secili] ?? []
                let tarihsiz = secili == bugun ? isler.filter { ($0.dueDate ?? "").isEmpty && !$0.done } : []
                Text(secili == bugun ? "Bugün" : kisaTarih(secili)).font(Yazi.kucukOrta).foregroundStyle(Renk.metin2).padding(.top, 2)
                if gunun.isEmpty && tarihsiz.isEmpty {
                    Text("Bu gün için iş yok.").font(Yazi.kucuk).foregroundStyle(Renk.metin3).padding(.vertical, 4)
                }
                ForEach(gunun.sorted { !$0.done && $1.done } + tarihsiz, id: \.id) { is_ in satir(is_) }
            }
            Button { formAcik = true } label: {
                HStack {
                    Text("İş ekle… ör. \"1-10 kat ekle\"").font(Yazi.kucuk).foregroundStyle(Renk.metin3)
                    Spacer()
                    Image(systemName: "plus").font(.system(size: 16, weight: .semibold)).foregroundStyle(Renk.orman)
                        .frame(width: 36, height: 36).background(Renk.bal, in: RoundedRectangle(cornerRadius: 11))
                }
                .padding(.leading, 12).padding(.trailing, 3).padding(.vertical, 3)
                .background(Renk.kart, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $formAcik) { IsFormu(tarih: secili) }
    }

    private func gunHucresi(_ g: Date, tarihli: [String: [Is]], bugun: String) -> some View {
        let iso = bugunISO(g)
        let o = tarihli[iso] ?? []
        let acik = o.contains { !$0.done }
        let gecikti = acik && iso < bugun
        return Button { secili = iso } label: {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: g))").font(iso == bugun ? Yazi.govdeOrta : Yazi.govde)
                    .foregroundStyle(secili == iso ? .white : iso == bugun ? Renk.orman2 : Renk.metin)
                Circle().fill(o.isEmpty ? .clear : gecikti ? Renk.kotu : acik ? Renk.bal : Renk.iyi).frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(secili == iso ? Renk.orman : iso == bugun ? Renk.bal.opacity(0.18) : .clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kisaTarih(iso)), \(o.count) iş")
    }

    @ViewBuilder
    private func tumListe(tarihli: [String: [Is]], tarihsiz: [Is], bugun: String) -> some View {
        Toggle("Tamamlananları göster", isOn: $tamamlananlar).font(Yazi.kucuk).tint(Renk.orman2)
        let tarihler = tarihli.keys.sorted().filter { d in tamamlananlar || tarihli[d]!.contains { !$0.done } }
        let tarihsizGor = tarihsiz.filter { tamamlananlar || !$0.done }
        if tarihler.isEmpty && tarihsizGor.isEmpty {
            Text("Açık iş yok.").font(Yazi.kucuk).foregroundStyle(Renk.metin3).padding(.vertical, 4)
        }
        ForEach(tarihler, id: \.self) { d in
            let o = tarihli[d]!.filter { tamamlananlar || !$0.done }
            let gecikti = d < bugun && o.contains { !$0.done }
            Text((gecikti ? "⚠️ " : "") + (d == bugun ? "Bugün" : kisaTarih(d)))
                .font(Yazi.kucukOrta).foregroundStyle(gecikti ? Renk.kotu : d == bugun ? Renk.orman2 : Renk.metin3).padding(.top, 4)
            ForEach(o, id: \.id) { is_ in satir(is_) }
        }
        if !tarihsizGor.isEmpty {
            Text("Tarihsiz").font(Yazi.kucukOrta).foregroundStyle(Renk.metin3).padding(.top, 4)
            ForEach(tarihsizGor, id: \.id) { is_ in satir(is_) }
        }
    }

    private func ayDegistir(_ fark: Int) {
        ay = Calendar.current.date(byAdding: .month, value: fark, to: ay) ?? ay
    }

    private func satir(_ i: Is) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                depo.degistir { v in
                    var l = v.isler
                    if let k = l.firstIndex(where: { $0.id == i.id }) { l[k].done.toggle(); v.isler = l }
                }
            } label: {
                Image(systemName: i.done ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22)).foregroundStyle(i.done ? Renk.iyi : Renk.metin3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(i.done ? "Tamamlandı" : "Tamamla")
            VStack(alignment: .leading, spacing: 3) {
                Text(i.text).font(Yazi.govde).strikethrough(i.done).foregroundStyle(i.done ? Renk.metin3 : Renk.metin)
                if let d = i.dueDate, !d.isEmpty, d != secili, !tumu { Text(kisaTarih(d)).font(Yazi.etiket).foregroundStyle(Renk.metin3) }
                if let s = i.scope, !s.isEmpty {
                    Rozet(metin: topluEtiket(s, i.hiveIds?.count), tur: .bilgi)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .overlay(alignment: .top) { Divider().overlay(Renk.krem2) }
        .contextMenu {
            Button(role: .destructive) {
                depo.degistir { v in v.isler = v.isler.filter { $0.id != i.id } }
            } label: { Label("Sil", systemImage: "trash") }
        }
    }

    private func topluEtiket(_ kapsam: String, _ sayi: Int?) -> String {
        let k = kapsam.first?.isNumber == true ? "Kovan \(kapsam.replacingOccurrences(of: "-", with: "–"))" : kapsam
        return sayi.map { "\(k) · \($0) kovan" } ?? k
    }

}

/// İş ekleme: metin, tarih, toplu kapsam ("12-18", "Tüm Langstroth") + canlı kovan sayısı.
struct IsFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    @State private var metin = ""
    @State private var tarih: Date
    @State private var tarihVar = true
    @State private var kapsam = ""

    init(tarih: String) { _tarih = State(initialValue: isoTarih(tarih) ?? Date()) }

    var body: some View {
        let kovanlar = topluIsKovanlari(kapsam, kovanlar: depo.veri.kovanlar)
        NavigationStack {
            Form {
                Section("İş") {
                    TextField("Ör. Şurup ver (1 lt)", text: $metin, axis: .vertical)
                }
                Section {
                    Toggle("Tarihli", isOn: $tarihVar)
                    if tarihVar { DatePicker("Tarih", selection: $tarih, displayedComponents: .date) }
                }
                Section {
                    TextField("Kovanlar: 12-18, 1,3,5 ya da Tüm Langstroth", text: $kapsam)
                        .textInputAutocapitalization(.never)
                } header: { Text("Toplu iş (isteğe bağlı)") } footer: {
                    if !kapsam.isEmpty { Text(kovanlar.isEmpty ? "Eşleşen kovan yok" : "\(kovanlar.count) kovan seçildi") }
                }
            }
            .navigationTitle("Yeni İş")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        let t = metin.trimmingCharacters(in: .whitespacesAndNewlines)
                        depo.degistir { v in
                            var k: Kayit = ["id": .metin(yeniKimlik()), "text": .metin(t), "done": .bool(false)]
                            if tarihVar { k["dueDate"] = .metin(bugunISO(tarih)) }
                            if !kovanlar.isEmpty {
                                k["scope"] = .metin(kapsam.trimmingCharacters(in: .whitespaces))
                                k["hiveIds"] = .dizi(kovanlar.map { .metin($0) })
                            }
                            v.isler = v.isler + [Is(k)]
                        }
                        kapat()
                    }
                    .disabled(metin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
