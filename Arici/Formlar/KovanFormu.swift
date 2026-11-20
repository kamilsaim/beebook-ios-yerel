import AriCekirdek
import SwiftUI

/// Kovan ekle/düzenle (web hive-modal alanları). Düzenlemede kayıt yayılır: bilinmeyen alanlar korunur.
struct KovanFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let kovanId: String?

    @State private var num = ""
    @State private var tip = "Langstroth"
    @State private var anaDurum = "yes"
    @State private var renk = "white"
    @State private var isaret = ""
    @State private var guc = 3
    @State private var irk = ""
    @State private var kusak = ""
    @State private var yil = ""
    @State private var cerceve = ""
    @State private var kat = 1
    @State private var not = ""
    @State private var tarayici = false
    @State private var silOnay = false
    @State private var yuklendi = false

    private let durumlar: [(String, String)] = [("yes", "Ana var"), ("no", "Ana yok"), ("bakire", "Bakire"), ("meme", "Meme var"), ("unknown", "Bilinmiyor"), ("empty", "Arısız")]
    private let renkler: [(String, String)] = [("white", "Beyaz"), ("yellow", "Sarı"), ("red", "Kırmızı"), ("green", "Yeşil"), ("blue", "Mavi"), ("unpainted", "Boyasız")]

    var body: some View {
        NavigationStack {
            Form {
                Section { onizleme }.listeBasligi()
                Section(header: Label("Kovan", systemImage: "square.stack.3d.up")) {
                    HStack {
                        TextField("Kovan no", text: $num).keyboardType(.numbersAndPunctuation)
                        Button { tarayici = true } label: { Image(systemName: "barcode.viewfinder") }
                    }
                    CipSecici(baslik: "Tip", secenekler: tipListesi.map { ($0, $0) }, secili: tip) { tip = $0 }
                    CipSecici(baslik: "Ana arı", secenekler: durumlar, secili: anaDurum, nokta: { $0 == "empty" ? Color(white: 0.6) : KovanRenkAyari.isimaRengi($0) }) { anaDurum = $0 }
                    if KovanRenkAyari.durumlarAcik {
                        CipSecici(baslik: "Renk durumu", secenekler: [("", "Yok")] + KovanRenkAyari.durumlar.map { ($0.id, $0.name) }, secili: isaret,
                                  nokta: { id in KovanRenkAyari.durumlar.first { $0.id == id }?.colors.first.flatMap { RenkPaleti.renk($0) } }) { isaret = $0 }
                    }
                }
                if anaDurum != "empty" {
                    Section(header: Label("Ana arı", systemImage: "crown")) {
                        CipSecici(baslik: "Irk", secenekler: irkListesi.map { ($0, $0) }, secili: irk) { irk = irk == $0 ? "" : $0 }
                        CipSecici(baslik: "Kuşak", secenekler: (kusakSecenekleri + (kusak.isEmpty || kusakSecenekleri.contains(kusak) ? [] : [kusak])).map { ($0, $0) }, secili: kusak) { kusak = kusak == $0 ? "" : $0 }
                        // Son 5 yıl tek dokunuşla; renk yıl rengine göre kendiliğinden
                        let buYil = Calendar.current.component(.year, from: Date())
                        let yillar = Array((buYil - 4)...buYil).reversed().map(String.init) + (Int(yil).map { $0 < buYil - 4 } == true ? [yil] : [])
                        CipSecici(baslik: "Ana yılı", secenekler: yillar.map { ($0, $0) }, secili: yil, nokta: { Int($0).map { Renk.ana(anaRengi(yil: $0)) } }) {
                            yil = yil == $0 ? "" : $0
                            if let n = Int(yil) { renk = anaRengi(yil: n) }
                        }
                        RenkSecici(secenekler: renkler, secili: $renk)
                    }
                    Section(header: Label("Koloni", systemImage: "hexagon")) {
                        CipSecici(baslik: "Güç", secenekler: [(1, "1 Çok zayıf"), (2, "2 Zayıf"), (3, "3 Orta"), (4, "4 Güçlü"), (5, "5 Çok güçlü")], secili: guc) { guc = $0 }
                        Stepper(value: Binding(get: { Int(cerceve) ?? 0 }, set: { cerceve = $0 > 0 ? String($0) : ""; kat = otomatikKat($0) }), in: 0...40) {
                            HStack { Text("Çerçeve"); Spacer(); Text(cerceve.isEmpty ? "—" : cerceve).font(Yazi.nunito(17, .bold)).foregroundStyle(Renk.orman2) }
                        }
                        CipSecici(baslik: nil, secenekler: [5, 8, 10, 12, 16, 20, 24].map { ($0, "\($0)") }, secili: Int(cerceve)) { cerceve = String($0); kat = otomatikKat($0) }
                        CipSecici(baslik: "Kat", secenekler: (1...4).map { ($0, "\($0) kat") }, secili: kat) { kat = $0 }
                    }
                }
                Section(header: Label("Notlar", systemImage: "note.text")) { TextField("Not", text: $not, axis: .vertical) }
                if kovanId != nil {
                    Section { Button("Kovanı sil", role: .destructive) { silOnay = true } }
                }
            }
            .navigationTitle(kovanId == nil ? "Yeni Kovan" : "Kovanı Düzenle")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { kaydet(); kapat() }.disabled(num.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                BuyukKaydetCubugu(etkin: !num.trimmingCharacters(in: .whitespaces).isEmpty, ipucu: "Önce kovan no yaz") { kaydet(); kapat() }
            }
            .confirmationDialog("Kovan \(num) silinsin mi?", isPresented: $silOnay, titleVisibility: .visible) {
                Button("Sil", role: .destructive) { sil(); kapat() }
            }
            .sheet(isPresented: $tarayici) { BarkodSayfasi { num = $0 } }
            .onAppear(perform: yukle)
        }
    }

    /// Canlı önizleme: seçilen tip ve kata göre kovan görseli.
    private var onizleme: some View {
        HStack(spacing: 12) {
            Image(kovanGorselAdi(tip: tip, kat: kat)).resizable().scaledToFit().frame(width: 96, height: 104)
                .grayscale(anaDurum == "empty" ? 1 : 0).opacity(anaDurum == "empty" ? 0.6 : 1)
            VStack(alignment: .leading, spacing: 5) {
                Text(num.trimmingCharacters(in: .whitespaces).isEmpty ? "Kovan" : "Kovan \(num.trimmingCharacters(in: .whitespaces))")
                    .font(Yazi.nunito(22, .bold)).foregroundStyle(Renk.orman).lineLimit(1)
                Text("\(tip) · \(kat) kat").font(Yazi.kucuk).foregroundStyle(Renk.metin2).lineLimit(1)
                HStack(spacing: 5) {
                    Rozet(metin: durumlar.first { $0.0 == anaDurum }?.1 ?? "", tur: anaDurum == "yes" ? .iyi : anaDurum == "no" ? .kotu : .notr)
                    if anaDurum != "empty", !irk.isEmpty {
                        Rozet(metin: [irk, kusak].filter { !$0.isEmpty }.joined(separator: " · "), simge: "ladybug", arkaRenk: Renk.bal.opacity(0.22))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 18)
        .dogaZemini()
    }

    private var tipListesi: [String] { ensure(depo.kovanTipleri, tip) }
    private var irkListesi: [String] { ensure(depo.irklar, irk) }
    private func ensure(_ l: [String], _ v: String) -> [String] { v.isEmpty || l.contains(v) ? l : l + [v] }

    private func yukle() {
        guard !yuklendi else { return }
        yuklendi = true
        if let k = depo.kovan(kovanId) {
            num = k.num; tip = k.type ?? tip; anaDurum = k.queenStatus == "new" ? "bakire" : (k.queenStatus ?? "yes")
            renk = k.queenColor ?? "white"; isaret = k.mark ?? ""; guc = Int(k.strength ?? "3") ?? 3; irk = k.race ?? ""; kusak = kusakDuzelt(k.generation)
            yil = k.year ?? ""; cerceve = k.frames.map { String(Int($0)) } ?? ""; kat = k.katSayisi; not = k.notes ?? ""
        } else {
            let enBuyuk = depo.veri.kovanlar.map(\.numara).filter { $0 != Int.max }.max() ?? 0
            num = String(enBuyuk + 1)
            tip = depo.kovanTipleri.first ?? "Langstroth"
        }
    }

    private func kaydet() {
        depo.degistir { v in
            var l = v.kovanlar
            var k: Kovan
            let i = l.firstIndex { $0.id == kovanId }
            if let i { k = l[i] } else { k = Kovan(["id": .metin(yeniKimlik()), "createdAt": .metin(bugunISO())]) }
            k.num = num.trimmingCharacters(in: .whitespaces)
            k.type = tip
            k.queenStatus = anaDurum
            k.queenColor = renk
            k.mark = isaret.isEmpty ? nil : isaret
            k.strength = String(guc)
            k.race = irk
            k.generation = kusak
            k.year = yil
            k.frames = Double(cerceve)
            k.floors = Double(kat)
            k.notes = not
            if let i { l[i] = k } else { l.append(k) }
            v.kovanlar = l
        }
    }

    private func sil() {
        guard let id = kovanId else { return }
        depo.degistir { v in
            v.kovanlar = v.kovanlar.filter { $0.id != id }
            v.muayeneler = v.muayeneler.filter { $0.hiveId != id }
            if var lay = v.araziLayout, var p = lay["positions"]?.nesneDegeri {
                p.removeValue(forKey: id)
                lay["positions"] = .nesne(p)
                lay["_up"] = .tam(VeriDeposu.simdiMs)
                v.araziLayout = lay
            }
        }
    }
}

/// Toplu kovan ekleme: başlangıç no + adet (web saveBulkHives).
struct TopluKovanFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    @State private var baslangic = ""
    @State private var adet = 10
    @State private var tip = "Langstroth"
    @State private var anaDurum = "yes"
    @State private var irk = ""
    @State private var guc = 3

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Başlangıç no", text: $baslangic).keyboardType(.numberPad)
                    Stepper("Adet: \(adet)", value: $adet, in: 1...200)
                }
                Section {
                    CipSecici(baslik: "Tip", secenekler: depo.kovanTipleri.map { ($0, $0) }, secili: tip) { tip = $0 }
                    CipSecici(baslik: "Ana arı", secenekler: [("yes", "Ana var"), ("no", "Ana yok"), ("bakire", "Bakire"), ("unknown", "Bilinmiyor"), ("empty", "Arısız")], secili: anaDurum,
                              nokta: { $0 == "empty" ? Color(white: 0.6) : KovanRenkAyari.isimaRengi($0) }) { anaDurum = $0 }
                    if anaDurum != "empty" {
                        CipSecici(baslik: "Irk", secenekler: depo.irklar.map { ($0, $0) }, secili: irk) { irk = irk == $0 ? "" : $0 }
                        CipSecici(baslik: "Güç", secenekler: [(1, "1 Çok zayıf"), (2, "2 Zayıf"), (3, "3 Orta"), (4, "4 Güçlü"), (5, "5 Çok güçlü")], secili: guc) { guc = $0 }
                    }
                }
                if let b = Int(baslangic) { Section { Text("Kovan \(b) – \(b + adet - 1) eklenecek").foregroundStyle(.secondary) } }
            }
            .navigationTitle("Toplu Kovan")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) { Button("Ekle") { ekle(); kapat() }.disabled(Int(baslangic) == nil) }
            }
            .safeAreaInset(edge: .bottom) {
                BuyukKaydetCubugu(metin: "Ekle", etkin: Int(baslangic) != nil, ipucu: "Önce başlangıç no yaz") { ekle(); kapat() }
            }
            .onAppear {
                let enBuyuk = depo.veri.kovanlar.map(\.numara).filter { $0 != Int.max }.max() ?? 0
                baslangic = String(enBuyuk + 1)
            }
        }
    }

    private func ekle() {
        guard let b = Int(baslangic) else { return }
        depo.degistir { v in
            let yeni = (0..<adet).map { i in
                Kovan(["id": .metin(yeniKimlik()), "num": .metin(String(b + i)), "type": .metin(tip), "queenStatus": .metin(anaDurum),
                       "queenColor": .metin("white"), "strength": .metin(String(guc)), "race": .metin(irk), "generation": .metin(""),
                       "year": .metin(""), "notes": .metin(""), "createdAt": .metin(bugunISO())])
            }
            v.kovanlar = v.kovanlar + yeni
        }
    }
}

