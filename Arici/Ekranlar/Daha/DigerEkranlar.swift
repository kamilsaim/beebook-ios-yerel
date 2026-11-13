import AriCekirdek
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Raporlar (web Özet sayfası)

struct RaporlarEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    var body: some View {
        let k = depo.veri.kovanlar
        let s = depo.sezonda(depo.veri.satislar)
        let g = depo.sezonda(depo.veri.giderler)
        let gelir = s.reduce(0) { $0 + ($1.total ?? 0) }, gider = g.reduce(0) { $0 + ($1.amount ?? 0) }
        List {
            Section("Finans (sezon)") {
                satir("Gelir", tl(gelir)); satir("Gider", tl(gider)); satir("Net", tl(gelir - gider)).bold()
                satir("Bekleyen tahsilat", tl(bekleyenToplam(satislar: s)))
            }
            Section("Kovanlar") {
                dagilim(Dictionary(grouping: k) { $0.type ?? "—" }.mapValues(\.count))
            }
            Section("Ana arı durumu") {
                dagilim(Dictionary(grouping: k) { $0.anaDurumMetni }.mapValues(\.count))
            }
            Section("Irklar") {
                dagilim(Dictionary(grouping: k.filter { !($0.race ?? "").isEmpty }) { $0.race! }.mapValues(\.count))
            }
            Section("Üretim (sezon)") {
                satir("Arı sütü hasadı", miktar(depo.sezonda(depo.veri.hasatlar).reduce(0) { $0 + ($1.amount ?? 0) }, "gr"))
                ForEach(stokRaporu(depo.veri, urunler: depo.urunler), id: \.urun) { r in
                    let u = depo.urunler.first { $0.v == r.urun }
                    satir(u?.temizAd ?? r.urun, "\(miktar(r.mevcut, u?.unit ?? "")) mevcut")
                }
            }
        }
    }
    private func satir(_ a: String, _ b: String) -> some View { HStack { Text(a); Spacer(); Text(b).foregroundStyle(.secondary) } }
    @ViewBuilder private func dagilim(_ d: [String: Int]) -> some View {
        let toplam = max(1, d.values.reduce(0, +))
        ForEach(d.sorted { $0.value > $1.value }, id: \.key) { e in
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text(e.key); Spacer(); Text("\(e.value)").bold() }
                GeometryReader { geo in Capsule().fill(Renk.bal).frame(width: geo.size.width * CGFloat(e.value) / CGFloat(toplam), height: 6) }.frame(height: 6)
            }
        }
    }
}

// MARK: - Sezonlar

struct SezonlarEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var yeni = false
    var body: some View {
        let sezonlar = depo.veri.sezonlar.sorted { sezonBaslangici($0) > sezonBaslangici($1) }
        List {
            Section(footer: Text("Satış, gider ve arı sütü aktif sezona göre gösterilir. Kovanlar, ana arılar ve stok sezon-üstüdür.")) {
                ForEach(sezonlar, id: \.id) { s in
                    HStack {
                        VStack(alignment: .leading) { Text(s.name ?? "Sezon").bold(); Text("\(kisaTarih(sezonBaslangici(s))) \(String(sezonBaslangici(s).prefix(4))) başlangıç").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        if s.id == depo.ayarlar.activeSeason { Rozet(metin: "Aktif", tur: .iyi) }
                        else { Button("Aktifleştir") { depo.ayarDegistir { $0.activeSeason = s.id } }.buttonStyle(.bordered) }
                    }
                }
                .onDelete { idx in
                    let s = idx.map { sezonlar[$0].id }.filter { $0 != depo.ayarlar.activeSeason }
                    depo.degistir { v in v.sezonlar = v.sezonlar.filter { !s.contains($0.id) } }
                }
            }
        }
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { yeni = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $yeni) { SezonFormu() }
    }
}

