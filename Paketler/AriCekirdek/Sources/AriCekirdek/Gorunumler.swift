import Foundation

// Kayıtların tipli görünümleri. Alan adları web veri modeliyle (aricilik CLAUDE.md "Veri Modeli") birebir.
// Her görünüm ham kaydı taşır; tanınmayan alanlar dokunulmadan geri yazılır.

public struct Kovan: HamKayitli, Equatable, Sendable {
    public var ham: Kayit
    public init(_ ham: Kayit) { self.ham = ham }
    public var num: String { get { metin("num") ?? "" } set { metinYaz("num", newValue) } }
    public var type: String? { get { metin("type") } set { metinYaz("type", newValue) } }
    /// yes | no | bakire | meme | unknown | empty (eski veride `new` de olabilir)
    public var queenStatus: String? { get { metin("queenStatus") } set { metinYaz("queenStatus", newValue) } }
    public var queenColor: String? { get { metin("queenColor") } set { metinYaz("queenColor", newValue) } }
    public var strength: String? { get { metin("strength") } set { metinYaz("strength", newValue) } }
    public var race: String? { get { metin("race") } set { metinYaz("race", newValue) } }
    public var generation: String? { get { metin("generation") } set { metinYaz("generation", newValue) } }
    public var year: String? { get { metin("year") } set { metinYaz("year", newValue) } }
    public var frames: Double? { get { sayi("frames") } set { sayiYaz("frames", newValue) } }
    public var floors: Double? { get { sayi("floors") } set { sayiYaz("floors", newValue) } }
    public var notes: String? { get { metin("notes") } set { metinYaz("notes", newValue) } }
    public var createdAt: String? { get { metin("createdAt") } set { metinYaz("createdAt", newValue) } }
}

public struct Satis: HamKayitli, Equatable, Sendable {
    public var ham: Kayit
    public init(_ ham: Kayit) { self.ham = ham }
    public var type: String? { get { metin("type") } set { metinYaz("type", newValue) } }
    public var customer: String? { get { metin("customer") } set { metinYaz("customer", newValue) } }
    public var phone: String? { get { metin("phone") } set { metinYaz("phone", newValue) } }
    public var date: String? { get { metin("date") } set { metinYaz("date", newValue) } }
    public var qty: Double? { get { sayi("qty") } set { sayiYaz("qty", newValue) } }
    public var unit: String? { get { metin("unit") } set { metinYaz("unit", newValue) } }
    public var price: Double? { get { sayi("price") } set { sayiYaz("price", newValue) } }
    public var total: Double? { get { sayi("total") } set { sayiYaz("total", newValue) } }
    /// paid | pending | partial | hediye | zekat
    public var payment: String? { get { metin("payment") } set { metinYaz("payment", newValue) } }
    public var paidAmount: Double? { get { sayi("paidAmount") } set { sayiYaz("paidAmount", newValue) } }
    public var note: String? { get { metin("note") } set { metinYaz("note", newValue) } }
    public var honeyType: String? { get { metin("honeyType") } set { metinYaz("honeyType", newValue) } }
    public var soldHives: [String]? { get { metinler("soldHives") } set { metinlerYaz("soldHives", newValue) } }
    /// delivered | preorder
    public var orderStatus: String? { get { metin("orderStatus") } set { metinYaz("orderStatus", newValue) } }
    public var batchId: String? { get { metin("batchId") } set { metinYaz("batchId", newValue) } }
    /// Stok ürün id'si (v2.7.0+). Varsa stok bundan düşer.
    public var product: String? { get { metin("product") } set { metinYaz("product", newValue) } }
}

