import AriCekirdek
import SwiftUI

/// Takvimli yapılacaklar: haftalık şerit, işaretleme, toplu iş etiketi, hızlı ekleme.
struct YapilacaklarKarti: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var secili = bugunISO()
    @State private var formAcik = false
    @State private var tumu = false

    private var hafta: [Date] {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        let bas = c.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return (0..<7).compactMap { c.date(byAdding: .day, value: $0, to: bas) }
    }

    var body: some View {
        let isler = depo.veri.isler
        let gunun = isler.filter { ($0.dueDate ?? "") == secili }
        let tarihsiz = isler.filter { ($0.dueDate ?? "").isEmpty && !$0.done }
        Kart {
            KartBasligi(baslik: "Yapılacaklar", baglanti: tumu ? "Kapat" : "Tümü") { tumu.toggle() }
            HStack(spacing: 4) {
                ForEach(hafta, id: \.self) { g in
                    let iso = bugunISO(g)
                    Button { secili = iso } label: {
                        VStack(spacing: 2) {
                            Text(gunKisa(g)).font(Yazi.minik).foregroundStyle(secili == iso ? Color(white: 0.85) : Renk.metin3)
                            Text("\(Calendar.current.component(.day, from: g))").font(Yazi.govdeOrta)
                                .foregroundStyle(secili == iso ? .white : Renk.metin)
                            Circle().fill(isler.contains { $0.dueDate == iso } ? Renk.bal : .clear).frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(secili == iso ? Renk.orman : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(iso)
                }
            }
            let gosterilen = tumu ? isler.filter { !$0.done }.sorted { ($0.dueDate ?? "9") < ($1.dueDate ?? "9") } : gunun + (secili == bugunISO() ? tarihsiz : [])
            if gosterilen.isEmpty {
                Text("Bu gün için iş yok.").font(Yazi.kucuk).foregroundStyle(Renk.metin3).padding(.vertical, 4)
            }
            ForEach(gosterilen, id: \.id) { is_ in satir(is_) }
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
                if let d = i.dueDate, !d.isEmpty, d != secili { Text(kisaTarih(d)).font(Yazi.etiket).foregroundStyle(Renk.metin3) }
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

    private func gunKisa(_ d: Date) -> String {
        ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"][Calendar.current.component(.weekday, from: d) - 1]
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
