import SwiftUI
import UIKit
import AriCekirdek

/// Menülerde renkli simge: iOS menüleri SF Symbol'leri tek renk çizer, bu yüzden renk karesi görsel olarak üretilir.
enum RenkGorseli {
    static func gorsel(_ renkler: [Color], boyut: CGFloat = 18) -> Image {
        let l = Array(renkler.prefix(2))
        let n = CGFloat(max(1, l.count))
        let r = UIGraphicsImageRenderer(size: CGSize(width: boyut * n + 3 * (n - 1), height: boyut))
        let img = r.image { _ in
            for (i, c) in l.enumerated() {
                let kutu = CGRect(x: CGFloat(i) * (boyut + 3), y: 0, width: boyut, height: boyut).insetBy(dx: 0.5, dy: 0.5)
                let yol = UIBezierPath(roundedRect: kutu, cornerRadius: boyut * 0.3)
                UIColor(c).setFill(); yol.fill()
                UIColor.black.withAlphaComponent(0.25).setStroke(); yol.lineWidth = 1; yol.stroke()
            }
        }
        return Image(uiImage: img.withRenderingMode(.alwaysOriginal))
    }
    static func gorsel(idler: [String], boyut: CGFloat = 18) -> Image { gorsel(idler.map { RenkPaleti.renk($0) ?? .gray }, boyut: boyut) }
}

// Kovan renkleri (Android 3.0.1 ile aynı veri): kart ışıması renkleri + renk durumları (abinin şeması).

enum RenkPaleti {
    struct P: Identifiable { let id: String; let ad: String; let renk: Color }
    static let liste: [P] = [
        P(id: "red", ad: "Kırmızı", renk: Color(red: 0.898, green: 0.224, blue: 0.208)),
        P(id: "blue", ad: "Mavi", renk: Color(red: 0.118, green: 0.533, blue: 0.898)),
        P(id: "green", ad: "Yeşil", renk: Color(red: 0.263, green: 0.627, blue: 0.278)),
        P(id: "orange", ad: "Turuncu", renk: Color(red: 0.984, green: 0.549, blue: 0)),
        P(id: "yellow", ad: "Sarı", renk: Color(red: 0.992, green: 0.847, blue: 0.208)),
        P(id: "purple", ad: "Mor", renk: Color(red: 0.557, green: 0.141, blue: 0.667)),
        P(id: "pink", ad: "Pembe", renk: Color(red: 0.925, green: 0.251, blue: 0.478)),
        P(id: "white", ad: "Beyaz", renk: Color(red: 0.96, green: 0.96, blue: 0.96)),
        P(id: "black", ad: "Siyah", renk: Color(red: 0.13, green: 0.13, blue: 0.13)),
        P(id: "brown", ad: "Kahverengi", renk: Color(red: 0.475, green: 0.333, blue: 0.282)),
    ]

    static func renk(_ id: String?) -> Color? {
        guard let id else { return nil }
        if let p = liste.first(where: { $0.id == id }) { return p.renk }
        guard id.hasPrefix("#"), id.count == 7, let v = Int(id.dropFirst(), radix: 16) else { return nil }
        return Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    static func ad(_ id: String?) -> String { liste.first { $0.id == id }?.ad ?? (id ?? "") }
}

let varsayilanRenkDurumlari: [RenkDurumu] = [
    RenkDurumu(id: "d1", name: "Anasız kovan", colors: ["red"]),
    RenkDurumu(id: "d2", name: "Yeni analı kovan", colors: ["blue", "red"]),
    RenkDurumu(id: "d3", name: "Eski analı kovan", colors: ["green"]),
    RenkDurumu(id: "d4", name: "Oğul arısı", colors: ["blue"]),
    RenkDurumu(id: "d5", name: "F2 analı kovan", colors: ["orange"]),
    RenkDurumu(id: "d6", name: "Ana çıkmış, yüksüğü kesilmiş", colors: ["red", "green"]),
    RenkDurumu(id: "d7", name: "Yalancıya kaçmış", colors: ["blue", "green"]),
    RenkDurumu(id: "d8", name: "Saldırgan arı", colors: ["blue", "orange"]),
    RenkDurumu(id: "d9", name: "Meme var, ana çıkması bekleniyor", colors: ["red", "orange"]),
    RenkDurumu(id: "d10", name: "Değiştirilecek F2 ana (verim düşük)", colors: ["green", "orange"]),
]

/// Ana durumu → varsayılan ışıma rengi (eski sabit renkler).
let isimaVarsayilan: [String: Color] = [
    "yes": Color(red: 0.36, green: 0.85, blue: 0.45),
    "bakire": Color(red: 0.4, green: 0.68, blue: 1),
    "no": Color(red: 1, green: 0.36, blue: 0.3),
    "meme": Color(red: 0.74, green: 0.5, blue: 1),
    "unknown": Renk.bal,
]
let isimaAdlari: [(String, String)] = [("yes", "Ana var"), ("bakire", "Bakire ana"), ("no", "Anasız"), ("meme", "Meme var"), ("unknown", "Bilinmiyor")]

/// Ayarların kopyası (VeriDeposu durum her değiştiğinde günceller). Aktör bağımsız: her yerden okunur;
/// depo değişince kartlar zaten yeniden çizildiği için ekran tazelenir.
enum KovanRenkAyari {
    static var ayar = Ayarlar()

