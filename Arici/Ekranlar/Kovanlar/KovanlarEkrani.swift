import AriCekirdek
import SwiftUI

enum KovanGorunum: String { case liste, izgara, arazi }

let varsayilanKovanTipleri = ["Langstroth", "Dadant", "Yerli", "Çerçeveli", "Ana Arı Kovanı", "Nükleus (Ruşet)", "Diğer"]
let varsayilanIrklar = ["Kafkas", "Karadeniz", "İtalyan", "Karniyol", "Buckfast", "Anadolu", "Muğla", "Diğer"]

extension VeriDeposu {
    var kovanTipleri: [String] { (ayarlar.hiveTypes?.isEmpty == false ? ayarlar.hiveTypes : nil) ?? varsayilanKovanTipleri }
    var irklar: [String] { (ayarlar.beeRaces?.isEmpty == false ? ayarlar.beeRaces : nil) ?? varsayilanIrklar }
    func kovan(_ id: String?) -> Kovan? { veri.kovanlar.first { $0.id == id } }
}

struct KovanlarEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(MenuDurumu.self) private var menu
    @State private var yol = NavigationPath()
    @State private var arama = ""
    @State private var filtre = "tumu"
    @State private var gorunum: KovanGorunum = .liste
    @State private var yeniForm = false
    @State private var topluForm = false
    @State private var tarayici = false

    var body: some View {
        NavigationStack(path: $yol) {
            SekmeKaydirma {
                ManzaraBasligi(gorsel: "ArkaYesil") {
                    HStack {
                        Marka(kucuk: true)
                        Spacer()
                        Menu {
                            Button { yeniForm = true } label: { Label("Kovan ekle", systemImage: "plus") }
                            Button { topluForm = true } label: { Label("Toplu kovan ekle", systemImage: "square.stack.3d.up") }
                        } label: {
                            Image(systemName: "plus").font(.system(size: 17, weight: .medium)).foregroundStyle(.white)
                                .frame(width: 40, height: 40).background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.25)))
                        }
                        .accessibilityLabel("Kovan ekle")
                    }
                    BuyukBaslik(metin: "Kovanlar")
                    HStack(spacing: 8) {
                        HStack(spacing: 7) {
                            Image(systemName: "magnifyingglass")
                            TextField("", text: $arama, prompt: Text("No, ırk veya not ara").foregroundStyle(Color(white: 0.8)))
                                .font(Yazi.govde).foregroundStyle(.white)
                                .autocorrectionDisabled()
                            if !arama.isEmpty { Button { arama = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) }
                        }
                        .padding(.horizontal, 12).frame(height: 44)
                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.18)))
                        Button { tarayici = true } label: {
                            Label("Tara", systemImage: "barcode.viewfinder").font(Yazi.govdeOrta)
                                .padding(.horizontal, 14).frame(height: 44)
                                .background(Renk.bal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(Renk.ormanKoyu)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 12)
                    Segment(secenekler: [(KovanGorunum.liste, "Liste"), (.izgara, "Izgara"), (.arazi, "Arazi")], secili: $gorunum)
                        .padding(.top, 12)
                }
                Group {
                    if gorunum == .arazi {
                        AraziGorunumu { yol.append($0) }
                    } else {
                        liste
                    }
                }
                .padding(.horizontal, Olcu.kenar)
                .padding(.top, 12)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { id in KovanDetayi(kovanId: id) }
        }
        .sheet(isPresented: $yeniForm) { KovanFormu(kovanId: nil) }
        .sheet(isPresented: $topluForm) { TopluKovanFormu() }
        .sheet(isPresented: $tarayici) {
            BarkodSayfasi { kod in
                arama = kod
                if let k = depo.veri.kovanlar.first(where: { $0.num == kod || ($0.notes ?? "").contains(kod) }) { yol.append(k.id) }
            }
        }
        .onAppear { gorunum = depo.ayarlar.hiveView == "grid" ? .izgara : .liste }
        .onChange(of: gorunum) { _, g in
            if g != .arazi, depo.ayarlar.hiveView != (g == .izgara ? "grid" : "list") {
                depo.ayarDegistir { $0.hiveView = g == .izgara ? "grid" : "list" }
            }
        }
        .onChange(of: menu.araziIstegi) { _, _ in yol = NavigationPath(); gorunum = .arazi }
    }

    private var tumKovanlar: [Kovan] { depo.veri.kovanlar.sorted { $0.numara < $1.numara } }

    private var suzulmus: [Kovan] {
        var k = tumKovanlar
        switch filtre {
        case "tumu": break
        case "anasiz": k = k.filter { $0.queenStatus == "no" }
        case "bakire": k = k.filter { ["bakire", "new"].contains($0.queenStatus ?? "") }
        case "yasli": k = k.filter(\.yasliAna)
        default:
            if filtre.hasPrefix("irk:") { k = k.filter { $0.race == String(filtre.dropFirst(4)) } }
            if filtre.hasPrefix("tip:") { k = k.filter { $0.type == String(filtre.dropFirst(4)) } }
        }
        let a = arama.trimmingCharacters(in: .whitespaces).lowercased()
        if !a.isEmpty {
            k = k.filter { [$0.num, $0.race ?? "", $0.notes ?? "", $0.type ?? "", $0.generation ?? ""].contains { $0.lowercased().contains(a) } }
        }
        return k
    }

    @ViewBuilder
    private var liste: some View {
        let hepsi = tumKovanlar
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                sayi("\(hepsi.count)", "Kovan", .white)
                sayi("\(hepsi.filter { $0.queenStatus == "yes" }.count)", "Analı", Color(red: 0.62, green: 0.88, blue: 0.66))
                sayi("\(hepsi.filter { ["bakire", "new"].contains($0.queenStatus ?? "") }.count)", "Bakire", Color(red: 0.56, green: 0.74, blue: 0.94))
                sayi("\(hepsi.filter { $0.queenStatus == "no" }.count)", "Anasız", Color(red: 1, green: 0.62, blue: 0.56))
            }
            .padding(.vertical, 10)
            .background(Renk.orman.opacity(0.8), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Renk.bal.opacity(0.25)))

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    cip("tumu", "Tümü")
                    cip("anasiz", "Anasız", nokta: Renk.kotu)
                    cip("bakire", "Bakire")
                    cip("yasli", "Yaşlı ana")
                    ForEach(Array(Set(hepsi.compactMap(\.race)).filter { !$0.isEmpty }).sorted(), id: \.self) { cip("irk:\($0)", $0) }
                    ForEach(Array(Set(hepsi.compactMap(\.type)).filter { !$0.isEmpty }).sorted(), id: \.self) { cip("tip:\($0)", $0) }
                }
            }
            .scrollIndicators(.hidden)

            let k = suzulmus
            if k.isEmpty {
                BosDurum(simge: "archivebox", baslik: hepsi.isEmpty ? "Henüz kovan yok" : "Eşleşen kovan yok",
                         alt: hepsi.isEmpty ? "Sağ üstteki + ile kovan ekle." : nil)
            } else if gorunum == .izgara {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                    ForEach(k, id: \.id) { kv in
                        NavigationLink(value: kv.id) { KovanIzgaraHucresi(kovan: kv) }.buttonStyle(.plain)
                    }
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(k, id: \.id) { kv in
                        NavigationLink(value: kv.id) { KovanSatiri(kovan: kv) }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sayi(_ d: String, _ e: String, _ r: Color) -> some View {
        VStack(spacing: 1) {
            Text(d).font(Yazi.nunito(20, .bold)).foregroundStyle(r)
            Text(e).font(Yazi.minik).foregroundStyle(Color(white: 0.78))
        }
        .frame(maxWidth: .infinity)
    }

    private func cip(_ id: String, _ ad: String, nokta: Color? = nil) -> some View {
        Button { filtre = filtre == id && id != "tumu" ? "tumu" : id } label: {
            HStack(spacing: 5) {
                if let nokta { Circle().fill(nokta).frame(width: 8, height: 8) }
                Text(ad).font(Yazi.kucukOrta)
            }
            .padding(.horizontal, 13).frame(height: 34)
            .foregroundStyle(filtre == id ? Renk.orman : Color(white: 0.9))
            .background(filtre == id ? Renk.krem : .white.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.16)))
        }
        .buttonStyle(.plain)
    }
}

