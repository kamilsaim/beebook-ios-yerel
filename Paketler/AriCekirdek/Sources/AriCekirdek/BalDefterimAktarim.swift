import Foundation

// Bal Defterim yedeği (`bal-defterim-yedek-*.json`) → BeeBook verisi (17 Kas 2026, Android ile birebir).
// Yedek: {sezonlar, aktifSezon, fiyatlar, urunler?, hasatlar, siparisler, zekatlar}
// Kimlikler önekli ("bd-h-", "bd-s-", "bd-z-", "bd-sez-") → aynı yedek ikinci kez yüklenirse kopya oluşmaz, güncellenir.

/// Dosya Bal Defterim yedeği mi? (Bal Defterim'in kendi kontrolüyle aynı: sezonlar + siparisler dizisi.)
public func balDefterimYedegiMi(_ j: JSONDeger) -> Bool {
    j["sezonlar"]?.diziDegeri != nil && j["siparisler"]?.diziDegeri != nil
}

/// Bal Defterim hazır ürünleri → BeeBook hazır ürünleri.
private let hazirEsleme = ["suzme": "suzme_bal", "petek": "petek_bal", "karakovan": "karakovan_bal"]
/// BeeBook'ta adı kurala bağlı ürünler (ana arı satışı `type: queen`).
private let ozelEsleme = ["ana-ari": "ana_ari"]

/// Yedekte `urunler` yoksa Bal Defterim'in varsayılan listesi.
private let bdVarsayilanUrunler: [(id: String, ad: String, ikon: String, birim: String)] = [
    ("suzme", "Süzme Bal", "🍯", "kg"), ("petek", "Petek Bal", "🧇", "kg"),
    ("karakovan", "Karakovan", "🪵", "kg"), ("polen", "Polen", "🌼", "kg"),
]

private func adAnahtari(_ s: String) -> String {
    String(s.lowercased(with: Locale(identifier: "tr_TR")).filter { $0.isLetter || $0.isNumber })
}

public struct BalAktarim: Sendable {
    /// Bal Defterim ürün id → BeeBook ürün (`v`).
    public let urunEsleme: [String: String]
    public let yeniUrunler: [UrunTanimi]
    public let fiyatlar: [String: Double]
    public let yeniSezonlar: [Sezon]
    public let stokGirisleri: [StokKaydi]
    public let satislar: [Satis]
    public let hasatSayisi: Int
    public let siparisSayisi: Int
    public let zekatSayisi: Int

    public var ozet: String {
        var p = ["\(siparisSayisi) sipariş", "\(hasatSayisi) hasat", "\(zekatSayisi) zekat"]
        if !yeniUrunler.isEmpty { p.append("\(yeniUrunler.count) yeni ürün") }
        if !yeniSezonlar.isEmpty { p.append("\(yeniSezonlar.count) yeni sezon") }
        return p.joined(separator: " · ")
    }

    /// Ürünleri ve (boş olanlara) fiyatları ayarlara yazar.
    public func ayarlaraUygula(_ a: inout Ayarlar) {
        if !yeniUrunler.isEmpty {
            let mevcut = a.stockTypesTanimli ? a.stockTypes : hazirUrunler
            a.stockTypes = mevcut + yeniUrunler
        }
        var p = a.stockPrices
        for (u, f) in fiyatlar where (p[u] ?? 0) <= 0 && f > 0 { p[u] = f }
        if p != a.stockPrices { a.stockPrices = p }
    }

    /// Sezonları, stok girişlerini, satışları (ve satışlara bağlı stok çıkışlarını) veriye yazar.
    public func veriyeUygula(_ v: inout BBVeri, urunBirimi: (String) -> Birim?) {
        let mevcutSezonlar = Set(v.sezonlar.map(\.id))
        v.sezonlar = v.sezonlar + yeniSezonlar.filter { !mevcutSezonlar.contains($0.id) }
        v.stokKayitlari = Self.ekleVeyaDegistir(v.stokKayitlari, stokGirisleri)
        v.satislar = Self.ekleVeyaDegistir(v.satislar, satislar)
        for s in satislar {
            let cikisId = "bd-o-" + String(s.id.dropFirst(s.id.hasPrefix("bd-") ? 3 : 0))
            satisStokunuYaz(&v, satis: s, onceki: nil, urunBirimi: satisStokUrunu(s).flatMap(urunBirimi), kimlik: { cikisId })
        }
    }

    private static func ekleVeyaDegistir<T: HamKayitli>(_ mevcut: [T], _ yeni: [T]) -> [T] {
        var yeniIdler: [String: T] = [:]
        for y in yeni { yeniIdler[y.id] = y }
        var sonuc = mevcut.map { yeniIdler[$0.id] ?? $0 }
        let mevcutIdler = Set(mevcut.map(\.id))
        sonuc += yeni.filter { !mevcutIdler.contains($0.id) }
        return sonuc
    }
}

