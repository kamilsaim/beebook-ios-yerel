import Foundation

/// Kovan kartlarının elle sırası (`settings.hiveOrder`: kovan id listesi) — Android `KovanSirasi` ile aynı.
/// Yıldızlılar her zaman önde; her grup kendi içinde elle sıraya göre, sırada olmayanlar
/// (yeni eklenen ya da hiç sıralanmamış) sonda kovan numarasına göre.
public enum KovanSirasi {
    static func numara(_ k: Kovan) -> Int { Int(String(k.num.filter(\.isNumber).prefix(9))) ?? Int.max }

    public static func sirala(_ kovanlar: [Kovan], _ sira: [String]?) -> [Kovan] {
        var yer: [String: Int] = [:]
        for (i, id) in (sira ?? []).enumerated() where yer[id] == nil { yer[id] = i }
        return kovanlar.enumerated().sorted { x, y in
            let a = x.element, b = y.element
            if a.starred != b.starred { return a.starred }
            let ya = yer[a.id] ?? Int.max, yb = yer[b.id] ?? Int.max
            if ya != yb { return ya < yb }
            let na = numara(a), nb = numara(b)
            if na != nb { return na < nb }
            if a.num != b.num { return a.num < b.num }
            return x.offset < y.offset
        }.map(\.element)
    }

    /// Görünen (filtrelenmiş) kovanların yeni sırasını tüm sıraya yerleştirir: görünenlerin tuttuğu yuvalar
    /// yeni sırayla doldurulur, gizli kovanlar yerinde kalır. Yıldızlılar yine öne alınır.
    public static func yerlestir(_ tum: [Kovan], _ gorunenYeni: [String]) -> [String] {
        let gorunen = Set(gorunenYeni)
        let idler = Set(tum.map(\.id))
        var kuyruk = gorunenYeni.filter { idler.contains($0) }[...]
        let sonuc = tum.map { k -> String in
            if gorunen.contains(k.id), let ilk = kuyruk.popFirst() { return ilk }
            return k.id
        }
        let yildizli = Set(tum.filter(\.starred).map(\.id))
        return sonuc.filter { yildizli.contains($0) } + sonuc.filter { !yildizli.contains($0) }
    }

    /// Listede `kimden` konumundaki öğeyi `kime` konumuna taşır.
    public static func tasi<T>(_ liste: [T], _ kimden: Int, _ kime: Int) -> [T] {
        guard kimden != kime, liste.indices.contains(kimden), liste.indices.contains(kime) else { return liste }
        var l = liste
        l.insert(l.remove(at: kimden), at: kime)
        return l
    }
}