struct SezonFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    @State private var ad = "\(Calendar.current.component(.year, from: Date()) + 1) Sezonu"
    @State private var baslangic = Date()
    var body: some View {
        NavigationStack {
            Form {
                TextField("Ad", text: $ad)
                DatePicker("Başlangıç", selection: $baslangic, displayedComponents: .date)
                Text("Oluşturulunca aktif sezon olur.").font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle("Yeni Sezon").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Oluştur") {
                        let id = yeniKimlik()
                        let yil = Calendar.current.component(.year, from: baslangic)
                        depo.degistir { v in
                            v.sezonlar = v.sezonlar + [Sezon(["id": .metin(id), "year": .tam(Int64(yil)), "name": .metin(ad), "active": .bool(true), "start": .metin(bugunISO(baslangic))])]
                        }
                        depo.ayarDegistir { $0.activeSeason = id }
                        kapat()
                    }.disabled(ad.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Hava

struct HavaEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var hava: HavaDurumu?
    @State private var sehir = ""
    var body: some View {
        List {
            Section("Şehir") {
                TextField("Şehir", text: $sehir).onSubmit { depo.ayarDegistir { $0.city = sehir } }
            }
            if let hava {
                Section("Şimdi") {
                    HStack { Image(systemName: hava.simge).symbolRenderingMode(.multicolor).font(.largeTitle); Text("\(hava.derece)°").font(.largeTitle); Text(hava.durumMetni) }
                    Text("Hissedilen \(hava.hissedilen)° · Nem %\(hava.nem) · Rüzgâr \(hava.ruzgar) km/s").font(.caption)
                }
                Section("7 gün") {
                    ForEach(hava.gunluk) { g in
                        HStack { Text(kisaTarih(g.tarih)).frame(width: 60, alignment: .leading); Image(systemName: HavaDurumu.simge(g.kod)).symbolRenderingMode(.multicolor); Spacer(); Text("\(g.enDusuk)° / \(g.enYuksek)°") }
                    }
                }
            }
        }
        .task(id: depo.ayarlar.city) {
            sehir = depo.ayarlar.city ?? "Muğla"
            hava = try? await HavaServisi.paylasilan.getir(sehir: sehir)
        }
    }
}

// MARK: - Yedek

struct YedekDosyasi: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var veri: Data
    init(veri: Data) { self.veri = veri }
    init(configuration: ReadConfiguration) throws { veri = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: veri) }
}

struct YedekEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @State private var disari = false
    @State private var iceri = false
    @State private var bekleyenIce: (BBVeri, Ayarlar?)?
    @State private var mesaj: String?

    var body: some View {
        List {
            Section(footer: Text("Yedek dosyası web Beebook ile aynı biçimdedir; iki yönde de yüklenebilir.")) {
                if let s = depo.ayarlar.lastBackup { Text("Son yedek: \(kisaTarih(s))") }
                Button { disari = true } label: { Label("Yedek al (JSON)", systemImage: "square.and.arrow.up") }
                Button { iceri = true } label: { Label("Yedek yükle", systemImage: "square.and.arrow.down") }
            }
            if let mesaj { Section { Text(mesaj) } }
        }
        .fileExporter(isPresented: $disari, document: YedekDosyasi(veri: yedekVerisi()), contentType: .json, defaultFilename: "beebook-yedek-\(bugunISO()).json") { s in
            if case .success = s { depo.ayarDegistir { $0.lastBackup = bugunISO() }; mesaj = "Yedek kaydedildi." }
        }
        .fileImporter(isPresented: $iceri, allowedContentTypes: [.json]) { s in
            guard case .success(let url) = s else { return }
            let erisim = url.startAccessingSecurityScopedResource()
            defer { if erisim { url.stopAccessingSecurityScopedResource() } }
            do {
                let j = try JSONDecoder().decode(JSONDeger.self, from: Data(contentsOf: url))
                bekleyenIce = try yedegiNormallestir(j, buYil: Calendar.current.component(.year, from: Date()))
            } catch { mesaj = "Yedek okunamadı: dosya bozuk ya da Beebook yedeği değil." }
        }
        .confirmationDialog("Yedek yüklensin mi?", isPresented: Binding(get: { bekleyenIce != nil }, set: { if !$0 { bekleyenIce = nil } }), titleVisibility: .visible) {
            Button("Yükle (mevcut verinin yerine)", role: .destructive) {
                if let b = bekleyenIce { depo.tumunuDegistir(veri: b.0, ayarlar: b.1); mesaj = "Yedek yüklendi." }
                bekleyenIce = nil
            }
        } message: { Text("Mevcut kovan, satış ve diğer kayıtlar yedektekiyle değiştirilir.") }
    }

    private func yedekVerisi() -> Data {
        let j: JSONDeger = .nesne([
            "version": .metin(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.0"),
            "exportDate": .metin(ISO8601DateFormatter().string(from: Date())),
            "data": .nesne(depo.veri.ham), "settings": .nesne(depo.ayarlar.ham)])
        return (try? JSONEncoder().encode(j)) ?? Data()
    }
}