/// Yedeği BeeBook kayıtlarına çevirir; veriye dokunmaz (önce özet gösterilip onay alınır).
public func balDefterimAktarimi(_ j: JSONDeger, veri v: BBVeri, ayarlar a: Ayarlar) -> BalAktarim {
    let mevcutUrunler = a.stockTypesTanimli ? a.stockTypes : hazirUrunler

    // --- Ürünler
    struct BdUrun { let id, ad, ikon, birim: String; let zekat, pasif: Bool? }
    let listeVar = !(j["urunler"]?.diziDegeri ?? []).isEmpty
    var bdUrunler: [BdUrun] = (j["urunler"]?.diziDegeri ?? []).compactMap { e in
        guard let id = e["id"]?.metinDegeri else { return nil }
        return BdUrun(id: id, ad: e["ad"]?.metinDegeri ?? id, ikon: e["ikon"]?.metinDegeri ?? "", birim: e["birim"]?.metinDegeri ?? "kg",
                      zekat: e["zekat"]?.boolDegeri, pasif: e["pasif"]?.boolDegeri)
    }
    if bdUrunler.isEmpty {
        bdUrunler = bdVarsayilanUrunler.map { BdUrun(id: $0.id, ad: $0.ad, ikon: $0.ikon, birim: $0.birim, zekat: true, pasif: nil) }
    }

    var esleme: [String: String] = [:]
    var birimler: [String: String] = [:]
    var yeniUrunler: [UrunTanimi] = []
    var kullanilanIdler = mevcutUrunler.map(\.v)

    func urunuBul(_ u: BdUrun) -> String {
        if let h = hazirEsleme[u.id], mevcutUrunler.contains(where: { $0.v == h }) { return h }
        let anahtar = adAnahtari(u.ad)
        if let m = mevcutUrunler.first(where: { adAnahtari($0.l) == anahtar || $0.v == u.id }) { return m.v }
        if let m = yeniUrunler.first(where: { adAnahtari($0.l) == anahtar }) { return m.v }
        var v2 = urunKimligi(ad: u.ad, mevcut: kullanilanIdler)
        if let ozel = hazirEsleme[u.id] ?? ozelEsleme[u.id], !kullanilanIdler.contains(ozel) { v2 = ozel }
        kullanilanIdler.append(v2)
        var t = UrunTanimi(["v": .metin(v2), "l": .metin([u.ikon, u.ad].filter { !$0.isEmpty }.joined(separator: " ")), "unit": .metin(u.birim)])
        if u.zekat == false { t.zakat = false }
        if u.pasif == true { t.pasif = true }
        yeniUrunler.append(t)
        return v2
    }
    for u in bdUrunler { esleme[u.id] = urunuBul(u); birimler[u.id] = u.birim }
    // Bal Defterim'in ürün listesinde tanımlı olanlar (kaydı olmasa da) taşınır.
    let tanimli: Set<String> = listeVar ? Set(esleme.values) : []
    func urunId(_ bd: String) -> String {
        if let e = esleme[bd] { return e }
        // Listede olmayan ürün (silinmiş) → adı id olan yeni ürün
        let e = urunuBul(BdUrun(id: bd, ad: bd, ikon: "", birim: "kg", zekat: nil, pasif: nil))
        esleme[bd] = e; birimler[bd] = "kg"
        return e
    }

    // --- Fiyatlar
    var fiyatlar: [String: Double] = [:]
    for (k, d) in j["fiyatlar"]?.nesneDegeri ?? [:] { if let f = d.sayi { fiyatlar[urunId(k)] = f } }

    // --- Sezonlar: yıl BeeBook'ta yoksa eklenir (kayıtlar tarihlerine göre BeeBook sezonlarına düşer).
    let tumKayitlar = ["hasatlar", "siparisler", "zekatlar"].flatMap { j[$0]?.diziDegeri ?? [] }
    var yeniSezonlar: [Sezon] = []
    var yillar = Set(v.sezonlar.compactMap { $0.year ?? Int(sezonBaslangici($0).prefix(4)) })
    for s in j["sezonlar"]?.diziDegeri ?? [] {
        guard let id = s["id"]?.metinDegeri else { continue }
        let ad = s["ad"]?.metinDegeri ?? ""
        let adYili = ad.range(of: "(19|20)[0-9]{2}", options: .regularExpression).flatMap { Int(ad[$0]) }
        let kayitYili = tumKayitlar.filter { $0["sezon_id"]?.metinDegeri == id }.compactMap { $0["tarih"]?.metinDegeri.flatMap { Int($0.prefix(4)) } }.min()
        let olusturmaYili = s["created_at"]?.metinDegeri.flatMap { Int($0.prefix(4)) }
        guard let yil = adYili ?? kayitYili ?? olusturmaYili, !yillar.contains(yil) else { continue }
        yillar.insert(yil)
        var z = Sezon(["id": .metin("bd-sez-\(id)")])
        z.year = yil; z.name = ad.isEmpty ? "\(yil) Sezonu" : ad; z.start = "\(yil)-01-01"
        yeniSezonlar.append(z)
    }

    // --- Hasatlar → stok girişi
    var stok: [StokKaydi] = []
    for h in j["hasatlar"]?.diziDegeri ?? [] {
        guard let id = h["id"]?.metinDegeri, let bd = h["urun"]?.metinDegeri else { continue }
        var k = StokKaydi(["id": .metin("bd-h-\(id)")])
        k.product = urunId(bd); k.action = "in"; k.amount = h["miktar"]?.sayi ?? 0; k.unit = birimler[bd] ?? "kg"
        k.date = h["tarih"]?.metinDegeri.map { String($0.prefix(10)) }
        let ac = h["aciklama"]?.metinDegeri.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        // "devri" notu: zekat hesabına girmez (devreden stok).
        k.note = (h["tip"]?.metinDegeri == "devir" ? "Bal Defterim devri" : "Bal Defterim hasadı") + (ac.map { ": \($0)" } ?? "")
        stok.append(k)
    }

    // --- Siparişler ve zekatlar → satış
    var satislar: [Satis] = []
    func yeniSatis(_ id: String, _ bd: String, _ r: JSONDeger) -> Satis {
        var s = Satis(["id": .metin(id)])
        let u = urunId(bd)
        s.product = u
        switch u {
        case "suzme_bal", "petek_bal", "karakovan_bal": s.type = "honey"; s.honeyType = u
        case "ari_sutu": s.type = "milk"
        case "ana_ari": s.type = "queen"
        default: s.type = "other"
        }
        s.qty = r["miktar"]?.sayi ?? 0
        s.unit = birimler[bd] ?? "kg"
        s.date = r["tarih"]?.metinDegeri.map { String($0.prefix(10)) }
        if let n = r["aciklama"]?.metinDegeri, !n.trimmingCharacters(in: .whitespaces).isEmpty { s.note = n }
        s.orderStatus = "delivered"
        return s
    }
    let siparisler = j["siparisler"]?.diziDegeri ?? []
    for r in siparisler {
        guard let id = r["id"]?.metinDegeri, let bd = r["urun"]?.metinDegeri else { continue }
        var s = yeniSatis("bd-s-\(id)", bd, r)
        s.customer = r["musteri"]?.metinDegeri ?? ""
        if let t = r["tel"]?.metinDegeri, !t.trimmingCharacters(in: .whitespaces).isEmpty { s.phone = t }
        let fiyat = r["fiyat"]?.sayi ?? 0
        let toplam = r["tutar"]?.sayi ?? ((s.qty ?? 0) * fiyat)
        let odenen = r["odenen"]?.sayi
        if r["hediye"]?.boolDegeri == true {
            s.payment = "hediye"; s.price = 0; s.total = 0
        } else {
            s.price = fiyat; s.total = toplam
            if r["odendi"]?.boolDegeri == true || (odenen.map { $0 >= toplam && toplam > 0 } ?? false) {
                s.payment = "paid"
            } else if let o = odenen, o > 0 {
                s.payment = "partial"; s.paidAmount = o
            } else {
                s.payment = "pending"
            }
        }
        if r["teslim"]?.boolDegeri == false { s.orderStatus = "preorder" }
        satislar.append(s)
    }
    let zekatlar = j["zekatlar"]?.diziDegeri ?? []
    for r in zekatlar {
        guard let id = r["id"]?.metinDegeri, let bd = r["urun"]?.metinDegeri else { continue }
        var s = yeniSatis("bd-z-\(id)", bd, r)
        s.customer = "Zekat"; s.payment = "zekat"; s.price = 0; s.total = 0
        satislar.append(s)
    }

    // Listede tanımlı olmayan ve kaydı da olmayan ürün eklenmez (ör. yedekte yalnız fiyatı duran "polen"); fiyatı da yazılmaz.
    let kullanilan = Set(stok.compactMap(\.product) + satislar.compactMap(\.product)).union(tanimli)
    let tutulanYeni = yeniUrunler.filter { kullanilan.contains($0.v) }
    let gecerli = Set(mevcutUrunler.map(\.v) + tutulanYeni.map(\.v))
    return BalAktarim(urunEsleme: esleme.filter { gecerli.contains($0.value) }, yeniUrunler: tutulanYeni,
                      fiyatlar: fiyatlar.filter { gecerli.contains($0.key) }, yeniSezonlar: yeniSezonlar,
                      stokGirisleri: stok, satislar: satislar, hasatSayisi: stok.count, siparisSayisi: siparisler.count, zekatSayisi: zekatlar.count)
}