/// Ana yılı: ✕ temizle, − yıl +; altında "bu yıl" / "N yaş". Boşken ilk dokunuş bu yılı yazar.
struct YilAdim: View {
    let etiket: String
    @Binding var yil: String
    private var buYil: Int { Calendar.current.component(.year, from: Date()) }
    var body: some View {
        HStack(spacing: 10) {
            Text(etiket)
            Spacer()
            if !yil.isEmpty {
                Button { yil = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Renk.metin3) }.buttonStyle(.borderless)
            }
            adim("minus") { yil = String(max(1990, (Int(yil) ?? buYil + 1) - 1)) }
            VStack(spacing: 0) {
                Text(yil.isEmpty ? "—" : yil).font(Yazi.nunito(18, .bold)).foregroundStyle(Renk.orman2)
                if let y = Int(yil) { Text(buYil - y <= 0 ? "bu yıl" : "\(buYil - y) yaş").font(Yazi.minik).foregroundStyle(Renk.metin3) }
            }
            .frame(minWidth: 54)
            adim("plus") { yil = String(min(buYil, (Int(yil) ?? buYil - 1) + 1)) }
        }
    }
    private func adim(_ s: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Image(systemName: s).font(.system(size: 14, weight: .bold)).foregroundStyle(Renk.orman2)
                .frame(width: 34, height: 34).background(Renk.orman2.opacity(0.12), in: Circle())
        }
        .buttonStyle(.borderless)
    }
}

/// Ana arı rengi: renkli daireler, seçilende ✓; boyasız ∅.
struct RenkSecici: View {
    let secenekler: [(String, String)]
    @Binding var secili: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Renk"); Spacer(); Text(secenekler.first { $0.0 == secili }?.1 ?? "").foregroundStyle(Renk.metin2) }
            HStack(spacing: 10) {
                ForEach(secenekler, id: \.0) { kod, ad in
                    Button { secili = kod } label: {
                        ZStack {
                            Circle().fill(kod == "unpainted" ? Color(white: 0.93) : Renk.ana(kod)).frame(width: 38, height: 38)
                                .overlay(Circle().strokeBorder(secili == kod ? Renk.orman2 : .black.opacity(0.2), lineWidth: secili == kod ? 3 : 1))
                            if kod == "unpainted" { Text("∅").font(.system(size: 17)).foregroundStyle(Renk.metin3) }
                            if secili == kod { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(kod == "white" || kod == "yellow" || kod == "unpainted" ? Renk.orman : .white) }
                        }
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(ad)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
