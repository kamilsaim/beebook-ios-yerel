import Foundation

/// open-meteo (anahtarsız) — web loadWeather ile aynı uç noktalar.
struct HavaDurumu: Equatable, Codable {
    struct Saat: Equatable, Codable, Identifiable { var id: Int { saat }; let saat: Int; let derece: Int; let kod: Int }
    struct Gun: Equatable, Codable, Identifiable { var id: String { tarih }; let tarih: String; let enYuksek: Int; let enDusuk: Int; let kod: Int }
    let sehir: String
    let derece: Int
    let hissedilen: Int
    let kod: Int
    let enYuksek: Int
    let nem: Int
    let ruzgar: Int
    let saatlik: [Saat]
    let gunluk: [Gun]

    var durumMetni: String { HavaDurumu.metin(kod) }
    var simge: String { HavaDurumu.simge(kod) }

    static func metin(_ k: Int) -> String {
        switch k {
        case 0: return "Açık"
        case 1: return "Az bulutlu"
        case 2: return "Parçalı bulutlu"
        case 3: return "Kapalı"
        case 45, 48: return "Sisli"
        case 51...57: return "Çiseleme"
        case 61...67: return "Yağmurlu"
        case 71...77: return "Karlı"
        case 80...82: return "Sağanak"
        case 85, 86: return "Kar sağanağı"
        case 95...99: return "Gök gürültülü"
        default: return "—"
        }
    }

    static func simge(_ k: Int) -> String {
        switch k {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

actor HavaServisi {
    static let paylasilan = HavaServisi()
    private var onbellek: (sehir: String, zaman: Date, hava: HavaDurumu)?

    func getir(sehir: String) async throws -> HavaDurumu {
        if let o = onbellek, o.sehir == sehir, Date().timeIntervalSince(o.zaman) < 15 * 60 { return o.hava }
        let ad = sehir.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sehir
        let geo = try await json(URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(ad)&count=1&language=tr&format=json")!)
        guard let ilk = (geo["results"] as? [[String: Any]])?.first,
              let enlem = ilk["latitude"] as? Double, let boylam = ilk["longitude"] as? Double
        else { throw URLError(.cannotFindHost) }
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(enlem)&longitude=\(boylam)&current=temperature_2m,relative_humidity_2m,wind_speed_10m,apparent_temperature,weather_code&hourly=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=auto&forecast_days=7")!
        let w = try await json(url)
        let c = w["current"] as? [String: Any] ?? [:]
        let h = w["hourly"] as? [String: Any] ?? [:]
        let d = w["daily"] as? [String: Any] ?? [:]
        let sTimes = h["time"] as? [String] ?? []
        let sTemps = h["temperature_2m"] as? [Double] ?? []
        let sCodes = h["weather_code"] as? [Int] ?? []
        let simdiSaat = (c["time"] as? String).flatMap { Int($0.dropFirst(11).prefix(2)) } ?? 0
        let bugun = (c["time"] as? String).map { String($0.prefix(10)) } ?? ""
        var saatlik: [HavaDurumu.Saat] = []
        for (i, t) in sTimes.enumerated() where i < sTemps.count && i < sCodes.count {
            let gun = String(t.prefix(10)), s = Int(t.dropFirst(11).prefix(2)) ?? 0
            if (gun == bugun && s > simdiSaat) || gun > bugun { saatlik.append(.init(saat: s, derece: Int(sTemps[i].rounded()), kod: sCodes[i])) }
            if saatlik.count == 6 { break }
        }
        let gTimes = d["time"] as? [String] ?? []
        let gMax = d["temperature_2m_max"] as? [Double] ?? []
        let gMin = d["temperature_2m_min"] as? [Double] ?? []
        let gKod = d["weather_code"] as? [Int] ?? []
        let gunluk = gTimes.indices.compactMap { i -> HavaDurumu.Gun? in
            guard i < gMax.count, i < gMin.count, i < gKod.count else { return nil }
            return .init(tarih: gTimes[i], enYuksek: Int(gMax[i].rounded()), enDusuk: Int(gMin[i].rounded()), kod: gKod[i])
        }
        let hava = HavaDurumu(
            sehir: ilk["name"] as? String ?? sehir,
            derece: Int(((c["temperature_2m"] as? Double) ?? 0).rounded()),
            hissedilen: Int(((c["apparent_temperature"] as? Double) ?? 0).rounded()),
            kod: c["weather_code"] as? Int ?? 0,
            enYuksek: gunluk.first?.enYuksek ?? 0,
            nem: Int(((c["relative_humidity_2m"] as? Double) ?? 0).rounded()),
            ruzgar: Int(((c["wind_speed_10m"] as? Double) ?? 0).rounded()),
            saatlik: saatlik, gunluk: gunluk)
        onbellek = (sehir, Date(), hava)
        return hava
    }

    private func json(_ url: URL) async throws -> [String: Any] {
        let (veri, _) = try await URLSession.shared.data(from: url)
        return (try JSONSerialization.jsonObject(with: veri)) as? [String: Any] ?? [:]
    }
}
