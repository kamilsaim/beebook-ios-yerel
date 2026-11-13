import Foundation

// Web aricilik.html BB-MERGE bloğunun (bbPruneTombstones, bbBuildSnapshot, bbDiffAndStamp,
// bbMergeData, bbMergeSettings) birebir karşılığı. Kurallar değişirse iki taraf birlikte değişir.

public let mezarOmruMs: Int64 = 90 * 24 * 60 * 60 * 1000

/// Koleksiyon → (id → kararlı metin).
public typealias Anlik = [String: [String: String]]

public func mezarlariBuda(_ liste: [Kayit], simdi: Int64) -> [Kayit] {
    liste.filter { simdi - mezarTs($0) < mezarOmruMs }
}

func mezarTs(_ k: Kayit) -> Int64 {
    switch k["ts"] {
    case .tam(let i)?: return i
    case .ondalik(let d)?: return Int64(d)
    default: return 0
    }
}

public func anlikOlustur(_ v: BBVeri) -> Anlik {
    var a: Anlik = [:]
    for c in BBVeri.esitlenenler {
        var m: [String: String] = [:]
        for k in v.koleksiyon(c) { if let id = k.id { m[id] = kararliMetin(.nesne(k)) } }
        a[c] = m
    }
    return a
}

/// `v`'yi yerinde damgalar: yeni/değişen kayda `_up = simdi`, kaybolan kayda mezar. Yeni anlık görüntüyü döner.
@discardableResult
public func farkVeDamga(_ v: inout BBVeri, onceki: Anlik?, simdi: Int64) -> Anlik {
    var mezarlar = v.koleksiyon("deleted")
    for c in BBVeri.esitlenenler {
        let once = onceki?[c] ?? [:]
        var gorulen = Set<String>()
        var kayitlar = v.koleksiyon(c)
        var degisti = false
        for i in kayitlar.indices {
            guard let id = kayitlar[i].id else { continue }
            gorulen.insert(id)
            if once[id] != kararliMetin(.nesne(kayitlar[i])) {
                kayitlar[i]["_up"] = .tam(simdi)
                degisti = true
            }
        }
        if degisti { v.koleksiyonYaz(c, kayitlar) }
        for id in once.keys.sorted() where !gorulen.contains(id) {
            mezarlar.append(["id": .metin(id), "c": .metin(c), "ts": .tam(simdi)])
        }
    }
    v.koleksiyonYaz("deleted", mezarlariBuda(mezarlar, simdi: simdi))
    return anlikOlustur(v)
}

public struct BirlesimSonucu: Sendable {
    public let birlesik: BBVeri
    public let yerelKirli: Bool
    public let uzakKirli: Bool
}

private func mezarSirala(_ a: Kayit, _ b: Kayit) -> Bool { (a.id ?? "") < (b.id ?? "") }

/// Web `bbComparable`: kirli bayrağı hesabı için normalize blob.
func karsilastirilabilir(_ v: BBVeri) -> JSONDeger {
    var o: [String: JSONDeger] = [:]
    for c in BBVeri.esitlenenler { o[c] = .dizi(v.koleksiyon(c).map { .nesne($0) }) }
    o["deleted"] = .dizi(v.koleksiyon("deleted").sorted(by: mezarSirala).map { .nesne($0) })
    if let lay = v.araziLayout { o["araziLayout"] = .nesne(lay) }
    for (k, d) in v.ham where o[k] == nil && k != "_demo" && k != "araziLayout" { o[k] = d }
    return .nesne(o)
}

/// Kayıt bazlı birleştirme (web `bbMergeData`).
public func veriBirlestir(yerel: BBVeri?, uzak: BBVeri?) -> BirlesimSonucu {
    let l = yerel ?? BBVeri(), r = uzak ?? BBVeri()
    var birlesik: [String: JSONDeger] = [:]

    // Mezar birleşimi: aynı id için büyük ts
    var mezarlar: [String: Kayit] = [:]
    for t in l.koleksiyon("deleted") + r.koleksiyon("deleted") {
        guard let id = t.id else { continue }
        if let cur = mezarlar[id], mezarTs(t) <= mezarTs(cur) { continue }
        mezarlar[id] = t
    }

    for c in BBVeri.esitlenenler {
        let loc = l.koleksiyon(c), rem = r.koleksiyon(c)
        var remMap: [String: Kayit] = [:]
        for x in rem { if let id = x.id { remMap[id] = x } }
        let locIds = Set(loc.compactMap(\.id))
        var cikti: [JSONDeger] = []
        func tut(_ k: Kayit) -> Bool {
            guard let id = k.id, let t = mezarlar[id] else { return true }
            if mezarTs(t) > k.up { return false } // silme daha yeni
            mezarlar.removeValue(forKey: id)        // kayıt daha yeni → diriltme
            return true
        }
        for lr in loc {
            var kazanan = lr
            if let id = lr.id, let rr = remMap[id] { kazanan = rr.up >= lr.up ? rr : lr }
            if tut(kazanan) { cikti.append(.nesne(kazanan)) }
        }
        for rr in rem where !(rr.id.map(locIds.contains) ?? false) {
            if tut(rr) { cikti.append(.nesne(rr)) }
        }
        birlesik[c] = .dizi(cikti)
    }

    birlesik["deleted"] = .dizi(mezarlar.values.sorted(by: mezarSirala).map { .nesne($0) })

    // araziLayout: blob LWW, eşitlikte uzak
    let lLay = l.araziLayout, rLay = r.araziLayout
    if let a = lLay, let b = rLay { birlesik["araziLayout"] = .nesne(b.up >= a.up ? b : a) }
    else if let x = rLay ?? lLay { birlesik["araziLayout"] = .nesne(x) }

    // Koleksiyon dışı alanlar: uzakta varsa uzak, yoksa yerel
    for k in Set(l.ham.keys).union(r.ham.keys)
    where birlesik[k] == nil && k != "_demo" && k != "deleted" && k != "araziLayout" {
        birlesik[k] = r.ham[k] ?? l.ham[k]
    }

    let sonuc = BBVeri(ham: birlesik)
    let m = kararliMetin(karsilastirilabilir(sonuc))
    return BirlesimSonucu(
        birlesik: sonuc,
        yerelKirli: m != kararliMetin(karsilastirilabilir(l)),
        uzakKirli: m != kararliMetin(karsilastirilabilir(r))
    )
}

/// Ayarlar: blob LWW (`_up`); eşitse alan bazında birleştir (uzak ezer, yerelin fazlası kalır).
public func ayarBirlestir(yerel: Ayarlar?, uzak: Ayarlar?) -> Ayarlar {
    let l = yerel ?? Ayarlar(), r = uzak ?? Ayarlar()
    let lu = l.ham.up, ru = r.ham.up
    if ru > lu { return r }
    if lu > ru { return l }
    return Ayarlar(ham: l.ham.merging(r.ham) { _, u in u })
}
