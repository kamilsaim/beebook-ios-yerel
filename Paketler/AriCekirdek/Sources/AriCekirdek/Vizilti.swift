import Foundation

// Vızıltı sesli kayıt ayrıştırıcısı — Android `cekirdek/Vizilti.kt` ile birebir (aynı kurallar, aynı test cümleleri).
// Konuşma tanımanın verdiği metinden kovan numarasını ve muayene/bal sağımı alanlarını çıkarır.
// Kural: anlaşılmayan alan nil kalır, tahmin yazılmaz. "Ana görülmedi" ≠ "ana yok".

public enum ViziltiNiyet: Sendable, Equatable { case muayene, balSagimi, bilinmiyor }

public struct ViziltiSonuc: Sendable, Equatable {
    public var metin: String
    public var niyet: ViziltiNiyet
    /// Söylenen kovan numarası (ör. "3"); kovanlarla `viziltiKovanBul` eşler.
    public var kovanNo: String?
    public var anaGoruldu: Bool?
    /// "ana yok" dendi (anaGoruldu=false ile birlikte; kovan durumu kendiliğinden değişmez).
    public var anaYok = false
    public var yumurta: Bool?
    public var acikYavru: Bool?
    public var kapaliYavru: Bool?
    /// duzenli | seyrek | yok
    public var yavru: String?
    /// 1–5 (5 çok güçlü, 4 güçlü, 3 orta, 2 zayıf, 1 çok zayıf)
    public var guc: Int?
    public var besleme: String?
    /// Kovandaki çerçeve sayısı
    public var cerceve: Int?
    /// "3 gün sonra bakacağım" → 3
    public var gunSonra: Int?
    public var varroaSayi: Int?
    /// takildi | cikarildi | uygulandi
    public var varroaIslem: String?
    public var varroaIlac: String?
    public var balCerceve: Int?
    public var balKg: Double?
    /// Hiçbir kurala uymayan kısım
    public var not: String?

    public init(metin: String, niyet: ViziltiNiyet) { self.metin = metin; self.niyet = niyet }
}

private let birler: [String: Int] = ["sıfır": 0, "bir": 1, "iki": 2, "üç": 3, "dört": 4, "beş": 5, "altı": 6, "yedi": 7, "sekiz": 8, "dokuz": 9]
private let onlar: [String: Int] = ["on": 10, "yirmi": 20, "otuz": 30, "kırk": 40, "elli": 50, "altmış": 60, "yetmiş": 70, "seksen": 80, "doksan": 90]

/// Türkçe küçük harf (I → ı, İ → i); yerel ayara bağlı kalmasın diye elle.
func trKucuk(_ s: String) -> String {
    s.replacingOccurrences(of: "I", with: "ı").replacingOccurrences(of: "İ", with: "i").lowercased()
}

private func trIlkBuyuk(_ s: String) -> String {
    guard let ilk = s.first else { return s }
    let b: String = ilk == "i" ? "İ" : ilk == "ı" ? "I" : String(ilk).uppercased()
    return b + s.dropFirst()
}

private struct Parca { var yazi: String; var sayi: Double?; var cumleSonu = false }

private func tumEslesmeler(_ re: NSRegularExpression, _ s: String) -> [NSTextCheckingResult] {
    re.matches(in: s, range: NSRange(location: 0, length: (s as NSString).length))
}

