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

    public init(veri: BBVeri = BBVeri(), ayarlar: Ayarlar = Ayarlar(), anlik: Anlik? = nil, bekleyen: Bool = false) {
        self.veri = veri
        self.ayarlar = ayarlar
        self.anlik = anlik
        self.bekleyen = bekleyen
    }

    /// Veri değişikliği: `f` uygulanır, değişen/yeni kayıtlar damgalanır, silinenler mezar olur.
    public mutating func degistir(simdi: Int64, _ f: (inout BBVeri) -> Void) {
        let onceki = anlik ?? anlikOlustur(veri)
        f(&veri)
        let yeni = farkVeDamga(&veri, onceki: onceki, simdi: simdi)
        if yeni != onceki { bekleyen = true }
        anlik = yeni
    }

    /// Ayar değişikliği: blob `_up` damgası (web saveSettings).
    public mutating func ayarDegistir(simdi: Int64, _ f: (inout Ayarlar) -> Void) {
        f(&ayarlar)
        ayarlar.ham["_up"] = .tam(simdi)
        bekleyen = true
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

    /// Hiç sezon yoksa bir kez "YYYY Sezonu" oluşturur ve aktif yapar. Oluşturduysa true.
    @discardableResult
    public mutating func sezonYoksaOlustur(buYil: Int, simdi: Int64) -> Bool {
        guard veri.sezonlar.isEmpty else { return false }
        let id = "s\(buYil)"
        degistir(simdi: simdi) { v in
            v.sezonlar = [Sezon(["id": .metin(id), "year": .tam(Int64(buYil)), "name": .metin("\(buYil) Sezonu"),
                                 "active": .bool(true), "start": .metin("\(buYil)-01-01")])]
        }
        ayarDegistir(simdi: simdi) { $0.activeSeason = id }
        return true
    }

    public func kodla() throws -> Data { try JSONEncoder().encode(self) }
    public static func coz(_ d: Data) throws -> DepoDurumu { try JSONDecoder().decode(DepoDurumu.self, from: d) }
}