    static func isimaRengi(_ durum: String) -> Color {
        RenkPaleti.renk(ayar.glowColors[durum]) ?? isimaVarsayilan[durum] ?? Renk.bal
    }
    static var durumlarAcik: Bool { ayar.hiveMarksOn }
    static var durumlar: [RenkDurumu] { ayar.hiveMarks ?? varsayilanRenkDurumlari }
    static func durum(_ k: Kovan) -> RenkDurumu? {
        guard durumlarAcik, let id = k.mark else { return nil }
        return durumlar.first { $0.id == id }
    }
}

// MARK: Parçalar

struct RenkSeritleri: View {
    let renkler: [String]
    var en: CGFloat = 22
    var boy: CGFloat = 8
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(renkler.prefix(2).enumerated()), id: \.offset) { _, id in
                RoundedRectangle(cornerRadius: 3, style: .continuous).fill(RenkPaleti.renk(id) ?? .gray)
                    .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(.black.opacity(0.18)))
                    .frame(width: en, height: boy)
            }
        }
    }
}

/// Kovan kartında resmin altındaki şerit.
struct KovanRenkSeridi: View {
    let kovan: Kovan
    var body: some View {
        if let d = KovanRenkAyari.durum(kovan) { RenkSeritleri(renkler: d.colors, en: 26, boy: 9) }
    }
}

/// Kovan detayı › Hızlı Durum altı: renk durumu + seçim menüsü.
struct RenkDurumuKutusu: View {
    @Environment(VeriDeposu.self) private var depo
    let kovan: Kovan
    var body: some View {
        if KovanRenkAyari.durumlarAcik {
            let d = KovanRenkAyari.durum(kovan)
            Menu {
                ForEach(KovanRenkAyari.durumlar) { r in
                    Button { sec(r.id) } label: { Label { Text((r.id == kovan.mark ? "✓ " : "") + r.name) } icon: { RenkGorseli.gorsel(idler: r.colors) } }
                }
                Button("Yok", role: .destructive) { sec(nil) }
            } label: {
                HStack(spacing: 7) {
                    if let d { RenkSeritleri(renkler: d.colors, en: 12, boy: 12) } else { Image(systemName: "paintpalette").font(.system(size: 13)).foregroundStyle(kartAltin) }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Renk durumu").font(Yazi.nunito(10)).foregroundStyle(Renk.metin2)
                        Text(d?.name ?? "Seç").font(Yazi.nunito(13, .bold)).foregroundStyle(d == nil ? Renk.orman2 : Renk.metin)
                            .lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Renk.kart, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Renk.krem2))
            }
            .buttonStyle(.plain)
        }
    }

    private func sec(_ id: String?) {
        let kid = kovan.id
        depo.degistir { v in
            var l = v.kovanlar
            if let i = l.firstIndex(where: { $0.id == kid }) { l[i].mark = id; v.kovanlar = l }
        }
    }
}

// MARK: Ayarlar › Kovan renkleri

