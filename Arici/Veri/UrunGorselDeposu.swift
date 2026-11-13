import AriCekirdek
import Supabase
import SwiftUI
import UIKit

/// Ürün fotoğrafları: Supabase Storage `beebook-urun/{uid}/{urunId}.jpg` (özel, RLS). ≤256 px kare, ~25 KB JPEG.
actor UrunGorselDeposu {
    static let paylasilan = UrunGorselDeposu()
    private var bellek: [String: UIImage] = [:]

    private var klasor: URL {
        let k = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("urun-gorsel")
        try? FileManager.default.createDirectory(at: k, withIntermediateDirectories: true)
        return k
    }
    private func dosya(_ yol: String) -> URL { klasor.appendingPathComponent(yol.replacingOccurrences(of: "/", with: "_")) }

    /// Kare kırpar, 256 px'e küçültür, ~30 KB'ı aşmayana dek kaliteyi düşürür.
    static func hazirla(_ img: UIImage) -> Data? {
        let kenar = min(img.size.width, img.size.height)
        let kirp = CGRect(x: (img.size.width - kenar) / 2, y: (img.size.height - kenar) / 2, width: kenar, height: kenar)
        let hedef = CGSize(width: 256, height: 256)
        let bicim = UIGraphicsImageRendererFormat(); bicim.scale = 1
        let kucuk = UIGraphicsImageRenderer(size: hedef, format: bicim).image { _ in
            img.draw(in: CGRect(x: -kirp.minX * 256 / kenar, y: -kirp.minY * 256 / kenar,
                                width: img.size.width * 256 / kenar, height: img.size.height * 256 / kenar))
        }
        var q: CGFloat = 0.7
        var veri = kucuk.jpegData(compressionQuality: q)
        while let v = veri, v.count > 30_000, q > 0.15 { q -= 0.1; veri = kucuk.jpegData(compressionQuality: q) }
        return veri
    }

    func yukle(_ veri: Data, kullanici: String, urunId: String) async throws -> String {
        let yol = "\(kullanici)/\(urunId).jpg"
        try await supabase.storage.from(Sabitler.urunBucket)
            .upload(yol, data: veri, options: FileOptions(contentType: "image/jpeg", upsert: true))
        try? veri.write(to: dosya(yol))
        bellek[yol] = UIImage(data: veri)
        return yol
    }

    func gorsel(_ yol: String) async -> UIImage? {
        if let b = bellek[yol] { return b }
        if let d = try? Data(contentsOf: dosya(yol)), let i = UIImage(data: d) { bellek[yol] = i; return i }
        guard let d = try? await supabase.storage.from(Sabitler.urunBucket).download(path: yol), let i = UIImage(data: d) else { return nil }
        try? d.write(to: dosya(yol))
        bellek[yol] = i
        return i
    }

    func sil(_ yol: String) async {
        bellek[yol] = nil
        try? FileManager.default.removeItem(at: dosya(yol))
        _ = try? await supabase.storage.from(Sabitler.urunBucket).remove(paths: [yol])
    }
}

/// Hazır simge adları (ürün id → Assets).
func hazirSimge(_ urunId: String) -> String? {
    switch urunId {
    case "suzme_bal": return "UrunSuzme"
    case "petek_bal": return "UrunPetek"
    case "karakovan_bal": return "UrunKarakovan"
    case "ari_sutu": return "UrunSut"
    case "polen": return "UrunPolen"
    case "ana_ari": return "UrunAnaari"
    case "kovan", "arili_kovan", "ari": return "UrunKovan"
    default: return nil
    }
}

let hazirSimgeler = ["UrunSuzme", "UrunPetek", "UrunKarakovan", "UrunPolen", "UrunSut", "UrunKovan", "UrunAnaari"]

/// Ürün görseli: kullanıcı fotoğrafı (`<uid>/<id>.jpg`), hazır simge (`hazir:Ad`) ya da yer tutucu şişe.
struct UrunGorseli: View {
    let urun: UrunTanimi?
    var boyut: CGFloat = 46
    var yaricap: CGFloat = 13
    @State private var foto: UIImage?

    var body: some View {
        ZStack {
            if let foto {
                Image(uiImage: foto).resizable().scaledToFill()
            } else if let ad = simgeAdi {
                Image(ad).resizable().scaledToFill()
            } else {
                ZStack {
                    Color(red: 0.99, green: 0.95, blue: 0.86)
                    Image(systemName: urun?.unit == "lt" || urun?.unit == "ml" ? "waterbottle.fill" : "shippingbox.fill")
                        .font(.system(size: boyut * 0.45)).foregroundStyle(Renk.bal)
                }
                .overlay(RoundedRectangle(cornerRadius: yaricap, style: .continuous).strokeBorder(Color(red: 0.82, green: 0.72, blue: 0.48), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])))
            }
        }
        .frame(width: boyut, height: boyut)
        .clipShape(RoundedRectangle(cornerRadius: yaricap, style: .continuous))
        .task(id: urun?.image) {
            guard let y = urun?.image, !y.isEmpty, !y.hasPrefix("hazir:") else { foto = nil; return }
            foto = await UrunGorselDeposu.paylasilan.gorsel(y)
        }
        .accessibilityHidden(true)
    }

    private var simgeAdi: String? {
        if let i = urun?.image, i.hasPrefix("hazir:") { return String(i.dropFirst(6)) }
        return urun.flatMap { hazirSimge($0.v) }
    }
}
