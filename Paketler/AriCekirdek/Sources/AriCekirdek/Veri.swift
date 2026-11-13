import Foundation

public typealias Kayit = [String: JSONDeger]

extension Dictionary where Key == String, Value == JSONDeger {
    public var id: String? { self["id"]?.metinDegeri }
    /// `_up` damgası (ms); yoksa 0 (eski kayıt).
    public var up: Int64 {
        switch self["_up"] {
        case .tam(let i)?: return i
        case .ondalik(let d)?: return Int64(d)
        default: return 0
        }
    }
}

// MARK: - Alan erişim yardımcıları (tüm görünümler kullanır)

public protocol HamKayitli {
    var ham: Kayit { get set }
}

extension HamKayitli {
    public var id: String { ham.id ?? "" }

    func metin(_ k: String) -> String? { ham[k]?.metinDegeri }
    mutating func metinYaz(_ k: String, _ v: String?) {
        if let v { ham[k] = .metin(v) } else { ham.removeValue(forKey: k) }
    }
    func sayi(_ k: String) -> Double? { ham[k]?.sayi }
    mutating func sayiYaz(_ k: String, _ v: Double?) {
        if let v { ham[k] = .sayidan(v) } else { ham.removeValue(forKey: k) }
    }
    func bool(_ k: String) -> Bool? { ham[k]?.boolDegeri }
    mutating func boolYaz(_ k: String, _ v: Bool?) {
        if let v { ham[k] = .bool(v) } else { ham.removeValue(forKey: k) }
    }
    func metinler(_ k: String) -> [String]? { ham[k]?.diziDegeri?.compactMap { $0.metinDegeri } }
    mutating func metinlerYaz(_ k: String, _ v: [String]?) {
        if let v { ham[k] = .dizi(v.map { .metin($0) }) } else { ham.removeValue(forKey: k) }
    }
}

// MARK: - Tüm veri (user_data.data)

public struct BBVeri: Codable, Equatable, Sendable {
    public var ham: [String: JSONDeger]

    /// Kayıt bazlı eşitlenen koleksiyonlar. Web `BB_SYNC_COLLECTIONS` + `inspections` (web v2.7.0 ile aynı).
    public static let esitlenenler = ["hives", "sales", "expenses", "milk", "queens", "tasks", "seasons", "stock", "inventory", "inspections"]

    public init(ham: [String: JSONDeger] = [:]) { self.ham = ham }

    public init(from decoder: Decoder) throws {
        let d = try JSONDeger(from: decoder)
        guard case .nesne(let o) = d else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "data nesne değil"))
        }
        ham = o
    }

    public func encode(to encoder: Encoder) throws { try JSONDeger.nesne(ham).encode(to: encoder) }

    public func koleksiyon(_ ad: String) -> [Kayit] {
        (ham[ad]?.diziDegeri ?? []).compactMap { $0.nesneDegeri }
    }

    public mutating func koleksiyonYaz(_ ad: String, _ k: [Kayit]) {
        ham[ad] = .dizi(k.map { .nesne($0) })
    }

    func gorunumler<T: HamKayitli>(_ ad: String, _ yap: (Kayit) -> T) -> [T] { koleksiyon(ad).map(yap) }
    mutating func gorunumYaz<T: HamKayitli>(_ ad: String, _ g: [T]) { koleksiyonYaz(ad, g.map(\.ham)) }

    public var kovanlar: [Kovan] { get { gorunumler("hives", Kovan.init) } set { gorunumYaz("hives", newValue) } }
    public var satislar: [Satis] { get { gorunumler("sales", Satis.init) } set { gorunumYaz("sales", newValue) } }
    public var giderler: [Gider] { get { gorunumler("expenses", Gider.init) } set { gorunumYaz("expenses", newValue) } }
    public var hasatlar: [Hasat] { get { gorunumler("milk", Hasat.init) } set { gorunumYaz("milk", newValue) } }
    public var seriler: [AnaSeri] { get { gorunumler("queens", AnaSeri.init) } set { gorunumYaz("queens", newValue) } }
    public var isler: [Is] { get { gorunumler("tasks", Is.init) } set { gorunumYaz("tasks", newValue) } }
    public var sezonlar: [Sezon] { get { gorunumler("seasons", Sezon.init) } set { gorunumYaz("seasons", newValue) } }
    public var stokKayitlari: [StokKaydi] { get { gorunumler("stock", StokKaydi.init) } set { gorunumYaz("stock", newValue) } }
    public var envanter: [EnvanterKalemi] { get { gorunumler("inventory", EnvanterKalemi.init) } set { gorunumYaz("inventory", newValue) } }
    public var muayeneler: [Muayene] { get { gorunumler("inspections", Muayene.init) } set { gorunumYaz("inspections", newValue) } }

    /// `araziLayout` blob'u (positions, spacers, _up) — ham olarak.
    public var araziLayout: Kayit? {
        get { ham["araziLayout"]?.nesneDegeri }
        set { if let n = newValue { ham["araziLayout"] = .nesne(n) } else { ham.removeValue(forKey: "araziLayout") } }
    }

    public var demo: Bool { ham["_demo"]?.boolDegeri ?? false }
}

