import AriCekirdek
import Foundation

/// `-ornekVeri` başlatma argümanı: Kaynaklar/ornek-veri.json (araclar/ornek-veri-uret.py). Asla gönderilmez.
enum OrnekVeri {
    static func durum() -> DepoDurumu {
        guard let url = Bundle.main.url(forResource: "ornek-veri", withExtension: "json"),
              let veri = try? Data(contentsOf: url),
              let j = try? JSONDecoder().decode(JSONDeger.self, from: veri),
              case .nesne(let d)? = j["data"]
        else { return DepoDurumu() }
        let ayar = j["settings"]?.nesneDegeri.map { Ayarlar(ham: $0) } ?? Ayarlar()
        let v = BBVeri(ham: d)
        return DepoDurumu(veri: v, ayarlar: ayar, anlik: anlikOlustur(v), bekleyen: false)
    }
}
