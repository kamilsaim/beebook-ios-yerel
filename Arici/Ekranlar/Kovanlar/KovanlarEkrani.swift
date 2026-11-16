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
    @State private var oncekiGorunum: KovanGorunum = .liste
    @State private var yeniForm = false
    @State private var topluForm = false
    @State private var tarayici = false

    var body: some View {
        NavigationStack(path: $yol) {
            SekmeKaydirma(arka: "SayfaBokeh", koyuluk: 0.95) {
                ManzaraBasligi {
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
                liste
                .padding(.horizontal, Olcu.kenar)
                .padding(.top, 12)
            }
            .toolbar(.hidden, for: .navigationBar)
            .klavyeKapatici()
            .navigationDestination(for: String.self) { id in KovanDetayi(kovanId: id) }
        }
        .fullScreenCover(isPresented: Binding(get: { gorunum == .arazi }, set: { if !$0 { gorunum = oncekiGorunum } })) {
            AraziTamEkran()
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
        .onChange(of: gorunum) { eski, g in
            if eski != .arazi { oncekiGorunum = eski }
            if g != .arazi, depo.ayarlar.hiveView != (g == .izgara ? "grid" : "list") {
                depo.ayarDegistir { $0.hiveView = g == .izgara ? "grid" : "list" }
            }
        }
        .onChange(of: menu.araziIstegi) { _, _ in yol = NavigationPath(); gorunum = .arazi }
    }

    /// Kovan id → en son muayene (tarihe göre).
    private var sonMuayeneler: [String: Muayene] {
        var s: [String: Muayene] = [:]
        for m in depo.veri.muayeneler {
            guard let h = m.hiveId else { continue }
            if (m.date ?? "") >= (s[h]?.date ?? "") { s[h] = m }
        }
        return s
    }

    private var tumKovanlar: [Kovan] { depo.veri.kovanlar.sorted { $0.numara < $1.numara } }

    private var suzulmus: [Kovan] {
        var k = tumKovanlar
        switch filtre {
        case "tumu": break
        case "anasiz": k = k.filter { $0.queenStatus == "no" }
        case "bakire": k = k.filter { ["bakire", "new"].contains($0.queenStatus ?? "") }
        case "yasli": k = k.filter(\.yasliAna)
        case "arisiz": k = k.filter(\.arisiz)
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
                sayi("\(hepsi.count)", "Toplam", .white, simge: "square.stack.3d.up.fill")
                sayi("\(hepsi.filter { $0.saglikDurumu == .saglikli }.count)", "Sağlıklı", Color(red: 0.62, green: 0.88, blue: 0.66), simge: "checkmark.circle.fill")
                sayi("\(hepsi.filter { $0.saglikDurumu == .dikkat }.count)", "Dikkat", Renk.acikBal, simge: "exclamationmark.triangle.fill")
                sayi("\(hepsi.filter { $0.saglikDurumu == .mudahale }.count)", "Müdahale", Color(red: 1, green: 0.62, blue: 0.56), simge: "xmark.circle.fill")
                sayi("\(hepsi.filter(\.arisiz).count)", "Arısız", Color(white: 0.78), simge: "archivebox")
            }
            .padding(.vertical, 10)
            .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(Renk.ormanKoyu.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Renk.bal.opacity(0.25)))

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    cip("tumu", "Tümü")
                    cip("anasiz", "Anasız", nokta: Renk.kotu)
                    cip("bakire", "Bakire")
                    cip("yasli", "Yaşlı ana")
                    cip("arisiz", "Arısız", nokta: Color(white: 0.7))
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
                let sonMuayene = sonMuayeneler
                LazyVStack(spacing: 12) {
                    ForEach(k, id: \.id) { kv in
                        NavigationLink(value: kv.id) { KovanSatiri(kovan: kv, sonMuayene: sonMuayene[kv.id]) }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sayi(_ d: String, _ e: String, _ r: Color, simge: String) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: simge).font(.system(size: 13)).foregroundStyle(r)
                Text(d).font(Yazi.nunito(20, .bold)).foregroundStyle(.white)
            }
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

/// Kovan kartı (yenilogoo/kovandetay): büyük görsel, tip + sağlık rozeti, 2×2 bilgi (ana, yavru, güç, son kontrol).
struct KovanSatiri: View {
    let kovan: Kovan
    var sonMuayene: Muayene? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(kovan.gorselAdi).resizable().scaledToFit()
                .frame(width: 92, height: 104)
                .grayscale(kovan.arisiz ? 1 : 0).opacity(kovan.arisiz ? 0.6 : 1)
                .background(alignment: .bottom) {
                    Ellipse().fill(Color(red: 0.55, green: 0.7, blue: 0.35).opacity(kovan.arisiz ? 0 : 0.35))
                        .frame(width: 90, height: 18).blur(radius: 5)
                }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Kovan \(kovan.num)").font(Yazi.logo(25)).foregroundStyle(Renk.orman).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Renk.metin3)
                }
                HStack(spacing: 6) {
                    if let t = kovan.type, !t.isEmpty {
                        Rozet(metin: kovan.katSayisi > 1 ? "\(t) · \(kovan.katSayisi) kat" : t)
                    }
                    saglikRozeti
                }
                Divider().overlay(Renk.krem2)
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 5) {
                    GridRow {
                        bilgi("crown", "Ana arı", anaBilgisi, nokta: kovan.anaNoktasiGoster)
                        bilgi("circle.hexagongrid", "Yavru", yavru)
                    }
                    GridRow {
                        bilgi("bolt.heart", "Koloni gücü", guc)
                        bilgi("calendar", "Son kontrol", sonMuayene?.date.map { kisaTarih($0) } ?? "—")
                    }
                }
            }
        }
        .padding(.vertical, 10).padding(.leading, 6).padding(.trailing, 12)
        .kovanKartiStili(kovan, yaricap: Olcu.kartYaricap)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var saglikRozeti: some View {
        switch kovan.saglikDurumu {
        case .saglikli: Rozet(metin: "Sağlıklı", tur: .iyi)
        case .dikkat: Rozet(metin: kovan.yasliAna ? "Yaşlı ana" : kovan.anaDurumMetni, tur: .uyari)
        case .mudahale: Rozet(metin: "Ana yok", tur: .kotu)
        case .arisiz: Rozet(metin: "Arısız")
        }
    }

    private var anaBilgisi: String {
        guard kovan.anaNoktasiGoster else { return kovan.anaDurumMetni }
        var p: [String] = []
        if let y = kovan.anaYili {
            let yas = Calendar.current.component(.year, from: Date()) - y
            p.append(yas <= 0 ? "\(y) · bu yıl" : "\(y) · \(yas) yaş")
        }
        if let r = kovan.race, !r.isEmpty { p.append(r) }
        return p.isEmpty ? kovan.anaDurumMetni : p.joined(separator: " · ")
    }

    private var guc: String {
        if let s = sonMuayene?.strength, let g = Int(s) { return g >= 4 ? "Güçlü" : g == 3 ? "Orta" : "Zayıf" }
        return kovan.gucMetni ?? (kovan.frames.map { "\(Int($0)) çerçeve" } ?? "—")
    }

    private var yavru: String {
        guard let b = sonMuayene?.brood else { return "—" }
        return ["duzenli": "Düzenli", "seyrek": "Seyrek", "yok": "Yok"][b] ?? b
    }

    private func bilgi(_ simge: String, _ baslik: String, _ deger: String, nokta: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: simge).font(.system(size: 14)).foregroundStyle(Color(red: 0.8, green: 0.55, blue: 0.05)).frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(baslik).font(Yazi.nunito(11, .regular)).foregroundStyle(Renk.metin2)
                HStack(spacing: 4) {
                    if nokta { AnaNoktasi(renk: kovan.queenColor, boyut: 8) }
                    Text(deger).font(Yazi.nunito(14, .semibold)).foregroundStyle(Renk.metin).lineLimit(1).minimumScaleFactor(0.75)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KovanIzgaraHucresi: View {
    let kovan: Kovan
    var body: some View {
        VStack(spacing: 4) {
            Image(kovan.gorselAdi).resizable().scaledToFit().frame(height: 70)
                .grayscale(kovan.arisiz ? 1 : 0).opacity(kovan.arisiz ? 0.6 : 1)
            HStack(spacing: 4) {
                if kovan.anaNoktasiGoster { AnaNoktasi(renk: kovan.queenColor, boyut: 9) }
                Text(kovan.num).font(Yazi.nunito(16, .bold))
            }
            Text(kovan.anaDurumMetni).font(Yazi.minik).foregroundStyle(kovan.sorunlu ? Renk.kotu : Renk.metin2)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .kovanKartiStili(kovan, yaricap: 18)
    }
}

extension View {
    /// Kovan kartı: krem zemin + ana arı durumuna göre renkli ışıma; arısız kovan gri ve ışımasız.
    func kovanKartiStili(_ kovan: Kovan, yaricap: CGFloat) -> some View {
        let sekil = RoundedRectangle(cornerRadius: yaricap, style: .continuous)
        let isik = kovan.isimaRengi
        return self
            .background(kovan.arisiz ? Color(white: 0.78) : Renk.krem, in: sekil)
            .overlay(sekil.strokeBorder((isik ?? .clear).opacity(kovan.sorunlu ? 0.95 : 0.7), lineWidth: kovan.sorunlu ? 2 : 1.5))
            .shadow(color: (isik ?? .black).opacity(isik == nil ? 0.2 : 0.55), radius: 10)
            .shadow(color: .black.opacity(0.2), radius: 6, y: 5)
            .foregroundStyle(kovan.arisiz ? Color(white: 0.3) : Renk.metin)
    }
}