// MARK: - Ayarlar (user_data.settings)

public struct Ayarlar: Codable, Equatable, Sendable, HamKayitli {
    public var ham: Kayit

    public init(ham: Kayit = [:]) { self.ham = ham }

    public init(from decoder: Decoder) throws {
        let d = try JSONDeger(from: decoder)
        guard case .nesne(let o) = d else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "settings nesne değil"))
        }
        ham = o
    }

    public func encode(to encoder: Encoder) throws { try JSONDeger.nesne(ham).encode(to: encoder) }

    public var city: String? { get { metin("city") } set { metinYaz("city", newValue) } }
    public var userName: String? { get { metin("userName") } set { metinYaz("userName", newValue) } }
    public var userPhone: String? { get { metin("userPhone") } set { metinYaz("userPhone", newValue) } }
    public var activeSeason: String? { get { metin("activeSeason") } set { metinYaz("activeSeason", newValue) } }
    public var hiveView: String? { get { metin("hiveView") } set { metinYaz("hiveView", newValue) } }
    public var lastBackup: String? { get { metin("lastBackup") } set { metinYaz("lastBackup", newValue) } }
    public var hiveTypes: [String]? { get { metinler("hiveTypes") } set { metinlerYaz("hiveTypes", newValue) } }
    public var beeRaces: [String]? { get { metinler("beeRaces") } set { metinlerYaz("beeRaces", newValue) } }
    public var saleTypeOrder: [String]? { get { metinler("saleTypeOrder") } set { metinlerYaz("saleTypeOrder", newValue) } }
    public var qrLastPass: Double? { get { sayi("qrLastPass") } set { sayiYaz("qrLastPass", newValue) } }

    /// `{v, l}` listesi (gider türleri) — ham.
    public var expenseTypes: [Kayit]? {
        get { ham["expenseTypes"]?.diziDegeri?.compactMap { $0.nesneDegeri } }
        set { if let n = newValue { ham["expenseTypes"] = .dizi(n.map { .nesne($0) }) } else { ham.removeValue(forKey: "expenseTypes") } }
    }

    public var stockPrices: [String: Double] {
        get { (ham["stockPrices"]?.nesneDegeri ?? [:]).compactMapValues { $0.sayi } }
        set { ham["stockPrices"] = .nesne(newValue.mapValues { .sayidan($0) }) }
    }

    /// Tanımlı değilse nil (web `DEFAULT_STOCK_TYPES` kullanır).
    public var stockTypes: [UrunTanimi] {
        get { (ham["stockTypes"]?.diziDegeri ?? []).compactMap { $0.nesneDegeri }.map(UrunTanimi.init) }
        set { ham["stockTypes"] = .dizi(newValue.map { .nesne($0.ham) }) }
    }

    public var stockTypesTanimli: Bool { ham["stockTypes"]?.diziDegeri != nil }
}