// MARK: - Ayarlar

struct AyarlarEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(OturumYoneticisi.self) private var oturum
    @Environment(\.openURL) private var ac
    @State private var silOnay1 = false
    @State private var silOnay2 = false
    @State private var mesaj: String?
    @State private var yeniTip = ""
    @State private var yeniIrk = ""

    var body: some View {
        List {
            Section("Hesap") {
                if oturum.durum == .hesapsiz {
                    Text("Hesapsız kullanıyorsun; veriler yalnız bu telefonda.").font(.caption)
                    Button("Giriş yap ve eşitle") { oturum.girisEkraninaDon() }
                } else {
                    LabeledContent("Ad", value: oturum.adSoyad)
                    LabeledContent("E-posta", value: oturum.epostaGorunen)
                    if depo.esitleniyor { Label("Eşitleniyor…", systemImage: "arrow.triangle.2.circlepath") }
                    else if let h = depo.sonHata { Label("Eşitlenemedi: \(h)", systemImage: "exclamationmark.icloud").foregroundStyle(Renk.uyari) }
                    else { Label("Eşitlendi", systemImage: "checkmark.icloud").foregroundStyle(Renk.iyi) }
                }
            }
            Section("Profil") {
                TextField("Adın", text: Binding(get: { depo.ayarlar.userName ?? "" }, set: { v in depo.ayarDegistir { $0.userName = v } }))
                TextField("Telefon", text: Binding(get: { depo.ayarlar.userPhone ?? "" }, set: { v in depo.ayarDegistir { $0.userPhone = v } })).keyboardType(.phonePad)
                TextField("Hava durumu şehri", text: Binding(get: { depo.ayarlar.city ?? "" }, set: { v in depo.ayarDegistir { $0.city = v } }))
            }
            Section("Kovan tipleri") {
                ForEach(depo.kovanTipleri, id: \.self) { Text($0) }
                    .onDelete { i in let l = depo.kovanTipleri; depo.ayarDegistir { a in a.hiveTypes = l.enumerated().filter { !i.contains($0.offset) }.map(\.element) } }
                    .onMove { f, t in var l = depo.kovanTipleri; l.move(fromOffsets: f, toOffset: t); depo.ayarDegistir { $0.hiveTypes = l } }
                HStack { TextField("Yeni tip", text: $yeniTip); Button("Ekle") { let l = depo.kovanTipleri + [yeniTip]; depo.ayarDegistir { $0.hiveTypes = l }; yeniTip = "" }.disabled(yeniTip.isEmpty) }
            }
            Section("Arı ırkları") {
                ForEach(depo.irklar, id: \.self) { Text($0) }
                    .onDelete { i in let l = depo.irklar; depo.ayarDegistir { a in a.beeRaces = l.enumerated().filter { !i.contains($0.offset) }.map(\.element) } }
                HStack { TextField("Yeni ırk", text: $yeniIrk); Button("Ekle") { let l = depo.irklar + [yeniIrk]; depo.ayarDegistir { $0.beeRaces = l }; yeniIrk = "" }.disabled(yeniIrk.isEmpty) }
            }
            Section {
                Button("Gizlilik politikası") { ac(Sabitler.gizlilik) }
                if oturum.durum == .girisli {
                    Button("Çıkış yap") { Task { await oturum.cikis() } }
                    Button("Hesabımı sil", role: .destructive) { silOnay1 = true }
                }
            } footer: { Text("BeeBook \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")") }
            if let mesaj { Section { Text(mesaj) } }
        }
        .confirmationDialog("Hesabın silinsin mi?", isPresented: $silOnay1, titleVisibility: .visible) {
            Button("Devam", role: .destructive) { silOnay2 = true }
        } message: { Text("Tüm Beebook verilerin (kovanlar, satışlar, ürün fotoğrafları) kalıcı olarak silinir.") }
        .alert("GERİ ALINAMAZ", isPresented: $silOnay2) {
            Button("Vazgeç", role: .cancel) {}
            Button("Hesabımı sil", role: .destructive) {
                Task {
                    do { let tum = try await oturum.hesabiSil(); _ = tum } catch { mesaj = "Silinemedi: \(error.localizedDescription)" }
                }
            }
        } message: { Text("Bu işlem geri alınamaz. Emin misin?") }
    }
}