public struct Gider: HamKayitli, Equatable, Sendable {
    public var ham: Kayit
    public init(_ ham: Kayit) { self.ham = ham }
    public var type: String? { get { metin("type") } set { metinYaz("type", newValue) } }
    public var amount: Double? { get { sayi("amount") } set { sayiYaz("amount", newValue) } }
    public var date: String? { get { metin("date") } set { metinYaz("date", newValue) } }
    public var desc: String? { get { metin("desc") } set { metinYaz("desc", newValue) } }
    public var payment: String? { get { metin("payment") } set { metinYaz("payment", newValue) } }
    public var paidAmount: Double? { get { sayi("paidAmount") } set { sayiYaz("paidAmount", newValue) } }
}

/// Arı sütü hasadı (`milk`).
public struct Hasat: HamKayitli, Equatable, Sendable {
    public var ham: Kayit
    public init(_ ham: Kayit) { self.ham = ham }
    public var amount: Double? { get { sayi("amount") } set { sayiYaz("amount", newValue) } }
    public var date: String? { get { metin("date") } set { metinYaz("date", newValue) } }
    public var hiveCount: Double? { get { sayi("hiveCount") } set { sayiYaz("hiveCount", newValue) } }
    public var note: String? { get { metin("note") } set { metinYaz("note", newValue) } }
}

public struct Meme: HamKayitli, Equatable, Sendable {
    public var ham: Kayit
    public init(_ ham: Kayit) { self.ham = ham }
    public var num: String? { get { metin("num") } set { metinYaz("num", newValue) } }
    /// pending | kovana_aktarildi | satildi | oldu
    public var status: String? { get { metin("status") } set { metinYaz("status", newValue) } }
    public var targetHive: String? { get { metin("targetHive") } set { metinYaz("targetHive", newValue) } }
}

/// Ana arı üretim serisi (`queens`).
public struct AnaSeri: HamKayitli, Equatable, Sendable {
    public var ham: Kayit
    public init(_ ham: Kayit) { self.ham = ham }
    public var name: String? { get { metin("name") } set { metinYaz("name", newValue) } }
    public var race: String? { get { metin("race") } set { metinYaz("race", newValue) } }
    public var generation: String? { get { metin("generation") } set { metinYaz("generation", newValue) } }
    public var motherHive: String? { get { metin("motherHive") } set { metinYaz("motherHive", newValue) } }
    public var starterHive: String? { get { metin("starterHive") } set { metinYaz("starterHive", newValue) } }
    public var transfer: String? { get { metin("transfer") } set { metinYaz("transfer", newValue) } }
    public var grafted: Double? { get { sayi("grafted") } set { sayiYaz("grafted", newValue) } }
    public var accepted: Double? { get { sayi("accepted") } set { sayiYaz("accepted", newValue) } }
    public var emerged: Double? { get { sayi("emerged") } set { sayiYaz("emerged", newValue) } }
    public var sold: Double? { get { sayi("sold") } set { sayiYaz("sold", newValue) } }
    /// active | completed | failed
    public var status: String? { get { metin("status") } set { metinYaz("status", newValue) } }
    public var notes: String? { get { metin("notes") } set { metinYaz("notes", newValue) } }
    public var memeler: [Meme] {
        get { (ham["queens"]?.diziDegeri ?? []).compactMap { $0.nesneDegeri }.map(Meme.init) }
        set { ham["queens"] = .dizi(newValue.map { .nesne($0.ham) }) }
    }
}

/// Yapılacak iş (`tasks`). `hiveIds`/`scope` v2.7.0 ile eklendi (toplu iş).
public struct Is: HamKayitli, Equatable, Sendable {
    public var ham: Kayit
    public init(_ ham: Kayit) { self.ham = ham }
    public var text: String { get { metin("text") ?? "" } set { metinYaz("text", newValue) } }
    public var done: Bool { get { bool("done") ?? false } set { boolYaz("done", newValue) } }
    public var dueDate: String? { get { metin("dueDate") } set { metinYaz("dueDate", newValue) } }
    public var hiveIds: [String]? { get { metinler("hiveIds") } set { metinlerYaz("hiveIds", newValue) } }
    public var scope: String? { get { metin("scope") } set { metinYaz("scope", newValue) } }
}