struct KovanRenkleriSayfasi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    @State private var duzenlenen: RenkDurumu?

    private var durumlar: [RenkDurumu] { depo.ayarlar.hiveMarks ?? varsayilanRenkDurumlari }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(isimaAdlari, id: \.0) { e in
                        let anahtar = e.0, ad = e.1
                        let ozel = depo.ayarlar.glowColors[anahtar]
                        Menu {
                            Button { depo.ayarDegistir { $0.glowColors[anahtar] = nil } } label: { Label { Text((ozel == nil ? "✓ " : "") + "Varsayılan") } icon: { RenkGorseli.gorsel([isimaVarsayilan[anahtar] ?? Renk.bal]) } }
                            ForEach(RenkPaleti.liste) { p in
                                Button { depo.ayarDegistir { $0.glowColors[anahtar] = p.id } } label: { Label { Text((p.id == ozel ? "✓ " : "") + p.ad) } icon: { RenkGorseli.gorsel(idler: [p.id]) } }
                            }
                        } label: {
                            HStack {
                                Text(ad).foregroundStyle(Renk.metin)
                                Spacer()
                                if let ozel { Text(RenkPaleti.ad(ozel)).font(Yazi.etiket).foregroundStyle(Renk.metin2) }
                                Circle().fill(KovanRenkAyari.isimaRengi(anahtar)).frame(width: 24, height: 24)
                                    .overlay(Circle().strokeBorder(.black.opacity(0.2)))
                            }
                        }
                    }
                    if !depo.ayarlar.glowColors.isEmpty {
                        Button("Hepsini varsayılana döndür") { depo.ayarDegistir { $0.glowColors = [:] } }
                    }
                } header: { Label("Kart ışıması", systemImage: "paintpalette") } footer: {
                    Text("Kovan kartını saran ışık, ana arı durumuna göre bu renklerde yanar.")
                }

                Section {
                    Toggle("Renk durumlarını kullan", isOn: Binding(get: { depo.ayarlar.hiveMarksOn }, set: { v in depo.ayarDegistir { $0.hiveMarksOn = v } }))
                        .tint(Renk.orman2)
                    if depo.ayarlar.hiveMarksOn {
                        ForEach(durumlar) { r in
                            Button { duzenlenen = r } label: {
                                HStack(spacing: 10) {
                                    RenkSeritleri(renkler: r.colors, en: 20, boy: 12).frame(width: 48, alignment: .leading)
                                    Text(r.name).foregroundStyle(Renk.metin)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Renk.metin3)
                                }
                            }
                        }
                        Button { duzenlenen = RenkDurumu(id: "", name: "", colors: ["red"]) } label: { Label("Yeni durum", systemImage: "plus") }
                        if depo.ayarlar.hiveMarks != nil && depo.ayarlar.hiveMarks != varsayilanRenkDurumlari {
                            Button("Varsayılan listeyi geri yükle") { depo.ayarDegistir { $0.hiveMarks = nil } }.foregroundStyle(Renk.metin2)
                        }
                    }
                } header: { Label("Renk durumları", systemImage: "tag") } footer: {
                    Text("Kovana koyduğun renk işaretleri: her durum 1–2 renk. Açıkken kovan kartında resmin altında renkler görünür, kovan detayında Hızlı Durum'dan seçilir.")
                }
            }
            .navigationTitle("Kovan renkleri")
            .navigationBarTitleDisplayMode(.inline)
            .formArkaplani()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } } }
            .sheet(item: $duzenlenen) { r in RenkDurumuFormu(r0: r, durumlar: durumlar) }
        }
    }
}

private struct RenkDurumuFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let r0: RenkDurumu
    let durumlar: [RenkDurumu]
    @State private var ad = ""
    @State private var r1 = "red"
    @State private var r2: String?
    @State private var yuklendi = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Ad") { TextField("Örn. Yeni analı kovan", text: $ad) }
                Section("1. renk") { palet(secili: r1) { r1 = $0 ?? r1 } }
                Section("2. renk (isteğe bağlı)") { palet(secili: r2, bosVar: true) { r2 = $0 } }
                if !r0.id.isEmpty {
                    Section { Button("Durumu sil", role: .destructive) { yaz(durumlar.filter { $0.id != r0.id }) } }
                }
            }
            .navigationTitle(r0.id.isEmpty ? "Yeni durum" : "Durumu düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        let yeni = RenkDurumu(id: r0.id.isEmpty ? UUID().uuidString : r0.id, name: ad.trimmingCharacters(in: .whitespaces), colors: [r1] + (r2.map { [$0] } ?? []))
                        yaz(r0.id.isEmpty ? durumlar + [yeni] : durumlar.map { $0.id == r0.id ? yeni : $0 })
                    }
                    .disabled(ad.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard !yuklendi else { return }
                yuklendi = true
                ad = r0.name; r1 = r0.colors.first ?? "red"; r2 = r0.colors.count > 1 ? r0.colors[1] : nil
            }
        }
    }

    private func palet(secili: String?, bosVar: Bool = false, sec: @escaping (String?) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
            if bosVar {
                Button { sec(nil) } label: {
                    Circle().strokeBorder(secili == nil ? Renk.orman : .black.opacity(0.2), lineWidth: secili == nil ? 2.5 : 1)
                        .frame(width: 32, height: 32).overlay(Text("—").font(Yazi.minik))
                }.buttonStyle(.plain)
            }
            ForEach(RenkPaleti.liste) { p in
                Button { sec(p.id) } label: {
                    Circle().fill(p.renk).frame(width: 32, height: 32)
                        .overlay(Circle().strokeBorder(p.id == secili ? Renk.orman : .black.opacity(0.2), lineWidth: p.id == secili ? 2.5 : 1))
                        .overlay { if p.id == secili { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(p.id == "white" || p.id == "yellow" ? .black : .white) } }
                }.buttonStyle(.plain).accessibilityLabel(p.ad)
            }
        }
        .padding(.vertical, 4)
    }

    private func yaz(_ yeni: [RenkDurumu]) {
        depo.ayarDegistir { $0.hiveMarks = yeni }
        kapat()
    }
}

