import AriCekirdek
import PhotosUI
import SwiftUI
import UIKit

/// Ürün ekle/düzenle (görselli). Id asla değişmez; birim değişince eski stok kayıtlarına dokunulmaz.
struct UrunFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(OturumYoneticisi.self) private var oturum
    @Environment(\.dismiss) private var kapat
    let urunId: String?

    @State private var ad = ""
    @State private var birim: Birim = .kg
    @State private var fiyat: Double = 0
    @State private var baslangic: Double = 0
    @State private var zekat = true
    @State private var hazir: String?
    @State private var foto: UIImage?
    @State private var fotoSecim: PhotosPickerItem?
    @State private var kamera = false
    @State private var eskiBirim: Birim?
    @State private var silOnay = false
    @State private var yuklendi = false
    @State private var kaydediliyor = false
    @State private var yuklemeHatasi: String?

    private var hesapli: Bool { oturum.kullaniciId != nil }
    private var hazirUrun: Bool { urunId.map { id in hazirUrunler.contains { $0.v == id } } ?? false }

    var body: some View {
        NavigationStack {
            Form {
                Section("Görsel") {
                    HStack(spacing: 14) {
                        onizleme.frame(width: 92, height: 92)
                        VStack(spacing: 8) {
                            if hesapli {
                                Button { kamera = true } label: { Label("Fotoğraf çek", systemImage: "camera") }
                                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                                PhotosPicker(selection: $fotoSecim, matching: .images) { Label("Galeriden seç", systemImage: "photo") }
                            } else {
                                Text("Fotoğraf için giriş yap; hazır simge seçebilirsin.").font(Yazi.etiket).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.bordered).tint(Renk.orman2)
                    }
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(hazirSimgeler, id: \.self) { s in
                                Button { hazir = s; foto = nil } label: {
                                    Image(s).resizable().scaledToFill().frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(hazir == s && foto == nil ? Renk.bal : .clear, lineWidth: 3))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                Section("Ürün") {
                    TextField("Ad (ör. Bal Sirkesi)", text: $ad).disabled(hazirUrun)
                    Picker("Birim", selection: $birim) { ForEach(Birim.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    if let e = eskiBirim, e != birim {
                        Text("Birim değişti: önceki \(e.rawValue) kayıtları olduğu gibi kalır.").font(Yazi.etiket).foregroundStyle(Renk.uyari)
                    }
                    HStack { Text("Birim fiyat"); TextField("₺", value: $fiyat, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing); Text("/ \(birim.rawValue)").foregroundStyle(.secondary) }
                    if urunId == nil {
                        HStack { Text("Başlangıç stoğu"); TextField("0", value: $baslangic, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing); Text(birim.rawValue).foregroundStyle(.secondary) }
                    }
                    Toggle("Zekat hesabına dahil", isOn: $zekat)
                }
                if urunId != nil && !hazirUrun {
                    Section { Button("Ürünü sil", role: .destructive) { silOnay = true } }
                }
                Section {
                    Text("Fotoğraf telefonda 256×256'ya küçültülür (~25 KB) ve hesabınla eşitlenir. En fazla \(ozelUrunSiniri) ürün eklenebilir.")
                        .font(Yazi.etiket).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(urunId == nil ? "Yeni Ürün" : "Ürünü Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    if kaydediliyor { ProgressView() } else {
                        Button(urunId == nil ? "Ekle" : "Kaydet") { Task { if await kaydet() { kapat() } } }
                            .disabled(ad.trimmingCharacters(in: .whitespaces).isEmpty || (urunId == nil && !urunEklenebilir(depo.ayarlar)))
                    }
                }
            }
            .confirmationDialog("Ürün silinsin mi?", isPresented: $silOnay, titleVisibility: .visible) {
                Button("Sil", role: .destructive) { Task { await sil(); kapat() } }
            } message: { Text("Stok ve satış kayıtları silinmez; ürün listeden kalkar.") }
            .alert("Fotoğraf yüklenemedi", isPresented: Binding(get: { yuklemeHatasi != nil }, set: { if !$0 { yuklemeHatasi = nil; kapat() } })) {
                Button("Tamam", role: .cancel) {}
            } message: { Text("Ürün fotoğrafsız kaydedildi. İnterneti kontrol edip ürünü düzenleyerek tekrar deneyebilirsin. (\(yuklemeHatasi ?? ""))") }
            .sheet(isPresented: $kamera) { KameraSecici { foto = $0; hazir = nil }.ignoresSafeArea() }
            .onChange(of: fotoSecim) { _, s in
                Task { if let d = try? await s?.loadTransferable(type: Data.self), let i = UIImage(data: d) { foto = i; hazir = nil } }
            }
            .onAppear(perform: yukle)
        }
    }

    @ViewBuilder
    private var onizleme: some View {
        if let foto {
            Image(uiImage: foto).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if let hazir {
            Image(hazir).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            UrunGorseli(urun: depo.urunler.first { $0.v == urunId }, boyut: 92, yaricap: 20)
        }
    }

    private func yukle() {
        guard !yuklendi else { return }
        yuklendi = true
        guard let u = depo.urunler.first(where: { $0.v == urunId }) else { return }
        ad = u.temizAd
        birim = Birim(rawValue: u.unit) ?? .kg
        eskiBirim = birim
        fiyat = depo.ayarlar.stockPrices[u.v] ?? 0
        zekat = u.zakat ?? true
        if let i = u.image, i.hasPrefix("hazir:") { hazir = String(i.dropFirst(6)) }
    }

    /// Kaydeder. Fotoğraf yüklenemezse ürün yine kaydedilir, hata gösterilir (false: sayfa uyarıdan sonra kapanır).
    private func kaydet() async -> Bool {
        kaydediliyor = true
        defer { kaydediliyor = false }
        let mevcutListe = depo.urunler
        let id = urunId ?? urunKimligi(ad: ad, mevcut: mevcutListe.map(\.v))
        let eskiGorsel = mevcutListe.first { $0.v == id }?.image
        var gorselAlani: String? = hazir.map { "hazir:\($0)" }
        var hata: String?
        if let foto, let uid = oturum.kullaniciId, let veri = UrunGorselDeposu.hazirla(foto) {
            do {
                gorselAlani = try await UrunGorselDeposu.paylasilan.yukle(veri, kullanici: uid, urunId: id)
            } catch {
                hata = error.localizedDescription
            }
        }
        if let g = gorselAlani, let e = eskiGorsel, e != g, !e.hasPrefix("hazir:") { await UrunGorselDeposu.paylasilan.sil(e) }
        depo.ayarDegistir { a in
            var l = urunListesi(a)
            var u = l.first { $0.v == id } ?? UrunTanimi(["v": .metin(id)])
            if !hazirUrun { u.l = ad.trimmingCharacters(in: .whitespaces) }
            u.unit = birim.rawValue
            u.zakat = zekat
            if let gorselAlani { u.image = gorselAlani }
            if let i = l.firstIndex(where: { $0.v == id }) { l[i] = u } else { l.append(u) }
            a.stockTypes = l
            var p = a.stockPrices
            if fiyat > 0 { p[id] = fiyat } else { p.removeValue(forKey: id) }
            a.stockPrices = p
        }
        if urunId == nil && baslangic > 0 {
            depo.degistir { v in
                var k = StokKaydi(["id": .metin(yeniKimlik())])
                k.product = id; k.action = "in"; k.amount = baslangic; k.unit = birim.rawValue; k.date = bugunISO(); k.note = "Başlangıç stoğu"
                v.stokKayitlari = v.stokKayitlari + [k]
            }
        }
        if let hata { yuklemeHatasi = hata; return false }
        return true
    }

    private func sil() async {
        guard let id = urunId else { return }
        let gorsel = depo.urunler.first { $0.v == id }?.image
        depo.ayarDegistir { a in a.stockTypes = urunListesi(a).filter { $0.v != id } }
        if let g = gorsel, !g.hasPrefix("hazir:") { await UrunGorselDeposu.paylasilan.sil(g) }
    }
}

/// Kamera ile fotoğraf (UIImagePickerController).
struct KameraSecici: UIViewControllerRepresentable {
    let secildi: (UIImage) -> Void
    @Environment(\.dismiss) private var kapat
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ v: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> K { K(self) }
    final class K: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let ust: KameraSecici
        init(_ u: KameraSecici) { ust = u }
        func imagePickerController(_ p: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let i = info[.originalImage] as? UIImage { ust.secildi(i) }
            ust.kapat()
        }
        func imagePickerControllerDidCancel(_ p: UIImagePickerController) { ust.kapat() }
    }
}