private let belirtecDeseni = try! NSRegularExpression(pattern: #"\d+(?:[.,]\d+)?|[a-zçğıöşüâîû]+|[.!?;]"#)

private func sayiYazisi(_ d: Double) -> String {
    d == d.rounded(.down) ? String(Int64(d)) : "\(d)".replacingOccurrences(of: ".", with: ",")
}

/// Metni küçük harfli belirteçlere böler; yazıyla söylenen sayıları rakama çevirir ("on iki" → 12, "bir buçuk" → 1.5).
private func belirtecler(_ metin: String) -> [Parca] {
    let kucuk = trKucuk(metin)
    let ns = kucuk as NSString
    let ham = tumEslesmeler(belirtecDeseni, kucuk).map { ns.substring(with: $0.range) }
    var cikti: [Parca] = []
    var i = 0
    while i < ham.count {
        let t = ham[i]
        if [".", "!", "?", ";"].contains(t) {
            if !cikti.isEmpty { cikti[cikti.count - 1].cumleSonu = true }
            i += 1; continue
        }
        var deger: Double? = Double(t.replacingOccurrences(of: ",", with: "."))
        if t.first?.isNumber != true { deger = nil }
        var j = i + 1
        if deger == nil {
            var toplam = 0, k = i, bulundu = false
            if k < ham.count && ham[k] == "yüz" { toplam += 100; k += 1; bulundu = true }
            else if k + 1 < ham.count, let b = birler[ham[k]], ham[k + 1] == "yüz" { toplam += 100 * b; k += 2; bulundu = true }
            if k < ham.count, let o = onlar[ham[k]] { toplam += o; k += 1; bulundu = true }
            if k < ham.count, let b = birler[ham[k]] { toplam += b; k += 1; bulundu = true }
            if bulundu { deger = Double(toplam); j = k }
            else if t == "yarım" { deger = 0.5; j = i + 1 }
        }
        if var d = deger {
            if j < ham.count && ham[j] == "buçuk" { d += 0.5; j += 1 }
            cikti.append(Parca(yazi: sayiYazisi(d), sayi: d))
            i = j
        } else { cikti.append(Parca(yazi: t, sayi: nil)); i += 1 }
    }
    return cikti
}

private final class Toplayici {
    var kovanNo: String?; var anaGoruldu: Bool?; var anaYok = false; var yumurta: Bool?
    var acikYavru: Bool?; var kapaliYavru: Bool?
    var yavru: String?; var guc: Int?; var besleme: String?; var cerceve: Int?
    var gunSonra: Int?; var balCerceve: Int?; var balKg: Double?
    var varroaSayi: Int?; var varroaIslem: String?; var varroaIlac: String?
}

/// Eşleşmenin grupları ("" = eşleşmedi).
private struct Gruplar {
    let g: [String]
    subscript(_ i: Int) -> String { i < g.count ? g[i] : "" }
    func sayi(_ i: Int) -> Double? { Double(self[i].replacingOccurrences(of: ",", with: ".")) }
}

private struct Kural {
    let re: NSRegularExpression
    let uygula: (Gruplar, Toplayici) -> Void
    init(_ desen: String, _ uygula: @escaping (Gruplar, Toplayici) -> Void) {
        let s = #"(\d+(?:,\d+)?)"#
        let d = desen.replacingOccurrences(of: "{S}", with: s).replacingOccurrences(of: #"\w"#, with: #"[\p{L}\p{N}_]"#)
        re = try! NSRegularExpression(pattern: d)
        self.uygula = uygula
    }
}

private let varroaIlaclari: [(String, String)] = [
    ("amitraz", "Amitraz"), ("apivar", "Amitraz"), ("flumetrin", "Flumetrin"), ("bayvarol", "Flumetrin"),
    ("oksalik", "Oksalik asit"), ("okzalik", "Oksalik asit"), ("formik", "Formik asit"), ("timol", "Timol"), ("thymol", "Timol"),
    ("apiguard", "Timol"), ("thymovar", "Timol"), ("apistan", "Fluvalinat"), ("fluvalinat", "Fluvalinat"),
]
private func ilacAdi(_ s: String) -> String? { varroaIlaclari.first { s.hasPrefix($0.0) }?.1 }

// Sıra önemli: önce özel (bal sağımı, "ana görülmedi"), sonra genel kurallar. Eşleşen bölüm tüketilir.
private let kurallar: [Kural] = [
    // --- Bal sağımı
    Kural(#"{S} çerçeve\w* bal\w*(?: (?:aldım|sağdım|süzdüm|çektim|çıkardım|hasat\w*|aldık|sağdık))?"#) { m, t in t.balCerceve = m.sayi(1).map { Int($0) } },
    Kural(#"{S} (?:kilo\w*|kg|kilogram\w*) bal\w*(?: (?:aldım|sağdım|süzdüm|çektim|çıkardım|hasat\w*|aldık|sağdık))?"#) { m, t in t.balKg = m.sayi(1) },
    Kural(#"bal (?:aldım|sağdım|süzdüm|çektim|hasadı|sağımı)(?: {S} (?:çerçeve\w*|(kilo\w*|kg)))?"#) { m, t in
        if let n = m.sayi(1) { if !m[2].isEmpty { t.balKg = n } else { t.balCerceve = Int(n) } }
    },
    // --- Varroa (besleme ve sayılardan önce)
    Kural(#"(?:varroa\w* |akar\w* )?şeri[td]\w* (?:çıkardım|çıkarıldı|çıkarttım|aldım|söktüm|toplandı|topladım)"#) { _, t in t.varroaIslem = "cikarildi" },
    Kural(#"((?:amitraz|apivar|flumetrin|bayvarol|oksalik|okzalik|formik|timol|thymol|apiguard|thymovar|apistan|fluvalinat)\w*)(?: asit\w*)?(?: (şeri[td]\w*))?(?: (verdim|uyguladım|yaptım|taktım|koydum|astım|damlattım|buharlaştırdım|süzdüm|attım))?"#) { m, t in
        t.varroaIlac = ilacAdi(m[1])
        if t.varroaIslem == nil { t.varroaIslem = (!m[2].isEmpty || ["taktım", "astım", "koydum"].contains(m[3])) ? "takildi" : "uygulandi" }
    },
    Kural(#"(?:varroa\w* |akar\w* )?(?:ilaç\w* )?şeri[td]\w* (?:taktım|takıldı|koydum|astım|yerleştirdim|attım)"#) { _, t in if t.varroaIslem == nil { t.varroaIslem = "takildi" } },
    Kural(#"(?:varroa|akar)\w* (?:ilacı |ilaç )?(?:verdim|uyguladım|yaptım|mücadele\w*)"#) { _, t in if t.varroaIslem == nil { t.varroaIslem = "uygulandi" } },
    Kural(#"(?:varroa|akar)\w* (?:yok|görmedim|görülmedi|düşmedi)"#) { _, t in t.varroaSayi = 0 },
    Kural(#"{S} (?:tane )?(?:akar|varroa)\w*(?: (?:düştü|düşmüş|saydım|gördüm|var|çıktı))?"#) { m, t in t.varroaSayi = m.sayi(1).map { Int($0) } },
    Kural(#"(?:varroa|akar)\w* (?:sayısı |sayımı )?{S}(?: (?:tane|adet))?(?! (?:gün|hafta))"#) { m, t in if t.varroaSayi == nil { t.varroaSayi = m.sayi(1).map { Int($0) } } },
    // --- Kovan numarası
    Kural(#"{S} (?:numaral\w*|numara\w*|nolu\w*|no lu\w*|no)(?: kovan\w*)?"#) { m, t in if t.kovanNo == nil { t.kovanNo = m[1] } },
    Kural(#"kovan\w* (?:numarası |no |numara )?{S}"#) { m, t in if t.kovanNo == nil { t.kovanNo = m[1] } },
    Kural(#"{S} kovan\w*"#) { m, t in if t.kovanNo == nil { t.kovanNo = m[1] } },
    // --- Ana arı
    Kural(#"(?:ana|kraliçe)\w*(?: arı\w*)? (?:yok|yoktu)"#) { _, t in t.anaGoruldu = false; t.anaYok = true },
    Kural(#"(?:ana|kraliçe)\w*(?: arı\w*)? (?:görülmedi|göremedim|görmedim|görünmüyor|bulunamadı|bulamadım|bulmadım)"#) { _, t in t.anaGoruldu = false },
    Kural(#"(?:ana|kraliçe)\w*(?: arı\w*)? (?:görüldü|gördüm|var|vardı|mevcut|bulundu|buldum|yerinde|sağlam)"#) { _, t in t.anaGoruldu = true },
    // --- Yumurta
    Kural(#"(?:taze )?(?:yumurta|larva)\w*(?: ve larva\w*)? (?:yok|yoktu|görmedim|görülmedi|göremedim)"#) { _, t in t.yumurta = false },
    Kural(#"(?:taze )?(?:yumurta|larva)\w*(?: ve larva\w*)? (?:var|vardı|gördüm|görüldü|mevcut)"#) { _, t in t.yumurta = true },
    // --- Açık / kapalı yavru
    Kural(#"(açık|kapalı)(?: ve (açık|kapalı))? yavru\w* (yok|yoktu|görmedim|görülmedi|göremedim|var|vardı|gördüm|görüldü|mevcut)"#) { m, t in
        let v = ["var", "vardı", "gördüm", "görüldü", "mevcut"].contains(m[3])
        for g in [m[1], m[2]] { if g == "açık" { t.acikYavru = v }; if g == "kapalı" { t.kapaliYavru = v } }
    },
    // --- Yavru
    Kural(#"(?:kapalı |açık )?yavru\w* (?:yok|yoktu|görmedim|görülmedi)"#) { _, t in t.yavru = "yok" },
    Kural(#"(?:kapalı |açık )?yavru\w* (?:\w+ )?(?:seyrek|dağınık|az|kötü|boşluklu)|(?:seyrek|dağınık) yavru\w*"#) { _, t in t.yavru = "seyrek" },
    Kural(#"(?:kapalı |açık )?yavru\w* (?:\w+ )?(?:düzenli|güzel|iyi|dolu|sıkı|kompakt)|düzenli yavru\w*"#) { _, t in t.yavru = "duzenli" },
    Kural(#"seyrek"#) { _, t in if t.yavru == nil { t.yavru = "seyrek" } },
    // --- Besleme
    Kural(#"{S} (litre|lt|kilo|kg|gram|gr|paket|tane) (şurup\w*|şurub\w*|şerbet\w*|kek\w*|polen\w*|şeker\w*|fondan\w*|pogaça\w*|besin\w*)(?: (?:verdim|verildi|koydum|konuldu|yaptım|takviye\w*))?"#) { m, t in
        if t.besleme == nil { t.besleme = "\(m[1]) \(m[2]) \(m[3])" }
    },
    Kural(#"(şurup|şurub\w*|şerbet|kek|polen|şeker|fondan|pogaça)\w* (?:verdim|verildi|koydum|konuldu|yaptım)"#) { m, t in
        if t.besleme == nil { t.besleme = m[1].hasPrefix("şurub") ? "şurup" : m[1] }
    },
    Kural(#"(?:besledim|besleme yaptım|besleme yapıldı)"#) { _, t in if t.besleme == nil { t.besleme = "besleme" } },
    // --- Çerçeve sayısı (kovan)
    Kural(#"{S} çerçeve\w*(?: (?:var|oldu|dolu|arı\w*))?"#) { m, t in if t.cerceve == nil { t.cerceve = m.sayi(1).map { Int($0) } } },
    Kural(#"çerçeve\w* (?:sayısı )?{S}(?! (?:gün|hafta))"#) { m, t in if t.cerceve == nil { t.cerceve = m.sayi(1).map { Int($0) } } },
    // --- Güç (önce "çok")
    Kural(#"çok güçlü\w*"#) { _, t in t.guc = 5 },
    Kural(#"çok zayıf\w*"#) { _, t in t.guc = 1 },
    Kural(#"(?:durumu |koloni |gücü )?güçlü\w*"#) { _, t in if t.guc == nil { t.guc = 4 } },
    Kural(#"(?:durumu |koloni |gücü )?(?:zayıf\w*|güçsüz\w*)"#) { _, t in if t.guc == nil { t.guc = 2 } },
    Kural(#"(?:durumu |koloni |gücü )?orta\w*"#) { _, t in if t.guc == nil { t.guc = 3 } },
    // --- Hatırlatma
    Kural(#"{S} (gün|hafta)\w* sonra(?: (?:bak\w*|kontrol\w*|gel\w*|tekrar\w*|yine\w*))*"#) { m, t in
        if let n = m.sayi(1).map({ Int($0) }), t.gunSonra == nil { t.gunSonra = m[2] == "hafta" ? n * 7 : n }
    },
    Kural(#"haftaya(?: (?:bak\w*|kontrol\w*|gel\w*|tekrar\w*))*"#) { _, t in if t.gunSonra == nil { t.gunSonra = 7 } },
    Kural(#"yarın(?: (?:bak\w*|kontrol\w*|gel\w*|tekrar\w*))*"#) { _, t in if t.gunSonra == nil { t.gunSonra = 1 } },
]

/// Not'a girmeyecek dolgu sözcükleri (yalnız kalan parçanın baş/sonundan atılır).
private let dolgu: Set<String> = [
    "ve", "de", "da", "ile", "bugün", "tamam", "kaydet", "evet", "şimdi", "bakım", "bakımı", "bakımını", "muayene", "muayenesi", "kontrol", "kontrolü",
    "kovan", "kovanı", "kovanın", "kovanda", "kovandan", "kovana", "durumu", "durum", "arı", "vızıltı", "merhaba", "hey", "sonra", "yaptım", "verdim",
    "aldım", "bakacağım", "varroa", "akar", "ilacı", "mücadelesi", "bakarım", "bakalım", "gelip", "ee", "eee", "ıı", "hmm", "şey", "yani", "bir", "numaralı", "nolu", "çerçeve",
]

/// Konuşma metnini ayrıştırır.
public func viziltiAyristir(_ metin: String) -> ViziltiSonuc {
    let p = belirtecler(metin)
    if p.isEmpty { return ViziltiSonuc(metin: metin, niyet: .bilinmiyor) }
    // Belirteçleri boşlukla birleştir; her belirtecin UTF-16 aralığını tut
    var birlesik = ""; var bas = [Int](repeating: 0, count: p.count); var son = bas
    for (i, x) in p.enumerated() {
        if i > 0 { birlesik += " " }
        bas[i] = birlesik.utf16.count; birlesik += x.yazi; son[i] = birlesik.utf16.count
    }
    var birimler = Array(birlesik.utf16)
    var tuketildi = [Bool](repeating: false, count: p.count)
    let t = Toplayici()
    for k in kurallar {
        let duz = String(decoding: birimler, as: UTF16.self)
        let ns = duz as NSString
        for m in tumEslesmeler(k.re, duz) {
            // Sözcük sınırı: eşleşme bir belirtecin ortasında başlamasın/bitmesin
            guard let i0 = bas.firstIndex(of: m.range.location), let i1 = son.firstIndex(of: m.range.location + m.range.length), i0 <= i1 else { continue }
            if (i0...i1).contains(where: { tuketildi[$0] }) { continue }
            let gruplar = Gruplar(g: (0..<m.numberOfRanges).map { r in
                let a = m.range(at: r); return a.location == NSNotFound ? "" : ns.substring(with: a)
            })
            k.uygula(gruplar, t)
            for x in i0...i1 { tuketildi[x] = true }
        }
        // Tüketilenleri sonraki kurallar görmesin: yerlerine eşit uzunlukta imleç koy
        for i in p.indices where tuketildi[i] { for c in bas[i]..<son[i] { birimler[c] = 0x0001 } }
    }
    // Not: tüketilmeyen ardışık belirteç öbekleri (cümle sonunda öbek kesilir), baş/sondaki dolgular atılır
    var obekler: [[String]] = []; var cari: [String] = []
    for (i, x) in p.enumerated() {
        if tuketildi[i] { if !cari.isEmpty { obekler.append(cari); cari = [] } }
        else { cari.append(x.yazi); if x.cumleSonu { obekler.append(cari); cari = [] } }
    }
    if !cari.isEmpty { obekler.append(cari) }
    let notlar: [String] = obekler.compactMap { o in
        var a = 0, b = o.count
        while a < b && dolgu.contains(o[a]) { a += 1 }
        while b > a && dolgu.contains(o[b - 1]) { b -= 1 }
        return a >= b ? nil : o[a..<b].joined(separator: " ")
    }
    let birNot = notlar.joined(separator: ", ")

    let muayeneAlani = t.varroaSayi != nil || t.varroaIslem != nil || t.anaGoruldu != nil || t.yumurta != nil || t.acikYavru != nil
        || t.kapaliYavru != nil || t.yavru != nil || t.guc != nil || t.besleme != nil || t.cerceve != nil || t.gunSonra != nil
    let bal = t.balCerceve != nil || t.balKg != nil
    let niyet: ViziltiNiyet = bal && !muayeneAlani ? .balSagimi : (muayeneAlani || t.kovanNo != nil) ? .muayene : .bilinmiyor
    var s = ViziltiSonuc(metin: metin, niyet: niyet)
    s.kovanNo = t.kovanNo; s.anaGoruldu = t.anaGoruldu; s.anaYok = t.anaYok; s.yumurta = t.yumurta
    s.acikYavru = t.acikYavru; s.kapaliYavru = t.kapaliYavru
    s.yavru = t.yavru; s.guc = t.guc; s.besleme = t.besleme; s.cerceve = t.cerceve; s.gunSonra = t.gunSonra
    s.balCerceve = t.balCerceve; s.balKg = t.balKg
    s.varroaSayi = t.varroaSayi; s.varroaIslem = t.varroaIslem; s.varroaIlac = t.varroaIlac
    s.not = birNot.isEmpty ? nil : trIlkBuyuk(birNot)
    return s
}

/// Söylenen numarayla kovanları eşler: önce birebir `num`, yoksa sayısal eşitlik ("03" = "3").
public func viziltiKovanBul(_ no: String?, _ kovanlar: [Kovan]) -> [Kovan] {
    guard let no, !no.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
    let n = no.trimmingCharacters(in: .whitespaces)
    let birebir = kovanlar.filter { $0.num.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(n) == .orderedSame }
    if !birebir.isEmpty { return birebir }
    guard let s = Int(n) else { return [] }
    return kovanlar.filter { Int($0.num.trimmingCharacters(in: .whitespaces)) == s }
}

/// Otomatik kat: ≤10 çerçeve → 1 kat, 11–20 → 2, 21+ → 3.
public func otomatikKat(_ cerceve: Int) -> Int { cerceve <= 10 ? 1 : cerceve <= 20 ? 2 : 3 }

/// Bal sağımı tahmini kg = alınan çerçeve × çerçeve başı kg (varsayılan 3).
public func balKgTahmini(_ cerceve: Int, _ cerceveBasiKg: Double = 3) -> Double { Double(cerceve) * cerceveBasiKg }