public struct Sezon: HamKayitli, Equatable, Sendable {
    public var ham: Kayit
    public init(_ ham: Kayit) { self.ham = ham }
    public var year: Int? { get { sayi("year").map { Int($0) } } set { sayiYaz("year", newValue.map(Double.init)) } }
    public var name: String? { get { metin("name") } set { metinYaz("name", newValue) } }
    public var active: Bool? { get { bool("active") } set { boolYaz("active", newValue) } }
    public var start: String? { get { metin("start") } set { metinYaz("start", newValue) } }
}

public struct StokKaydi: HamKayitli, Equatable, Sendable {
    public var ham: Kayit
    public init(_ ham: Kayit) { self.ham = ham }
    public var product: String? { get { metin("product") } set { metinYaz("product", newValue) } }
    /// in | out
    public var action: String? { get { metin("action") } set { metinYaz("action", newValue) } }
    public var amount: Double? { get { sayi("amount") } set { sayiYaz("amount", newValue) } }
    public var unit: String? { get { metin("unit") } set { metinYaz("unit", newValue) } }
    public var date: String? { get { metin("date") } set { metinYaz("date", newValue) } }
    public var note: String? { get { metin("note") } set { metinYaz("note", newValue) } }
    public var saleId: String? { get { metin("saleId") } set { metinYaz("saleId", newValue) } }
    public var milkId: String? { get { metin("milkId") } set { metinYaz("milkId", newValue) } }
}

public struct EnvanterKalemi: HamKayitli, Equatable, Sendable {
    public var ham: Kayit
    public init(_ ham: Kayit) { self.ham = ham }
    public var name: String? { get { metin("name") } set { metinYaz("name", newValue) } }
    public var qty: Double? { get { sayi("qty") } set { sayiYaz("qty", newValue) } }
    /// saglam | tamir | eksik
    public var status: String? { get { metin("status") } set { metinYaz("status", newValue) } }
    public var note: String? { get { metin("note") } set { metinYaz("note", newValue) } }
}

/// Kovan muayenesi (`inspections`, v2.7.0).
public struct Muayene: HamKayitli, Equatable, Sendable {
    public var ham: Kayit
    public init(_ ham: Kayit) { self.ham = ham }
    public var hiveId: String? { get { metin("hiveId") } set { metinYaz("hiveId", newValue) } }
    public var date: String? { get { metin("date") } set { metinYaz("date", newValue) } }
    public var queenSeen: Bool? { get { bool("queenSeen") } set { boolYaz("queenSeen", newValue) } }
    public var eggs: Bool? { get { bool("eggs") } set { boolYaz("eggs", newValue) } }
    /// duzenli | seyrek | yok
    public var brood: String? { get { metin("brood") } set { metinYaz("brood", newValue) } }
    /// guclu | orta | zayif
    public var strength: String? { get { metin("strength") } set { metinYaz("strength", newValue) } }
    public var feeding: String? { get { metin("feeding") } set { metinYaz("feeding", newValue) } }
    public var note: String? { get { metin("note") } set { metinYaz("note", newValue) } }
}

/// Stok ürün tanımı (`settings.stockTypes[]`): `{v, l, unit}` + isteğe bağlı `zakat`, `image`.
public struct UrunTanimi: HamKayitli, Equatable, Sendable {
    public var ham: Kayit
    public init(_ ham: Kayit) { self.ham = ham }
    public var v: String { get { metin("v") ?? "" } set { metinYaz("v", newValue) } }
    public var l: String { get { metin("l") ?? "" } set { metinYaz("l", newValue) } }
    public var unit: String { get { metin("unit") ?? "kg" } set { metinYaz("unit", newValue) } }
    public var zakat: Bool? { get { bool("zakat") } set { boolYaz("zakat", newValue) } }
    public var image: String? { get { metin("image") } set { metinYaz("image", newValue) } }
}
