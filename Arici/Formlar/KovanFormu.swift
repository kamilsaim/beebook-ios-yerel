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
                Section {
                    HStack {
                        TextField("Kovan no", text: $num).keyboardType(.numbersAndPunctuation)
                        Button { tarayici = true } label: { Image(systemName: "barcode.viewfinder") }
                    }
                    Picker("Tip", selection: $tip) { ForEach(tipListesi, id: \.self) { Text($0) } }
                    Picker("Ana arı", selection: $anaDurum) { ForEach(durumlar, id: \.0) { Text($0.1).tag($0.0) } }
                }
                if anaDurum != "empty" {
                    Section("Ana arı") {
                        Picker("Irk", selection: $irk) { Text("—").tag(""); ForEach(irkListesi, id: \.self) { Text($0) } }
                        TextField("Kuşak (F1, F2…)", text: $kusak)
                        TextField("Ana yılı", text: $yil).keyboardType(.numberPad)
                            .onChange(of: yil) { _, y in if let n = Int(y), y.count == 4 { renk = anaRengi(yil: n) } }
                        Picker("Renk", selection: $renk) { ForEach(renkler, id: \.0) { Text($0.1).tag($0.0) } }
                    }
                    Section("Koloni") {
                        Stepper("Güç: \(guc)/5", value: $guc, in: 1...5)
                        TextField("Çerçeve sayısı", text: $cerceve).keyboardType(.numberPad)
                        Stepper("Kat: \(kat)", value: $kat, in: 1...4)
                    }
                }
                Section("Notlar") { TextField("Not", text: $not, axis: .vertical) }
                if kovanId != nil {
                    Section { Button("Kovanı sil", role: .destructive) { silOnay = true } }
                }
            }
            .navigationTitle(kovanId == nil ? "Yeni Kovan" : "Kovanı Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { kaydet(); kapat() }.disabled(num.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Kovan \(num) silinsin mi?", isPresented: $silOnay, titleVisibility: .visible) {
                Button("Sil", role: .destructive) { sil(); kapat() }
            }
            .sheet(isPresented: $tarayici) { BarkodSayfasi { num = $0 } }
            .onAppear(perform: yukle)
        }
    }

    private var tipListesi: [String] { ensure(depo.kovanTipleri, tip) }
    private var irkListesi: [String] { ensure(depo.irklar, irk) }
    private func ensure(_ l: [String], _ v: String) -> [String] { v.isEmpty || l.contains(v) ? l : l + [v] }

    private func yukle() {
        guard !yuklendi else { return }
        yuklendi = true
        if let k = depo.kovan(kovanId) {
            num = k.num; tip = k.type ?? tip; anaDurum = k.queenStatus == "new" ? "bakire" : (k.queenStatus ?? "yes")
            renk = k.queenColor ?? "white"; guc = Int(k.strength ?? "3") ?? 3; irk = k.race ?? ""; kusak = k.generation ?? ""
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
                    Picker("Tip", selection: $tip) { ForEach(depo.kovanTipleri, id: \.self) { Text($0) } }
                    Picker("Ana arı", selection: $anaDurum) {
                        Text("Ana var").tag("yes"); Text("Ana yok").tag("no"); Text("Bakire").tag("bakire"); Text("Bilinmiyor").tag("unknown"); Text("Arısız").tag("empty")
                    }
                    Picker("Irk", selection: $irk) { Text("—").tag(""); ForEach(depo.irklar, id: \.self) { Text($0) } }
                    Stepper("Güç: \(guc)/5", value: $guc, in: 1...5)
                }
                if let b = Int(baslangic) { Section { Text("Kovan \(b) – \(b + adet - 1) eklenecek").foregroundStyle(.secondary) } }
            }
            .navigationTitle("Toplu Kovan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) { Button("Ekle") { ekle(); kapat() }.disabled(Int(baslangic) == nil) }
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
