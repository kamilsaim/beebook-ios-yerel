import PhotosUI
import SwiftUI
import Vision
import VisionKit

/// Arıcı plakası (Code39, 12 hane) ve diğer barkodlar: VisionKit canlı tarama; desteklenmezse fotoğraftan okuma.
struct BarkodSayfasi: View {
    @Environment(\.dismiss) private var kapat
    let okundu: (String) -> Void
    @State private var secim: PhotosPickerItem?
    @State private var hata: String?

    private var canliVar: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if canliVar {
                    CanliTarayici { kod in bitir(kod) }.ignoresSafeArea()
                    RoundedRectangle(cornerRadius: 14).strokeBorder(Renk.bal, lineWidth: 3)
                        .frame(width: 300, height: 120)
                        .allowsHitTesting(false)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.metering.unknown").font(.system(size: 40)).foregroundStyle(Renk.bal)
                        Text("Bu cihazda canlı tarama yok.\nPlakanın fotoğrafını seçebilirsin.").multilineTextAlignment(.center).foregroundStyle(.white)
                    }
                }
                VStack {
                    Spacer()
                    if let hata { Text(hata).font(Yazi.kucukOrta).foregroundStyle(.white).padding(8).background(.black.opacity(0.6), in: Capsule()) }
                    PhotosPicker(selection: $secim, matching: .images) {
                        Label("Fotoğraftan oku", systemImage: "photo").font(Yazi.govdeOrta)
                            .padding(.horizontal, 18).frame(height: 46)
                            .background(Renk.bal, in: Capsule()).foregroundStyle(Renk.ormanKoyu)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Barkod Tara")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Kapat") { kapat() } } }
            .onChange(of: secim) { _, s in
                guard let s else { return }
                Task {
                    if let d = try? await s.loadTransferable(type: Data.self), let kod = await fotograftanOku(d) { bitir(kod) }
                    else { hata = "Fotoğrafta barkod bulunamadı" }
                }
            }
        }
    }

    private func bitir(_ kod: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        okundu(kod.trimmingCharacters(in: .whitespacesAndNewlines))
        kapat()
    }

    private func fotograftanOku(_ veri: Data) async -> String? {
        await Task.detached {
            guard let img = UIImage(data: veri)?.cgImage else { return nil }
            let istek = VNDetectBarcodesRequest()
            istek.symbologies = [.code39, .code39Checksum, .code128, .ean13, .itf14, .codabar, .qr]
            try? VNImageRequestHandler(cgImage: img).perform([istek])
            return istek.results?.compactMap(\.payloadStringValue).first
        }.value
    }
}

private struct CanliTarayici: UIViewControllerRepresentable {
    let okundu: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let v = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.code39, .code39Checksum, .code128, .ean13, .itf14, .codabar, .qr])],
            qualityLevel: .accurate, recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true)
        v.delegate = context.coordinator
        try? v.startScanning()
        return v
    }

    func updateUIViewController(_ v: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Koordinator { Koordinator(okundu: okundu) }

    final class Koordinator: NSObject, DataScannerViewControllerDelegate {
        let okundu: (String) -> Void
        private var bitti = false
        init(okundu: @escaping (String) -> Void) { self.okundu = okundu }
        func dataScanner(_ s: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !bitti else { return }
            for i in items {
                if case .barcode(let b) = i, let p = b.payloadStringValue, !p.isEmpty {
                    bitti = true
                    s.stopScanning()
                    DispatchQueue.main.async { self.okundu(p) }
                    return
                }
            }
        }
    }
}