struct KovanSatiri: View {
    let kovan: Kovan
    var body: some View {
        HStack(spacing: 10) {
            Image(kovan.gorselAdi).resizable().scaledToFit().frame(width: 76, height: 76)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("Kovan \(kovan.num)").font(Yazi.nunito(17, .bold))
                    Rozet(metin: [kovan.type, kovan.katSayisi > 1 ? "\(kovan.katSayisi) kat" : nil].compactMap { $0 }.joined(separator: " · "))
                }
                HStack(spacing: 6) {
                    if kovan.sorunlu { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Renk.kotu) }
                    else if kovan.anaNoktasiGoster { AnaNoktasi(renk: kovan.queenColor) }
                    Text(kovan.anaDurumMetni).foregroundStyle(kovan.sorunlu ? Renk.kotu : ["bakire", "new"].contains(kovan.queenStatus ?? "") ? Renk.bilgi : Renk.metin)
                    if let r = kovan.race, !r.isEmpty {
                        Text("·").foregroundStyle(Renk.metin3)
                        Text([r, kovan.generation].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")).foregroundStyle(Renk.orman2)
                    }
                }
                .font(Yazi.kucukOrta)
                Text(altSatir).font(Yazi.etiket).foregroundStyle(Renk.metin3).lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Renk.metin3)
        }
        .padding(.vertical, 8).padding(.leading, 6).padding(.trailing, 12)
        .background(Renk.krem, in: RoundedRectangle(cornerRadius: Olcu.kartYaricap, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Olcu.kartYaricap, style: .continuous).strokeBorder(kovan.sorunlu ? Renk.kotu : .clear, lineWidth: 2))
        .shadow(color: .black.opacity(0.22), radius: 9, y: 6)
        .foregroundStyle(Renk.metin)
        .accessibilityElement(children: .combine)
    }

    private var altSatir: String {
        var p: [String] = []
        if let y = kovan.year, !y.isEmpty, kovan.anaNoktasiGoster {
            p.append(kovan.yasliAna ? "\(y) anası · 2+ yaşında" : "\(y) anası")
        }
        if let f = kovan.frames, f > 0 { p.append("\(Int(f)) çerçeve") }
        if let g = kovan.gucMetni { p.append(g) }
        if let n = kovan.notes, !n.isEmpty { p.append(n) }
        return p.joined(separator: " · ")
    }
}

struct KovanIzgaraHucresi: View {
    let kovan: Kovan
    var body: some View {
        VStack(spacing: 4) {
            Image(kovan.gorselAdi).resizable().scaledToFit().frame(height: 70)
            HStack(spacing: 4) {
                if kovan.anaNoktasiGoster { AnaNoktasi(renk: kovan.queenColor, boyut: 9) }
                Text(kovan.num).font(Yazi.nunito(16, .bold))
            }
            Text(kovan.anaDurumMetni).font(Yazi.minik).foregroundStyle(kovan.sorunlu ? Renk.kotu : Renk.metin2)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Renk.krem, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(kovan.sorunlu ? Renk.kotu : .clear, lineWidth: 2))
        .foregroundStyle(Renk.metin)
    }
}
