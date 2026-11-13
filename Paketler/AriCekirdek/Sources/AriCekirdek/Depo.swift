import Foundation

/// Uygulama veri durumu (saf): veri + ayarlar + son anlık görüntü + bekleyen gönderim bayrağı.
/// Web saveData/saveSettings/syncFromSupabase/bbDiscardDemoAndAdopt davranışının karşılığı.
public struct DepoDurumu: Codable, Equatable, Sendable {
    public var veri: BBVeri
    public var ayarlar: Ayarlar
    /// Son kaydedilen hâlin anlık görüntüsü (fark → `_up` damgası / mezar).
    public var anlik: Anlik?
    /// Uzağa gönderilmemiş değişiklik var mı (önbellekle birlikte saklanır).
    public var bekleyen: Bool
    /// Her yerel değişiklikte artar. Gönderim başlarken alınır; gönderim bitince yalnız değişmemişse
    /// `bekleyen` temizlenir (gönderim sürerken yapılan değişiklik kaybolmaz).
    public private(set) var degisiklikSayaci: Int = 0

    public init(veri: BBVeri = BBVeri(), ayarlar: Ayarlar = Ayarlar(), anlik: Anlik? = nil, bekleyen: Bool = false) {
        self.veri = veri
        self.ayarlar = ayarlar
        self.anlik = anlik
        self.bekleyen = bekleyen
    }

    private enum CodingKeys: String, CodingKey { case veri, ayarlar, anlik, bekleyen, degisiklikSayaci }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        veri = try c.decode(BBVeri.self, forKey: .veri)
        ayarlar = try c.decode(Ayarlar.self, forKey: .ayarlar)
        anlik = try c.decodeIfPresent(Anlik.self, forKey: .anlik)
        bekleyen = try c.decodeIfPresent(Bool.self, forKey: .bekleyen) ?? false
        degisiklikSayaci = try c.decodeIfPresent(Int.self, forKey: .degisiklikSayaci) ?? 0
    }

    /// Veri değişikliği: `f` uygulanır, değişen/yeni kayıtlar damgalanır, silinenler mezar olur.
    public mutating func degistir(simdi: Int64, _ f: (inout BBVeri) -> Void) {
        let onceki = anlik ?? anlikOlustur(veri)
        f(&veri)
        let yeni = farkVeDamga(&veri, onceki: onceki, simdi: simdi)
        if yeni != onceki { bekleyen = true; degisiklikSayaci += 1 }
        anlik = yeni
    }

    /// Ayar değişikliği: blob `_up` damgası (web saveSettings).
    public mutating func ayarDegistir(simdi: Int64, _ f: (inout Ayarlar) -> Void) {
        f(&ayarlar)
        ayarlar.ham["_up"] = .tam(simdi)
        bekleyen = true
        degisiklikSayaci += 1
    }

    /// Uzak veriyle kayıt bazlı birleştir. Yerel demo veri varsa atılır, uzak benimsenir.
    @discardableResult
    public mutating func uzakIleBirlestir(_ uzakVeri: BBVeri?, _ uzakAyar: Ayarlar?) -> (yerelKirli: Bool, uzakKirli: Bool) {
        if veri.demo, uzakVeri != nil {
            veri = uzakVeri ?? BBVeri()
            veri.ham.removeValue(forKey: "_demo")
            ayarlar = uzakAyar ?? ayarlar
            anlik = anlikOlustur(veri)
            bekleyen = false
            return (true, false)
        }
        let r = veriBirlestir(yerel: veri, uzak: uzakVeri)
        let a = ayarBirlestir(yerel: ayarlar, uzak: uzakAyar)
        let ayarYerelKirli = a != ayarlar
        let ayarUzakKirli = kararliMetin(.nesne(a.ham)) != kararliMetin(.nesne((uzakAyar ?? Ayarlar()).ham))
        veri = r.birlesik
        ayarlar = a
        anlik = anlikOlustur(veri)
        bekleyen = r.uzakKirli || ayarUzakKirli
        return (r.yerelKirli || ayarYerelKirli, bekleyen)
    }

    /// Gönderim başarılı.
    public mutating func gonderildi() { bekleyen = false }

    /// Gönderim başarılı; gönderim başladığından beri değişiklik olmadıysa `bekleyen` temizlenir.
    public mutating func gonderildi(sayac: Int) { if sayac == degisiklikSayaci { bekleyen = false } }

    /// Hiç sezon yoksa bir kez "YYYY Sezonu" oluşturur ve aktif yapar. Oluşturduysa true.
    @discardableResult
    public mutating func sezonYoksaOlustur(buYil: Int, simdi: Int64) -> Bool {
        guard veri.sezonlar.isEmpty else { return false }
        // Damgasız (_up = 0): aynı id'li uzak sezon ve uzak ayarlar birleştirmede kazanır (web kullanıcısının
        // ayarları otomatik varsayılanla ezilmez). Yalnız uzak veri çekildikten sonra ya da hesapsız kipte çağrılmalı.
        let id = "s\(buYil)"
        veri.sezonlar = [Sezon(["id": .metin(id), "year": .tam(Int64(buYil)), "name": .metin("\(buYil) Sezonu"),
                                "active": .bool(true), "start": .metin("\(buYil)-01-01"), "_up": .tam(0)])]
        anlik = anlikOlustur(veri)
        if ayarlar.activeSeason == nil { ayarlar.ham["activeSeason"] = .metin(id) }
        bekleyen = true
        degisiklikSayaci += 1
        return true
    }

    public func kodla() throws -> Data { try JSONEncoder().encode(self) }
    public static func coz(_ d: Data) throws -> DepoDurumu { try JSONDecoder().decode(DepoDurumu.self, from: d) }
}
