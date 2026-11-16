import AriCekirdek
import SwiftUI

extension Is {
    /// Yapıldığı gün: işaretlenirken yazılan `doneAt`, yoksa işin tarihi.
    var yapildigiGun: String { String((ham["doneAt"]?.metinDegeri ?? dueDate ?? "").prefix(10)) }
}

/// Ana sayfa: takvimde "yapıldı" işaretlenen işler, en yeni üstte. Son 5'i kartta, tümü sayfada.
struct YapilanIslerKarti: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var tumu = false
    var body: some View {
        let yapilanlar = depo.veri.isler.filter(\.done).sorted { $0.yapildigiGun > $1.yapildigiGun }
        if !yapilanlar.isEmpty {
            Kart {
                KartBasligi(baslik: "Yapılan İşler", baglanti: yapilanlar.count > 5 ? "Tümü (\(yapilanlar.count))" : nil) { tumu = true }
                ForEach(yapilanlar.prefix(5), id: \.id) { i in YapilanIsSatiri(is_: i) }
            }
            .sheet(isPresented: $tumu) { YapilanIslerSayfasi() }
        }
    }
}

struct YapilanIsSatiri: View {
    @Environment(VeriDeposu.self) private var depo
    let is_: Is
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                depo.degistir { v in
                    var l = v.isler
                    if let k = l.firstIndex(where: { $0.id == is_.id }) {
                        l[k].done = false
                        l[k].ham.removeValue(forKey: "doneAt")
                        v.isler = l
                    }
                }
            } label: {
                Image(systemName: "checkmark.square.fill").font(.system(size: 22)).foregroundStyle(Renk.iyi)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Yapılmadı olarak işaretle")
            VStack(alignment: .leading, spacing: 3) {
                Text(is_.text).font(Yazi.govde).foregroundStyle(Renk.metin)
                if !is_.yapildigiGun.isEmpty {
                    Text(kisaTarih(is_.yapildigiGun)).font(Yazi.etiket).foregroundStyle(Renk.metin3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

struct YapilanIslerSayfasi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    var body: some View {
        let yapilanlar = depo.veri.isler.filter(\.done)
        let gruplar = Dictionary(grouping: yapilanlar, by: \.yapildigiGun)
        NavigationStack {
            List {
                if yapilanlar.isEmpty { Text("Henüz yapıldı işaretlenen iş yok.").foregroundStyle(.secondary) }
                ForEach(gruplar.keys.sorted(by: >), id: \.self) { g in
                    Section(g.isEmpty ? "Tarihsiz" : kisaTarih(g)) {
                        ForEach(gruplar[g]!, id: \.id) { i in YapilanIsSatiri(is_: i) }
                    }
                }
            }
            .navigationTitle("Yapılan İşler")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } } }
        }
    }
}
