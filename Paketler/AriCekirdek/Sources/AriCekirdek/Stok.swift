import Foundation

// Web getStockLevel / saleStockProduct / upsertSaleStock / arı sütü hasat stoğu karşılıkları (v2.7.0 kuralları).

/// Ürünün güncel stoğu: giriş − çıkış, en az 0. Metin miktarlar sayı sayılır.
public func stokSeviyesi(_ v: BBVeri, urun: String) -> Double {
    var giris = 0.0, cikis = 0.0
    for k in v.stokKayitlari where k.product == urun {
        if k.action == "in" { giris += k.amount ?? 0 } else if k.action == "out" { cikis += k.amount ?? 0 }
    }
    return max(0, giris - cikis)
}

/// Satışın düşeceği stok ürünü: önce `product`, yoksa eski kural (milk → ari_sutu, honey → honeyType).
public func satisStokUrunu(_ s: Satis) -> String? {
    if let p = s.product, !p.isEmpty { return p }
    if s.type == "milk" { return "ari_sutu" }
    if s.type == "honey" { return (s.honeyType?.isEmpty == false ? s.honeyType : nil) ?? "suzme_bal" }
    return nil
}

/// Satışa bağlı (`saleId`) stok çıkışını oluşturur/günceller/kaldırır.
/// - Parameter onceki: düzenlemede satışın eski hâli; yeni satışta nil. Eski hâl stok ürünü
///   taşıyıp hiçbir stok kaydına bağlı değilse yeni kayıt AÇILMAZ (elle düşülmüş eski stok iki kez düşmesin).
public func satisStokunuYaz(_ v: inout BBVeri, satis: Satis, onceki: Satis?, urunBirimi: Birim?, kimlik: () -> String) {
    var kayitlar = v.stokKayitlari
    let i = kayitlar.firstIndex { $0.saleId == satis.id }
    if let onceki, i == nil, satisStokUrunu(onceki) != nil { return }

    guard let urun = satisStokUrunu(satis) else {
        if let i { kayitlar.remove(at: i); v.stokKayitlari = kayitlar }
        return
    }
    var miktar = satis.qty ?? 0
    var birim = satis.unit
    if let ub = urunBirimi, let sb = satis.unit.flatMap(Birim.init(rawValue:)), let c = Birim.cevir(miktar, sb, ub) {
        miktar = c
        birim = ub.rawValue
    }
    let etiket = satis.payment == "hediye" ? "Hediye" : satis.payment == "zekat" ? "Zekat" : "Satış"
    let musteri = (satis.customer?.isEmpty == false ? satis.customer : nil) ?? "Müşteri"

    var k = StokKaydi(["id": .metin(i.map { kayitlar[$0].id } ?? kimlik())])
    k.product = urun
    k.action = "out"
    k.amount = miktar
    k.unit = birim
    k.date = satis.date
    k.note = "\(etiket): \(musteri)"
    k.saleId = satis.id
    if let i { kayitlar[i] = k } else { kayitlar.append(k) }
    v.stokKayitlari = kayitlar
}

public func bagliStokuSil(_ v: inout BBVeri, saleId: String?) {
    guard let saleId else { return }
    v.stokKayitlari = v.stokKayitlari.filter { $0.saleId != saleId }
}

/// Arı sütü hasadının stok girişi (`milkId` bağlı): oluşturur ya da günceller.
public func hasatStokunuYaz(_ v: inout BBVeri, hasat: Hasat, kimlik: () -> String) {
    var kayitlar = v.stokKayitlari
    let i = kayitlar.firstIndex { $0.milkId == hasat.id }
    var k = StokKaydi(["id": .metin(i.map { kayitlar[$0].id } ?? kimlik())])
    k.product = "ari_sutu"
    k.action = "in"
    k.amount = hasat.amount ?? 0
    k.unit = "gr"
    k.date = hasat.date
    k.note = "Hasat" + ((hasat.note?.isEmpty == false) ? ": \(hasat.note!)" : "")
    k.milkId = hasat.id
    if let i { kayitlar[i] = k } else { kayitlar.append(k) }
    v.stokKayitlari = kayitlar
}

public func hasatStokunuSil(_ v: inout BBVeri, milkId: String) {
    v.stokKayitlari = v.stokKayitlari.filter { $0.milkId != milkId }
}
