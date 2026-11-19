import Foundation

/// Telefon bildirimine dokununca açılacak yer.
public enum HatirlatmaHedefi: String, Sendable { case anaSayfa, anaAri, satis }

/// Kullanıcının açık tuttuğu hatırlatma türleri (cihaz tercihi; eşitlenmez).
public struct HatirlatmaTurleri: Equatable, Sendable {
    public var anaAri: Bool
    public var isler: Bool
    public var odeme: Bool
    public init(anaAri: Bool = true, isler: Bool = true, odeme: Bool = true) {
        self.anaAri = anaAri; self.isler = isler; self.odeme = odeme
    }
}

/// [id] aynı bildirimi ikilemesin diye bildirim kimliği olarak kullanılır.
public struct Hatirlatma: Equatable, Sendable {
    public let id: String
    public let baslik: String
    public let metin: String
    public let hedef: HatirlatmaHedefi
}

/// Ana arı takviminde hatırlatılan adımlar (transfer günü hariç).
private let hatirlatilanAdimlar: [String: String] = [
    "Kapanma": "Gözler kapandı, rahatsız etme",
    "Pupa": "Pupa dönemi",
    "Dağıtım": "Ana memelerini dağıtma günü",
    "Çıkım": "Analar bugün çıkıyor",
]

/// Sabah bildirimi için günün hatırlatmaları (Android `gunlukHatirlatmalar` ile aynı kural).
/// - Ana arı: aktif (durumu boş da sayılır) serilerde bugün Kapanma +4 / Pupa +6 / Dağıtım +10 / Çıkım +12 ise.
/// - İşler: bugün tarihli + geciken (bitmemiş) işler tek bildirimde.
/// - Ödeme: yalnız pazartesi; bekleyen alacak (ön siparişler hariç, bkz. `kalan`).
public func gunlukHatirlatmalar(_ v: BBVeri, bugun: String, pazartesi: Bool, turler: HatirlatmaTurleri) -> [Hatirlatma] {
    var l: [Hatirlatma] = []
    let b = String(bugun.prefix(10))

    if turler.anaAri {
        for s in v.seriler {
            guard (s.status ?? "active") == "active", let t = s.transfer, !t.isEmpty,
                  let adim = gelisimTakvimi(transfer: t).first(where: { $0.tarih == b && hatirlatilanAdimlar[$0.ad] != nil }) else { continue }
            let ad = s.name.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? "Ana arı serisi"
            l.append(Hatirlatma(id: "ana-\(s.id)-\(adim.ad)", baslik: "\(ad): bugün \(adim.ad) (G+\(adim.gun))",
                                metin: hatirlatilanAdimlar[adim.ad]!, hedef: .anaAri))
        }
    }

    if turler.isler {
        let acik = v.isler.filter { !$0.done && !($0.dueDate ?? "").isEmpty }
        let bugunku = acik.filter { String($0.dueDate!.prefix(10)) == b }
        let geciken = acik.filter { String($0.dueDate!.prefix(10)) < b }
        if !bugunku.isEmpty || !geciken.isEmpty {
            let gecikti = geciken.isEmpty ? nil : "\(geciken.count) iş gecikti"
            let baslik = bugunku.isEmpty ? gecikti! : "Bugün \(bugunku.count) iş var"
            var metin = (bugunku.isEmpty ? geciken : bugunku).prefix(3).map(\.text).joined(separator: " · ")
            if !bugunku.isEmpty, let gecikti { metin += " · \(gecikti)" }
            l.append(Hatirlatma(id: "isler", baslik: baslik, metin: metin, hedef: .anaSayfa))
        }
    }

    if turler.odeme && pazartesi {
        let toplam = bekleyenToplam(satislar: v.satislar)
        if toplam > 0 {
            let kisi = Set(v.satislar.filter { kalan($0.ham) > 0 }.compactMap { s -> String? in
                let c = (s.customer ?? "").trimmingCharacters(in: .whitespaces); return c.isEmpty ? nil : c
            }).count
            l.append(Hatirlatma(id: "odeme", baslik: "\(tl(toplam)) tahsil edilecek", metin: "\(kisi) müşteri", hedef: .satis))
        }
    }
    return l
}
