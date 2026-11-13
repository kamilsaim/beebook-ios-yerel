import AriCekirdek
import SwiftUI

/// Arazi düzeni: `araziLayout.positions` (web ile aynı piksel/nokta koordinatları). Uzun basıp sürükle → yer değiştir.
struct AraziGorunumu: View {
    @Environment(VeriDeposu.self) private var depo
    let ac: (String) -> Void
    @State private var surukle: (id: String, fark: CGSize)?

    private let hucre: CGFloat = 72

    var body: some View {
        let kovanlar = depo.veri.kovanlar
        let konumlar = konumlariOku()
        let yerlesmemis = kovanlar.filter { konumlar[$0.id] == nil }
        let genislik = max(340, (konumlar.values.map(\.x).max() ?? 0) + hucre + 40)
        let yukseklik = max(420, (konumlar.values.map(\.y).max() ?? 0) + hucre + 80)

        VStack(alignment: .leading, spacing: 10) {
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    Image("ArkaCicek").resizable().scaledToFill().frame(width: genislik, height: yukseklik).clipped()
                    LinearGradient(colors: [Color(red: 0.12, green: 0.31, blue: 0.16).opacity(0.25), Renk.orman.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                    ForEach(araLar(), id: \.id) { a in
                        RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.55, green: 0.42, blue: 0.25).opacity(0.75))
                            .frame(width: a.w, height: a.h).offset(x: a.x, y: a.y)
                    }
                    ForEach(kovanlar.filter { konumlar[$0.id] != nil }, id: \.id) { k in
                        let p = konumlar[k.id]!
                        let f = surukle?.id == k.id ? surukle!.fark : .zero
                        AraziKovani(kovan: k, genislik: hucre)
                            .offset(x: p.x + f.width, y: p.y + f.height)
                            .zIndex(surukle?.id == k.id ? 1 : 0)
                            .onTapGesture { ac(k.id) }
                            .gesture(
                                LongPressGesture(minimumDuration: 0.3)
                                    .sequenced(before: DragGesture())
                                    .onChanged { d in
                                        if case .second(true, let drag?) = d { surukle = (k.id, drag.translation) }
                                    }
                                    .onEnded { d in
                                        if case .second(true, let drag?) = d { tasi(k.id, p, drag.translation) }
                                        surukle = nil
                                    }
                            )
                    }
                }
                .frame(width: genislik, height: yukseklik, alignment: .topLeading)
            }
            .frame(height: 440)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 8)

            HStack(spacing: 8) {
                Rozet(metin: "Ana var", tur: .iyi); Rozet(metin: "Bakire", tur: .bilgi); Rozet(metin: "Anasız", tur: .kotu); Rozet(metin: "Ana üretim", tur: .mor)
            }
            Text("Kovana dokun: ayrıntı · Uzun basıp sürükle: yerini değiştir").font(Yazi.etiket).foregroundStyle(Color(white: 0.75))

            if !yerlesmemis.isEmpty {
                Kart {
                    KartBasligi(baslik: "Yerleştirilmemiş (\(yerlesmemis.count))", baglanti: "Hepsini yerleştir") { otomatikYerlestir(yerlesmemis) }
                    ScrollView(.horizontal) {
                        HStack { ForEach(yerlesmemis, id: \.id) { k in AraziKovani(kovan: k, genislik: 56).onTapGesture { ac(k.id) } } }
                    }
                }
            }
        }
    }

    private func konumlariOku() -> [String: CGPoint] {
        var s: [String: CGPoint] = [:]
        for (id, d) in depo.veri.araziLayout?["positions"]?.nesneDegeri ?? [:] {
            if let x = d["x"]?.sayi, let y = d["y"]?.sayi { s[id] = CGPoint(x: x, y: y) }
        }
        return s
    }

    private func araLar() -> [(id: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] {
        (depo.veri.araziLayout?["spacers"]?.diziDegeri ?? []).compactMap { a -> (id: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)? in
            guard let id = a["id"]?.metinDegeri, let x = a["x"]?.sayi, let y = a["y"]?.sayi else { return nil }
            return (id, CGFloat(x), CGFloat(y), CGFloat(a["w"]?.sayi ?? 40), CGFloat(a["h"]?.sayi ?? 20))
        }
    }

    private func tasi(_ id: String, _ p: CGPoint, _ f: CGSize) {
        let yeni = CGPoint(x: max(0, (p.x + f.width).rounded()), y: max(0, (p.y + f.height).rounded()))
        konumYaz([id: yeni])
    }

    /// Web araziAutoPlace: ızgara adımları hücre×1,6 / ×2,4, dolu yerleri atla.
    private func otomatikYerlestir(_ liste: [Kovan]) {
        let mevcut = konumlariOku()
        let sutun = max(3, Int(Double(liste.count + mevcut.count).squareRoot().rounded(.up)))
        let cAdim = (80 * 1.6).rounded(), rAdim = (80 * 2.4).rounded()
        var dolu = Set(mevcut.values.map { "\(Int(($0.x / cAdim).rounded())),\(Int(($0.y / rAdim).rounded()))" })
        var c = 0, r = 0
        var yeni: [String: CGPoint] = [:]
        for k in liste {
            while dolu.contains("\(c),\(r)") { c += 1; if c >= sutun { c = 0; r += 1 } }
            dolu.insert("\(c),\(r)")
            yeni[k.id] = CGPoint(x: CGFloat(c) * cAdim + 40, y: CGFloat(r) * rAdim + 40)
        }
        konumYaz(yeni)
    }

    private func konumYaz(_ yeni: [String: CGPoint]) {
        depo.degistir { v in
            var lay = v.araziLayout ?? [:]
            var konum = lay["positions"]?.nesneDegeri ?? [:]
            for (id, p) in yeni { konum[id] = .nesne(["x": .sayidan(p.x), "y": .sayidan(p.y)]) }
            lay["positions"] = .nesne(konum)
            if lay["spacers"] == nil { lay["spacers"] = .dizi([]) }
            lay["_up"] = .tam(VeriDeposu.simdiMs)
            v.araziLayout = lay
        }
    }
}

struct AraziKovani: View {
    let kovan: Kovan
    let genislik: CGFloat
    var body: some View {
        VStack(spacing: -4) {
            Image(kovan.gorselAdi).resizable().scaledToFit().frame(width: genislik)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 4)
            HStack(spacing: 3) {
                if kovan.anaNoktasiGoster && !kovan.sorunlu { AnaNoktasi(renk: kovan.queenColor, boyut: 8) }
                Text(kovan.sorunlu ? "\(kovan.num) · anasız" : kovan.num).font(Yazi.nunito(11, .bold))
            }
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(kovan.sorunlu ? Renk.kotu : etiketRenk, in: Capsule())
            .foregroundStyle(kovan.sorunlu || kovan.queenStatus == "meme" ? .white : Renk.metin)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kovan \(kovan.num), \(kovan.anaDurumMetni)")
    }
    private var etiketRenk: Color { kovan.queenStatus == "meme" ? Renk.mor : Renk.kart }
}
