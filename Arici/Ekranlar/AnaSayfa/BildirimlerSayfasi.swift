import AriCekirdek
import SwiftUI

/// Ana sayfa zili: dikkat isteyen durumlar tek listede. Satıra dokununca ilgili sekmeye gider.
struct Bildirim: Identifiable {
    let id: String
    let simge: String
    let renk: Color
    let baslik: String
    let ayrinti: String
    let hedef: Sekme
}

extension VeriDeposu {
    var bildirimler: [Bildirim] {
        var l: [Bildirim] = []
        let bugun = bugunISO()
        let kovanlar = veri.kovanlar.sorted { $0.numara < $1.numara }
        let numaralar: ([Kovan]) -> String = { k in
            k.prefix(8).map(\.num).joined(separator: ", ") + (k.count > 8 ? " …" : "")
        }

        let gecikmis = veri.isler.filter { !$0.done && !($0.dueDate ?? "").isEmpty && ($0.dueDate ?? "") < bugun }
        if !gecikmis.isEmpty {
            l.append(Bildirim(id: "gecikmis", simge: "exclamationmark.circle.fill", renk: Renk.kotu,
                              baslik: "\(gecikmis.count) iş gecikti",
                              ayrinti: gecikmis.prefix(3).map(\.text).joined(separator: " · "), hedef: .anaSayfa))
        }
        let bugunku = veri.isler.filter { !$0.done && ($0.dueDate ?? "").hasPrefix(bugun) }
        if !bugunku.isEmpty {
            l.append(Bildirim(id: "bugun", simge: "checklist", renk: Renk.bal,
                              baslik: "Bugün \(bugunku.count) iş var",
                              ayrinti: bugunku.prefix(3).map(\.text).joined(separator: " · "), hedef: .anaSayfa))
        }
        let anasiz = kovanlar.filter(\.sorunlu)
        if !anasiz.isEmpty {
            l.append(Bildirim(id: "anasiz", simge: "crown", renk: Renk.kotu,
                              baslik: "\(anasiz.count) kovan anasız", ayrinti: "Kovan " + numaralar(anasiz), hedef: .anaAri))
        }
        let yasli = kovanlar.filter(\.yasliAna)
        if !yasli.isEmpty {
            l.append(Bildirim(id: "yasli", simge: "hourglass", renk: Renk.uyari,
                              baslik: "\(yasli.count) kovanda ana 2+ yaşında", ayrinti: "Kovan " + numaralar(yasli), hedef: .anaAri))
        }
        let bakire = kovanlar.filter { ["bakire", "new"].contains($0.queenStatus ?? "") }
        if !bakire.isEmpty {
            l.append(Bildirim(id: "bakire", simge: "eye", renk: Renk.bilgi,
                              baslik: "\(bakire.count) kovanda bakire ana", ayrinti: "Yumurta kontrolü: Kovan " + numaralar(bakire), hedef: .kovanlar))
        }
        let bekleyen = bekleyenToplam(satislar: veri.satislar)
        if bekleyen > 0 {
            let kisi = Set(veri.satislar.filter { kalan($0.ham) > 0 && ["pending", "partial"].contains($0.payment ?? "") }.compactMap(\.customer)).count
            l.append(Bildirim(id: "odeme", simge: "turkishlirasign.circle.fill", renk: Renk.uyari,
                              baslik: "\(tl(bekleyen)) tahsil edilecek", ayrinti: "\(kisi) müşteri", hedef: .satis))
        }
        let onSiparis = veri.satislar.filter { $0.orderStatus == "preorder" }
        if !onSiparis.isEmpty {
            l.append(Bildirim(id: "onsiparis", simge: "shippingbox", renk: Renk.bilgi,
                              baslik: "\(onSiparis.count) ön sipariş teslim bekliyor",
                              ayrinti: Set(onSiparis.compactMap(\.customer)).sorted().prefix(4).joined(separator: ", "), hedef: .satis))
        }
        return l
    }
}

struct BildirimlerSayfasi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(MenuDurumu.self) private var menu
    @Environment(\.dismiss) private var kapat

    var body: some View {
        let l = depo.bildirimler
        NavigationStack {
            List {
                if l.isEmpty {
                    ContentUnavailableView("Her şey yolunda", systemImage: "checkmark.seal", description: Text("Dikkat isteyen bir durum yok."))
                        .listRowBackground(Color.clear)
                }
                ForEach(l) { b in
                    Button {
                        kapat()
                        menu.git(b.hedef)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: b.simge).font(.system(size: 18)).foregroundStyle(b.renk)
                                .frame(width: 38, height: 38).background(b.renk.opacity(0.15), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.baslik).font(Yazi.govdeOrta)
                                if !b.ayrinti.isEmpty { Text(b.ayrinti).font(Yazi.kucuk).foregroundStyle(.secondary).lineLimit(2) }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Bildirimler")
            .navigationBarTitleDisplayMode(.inline)
            .formArkaplani()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
