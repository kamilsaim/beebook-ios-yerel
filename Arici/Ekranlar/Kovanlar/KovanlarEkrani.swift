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
        .onChange(of: menu.yeniKovanIstegi) { _, _ in yeniForm = true }
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

    private var tumKovanlar: [Kovan] {
        depo.veri.kovanlar.sorted { a, b in a.starred != b.starred ? a.starred : (a.numara != b.numara ? a.numara < b.numara : a.num < b.num) }
    }

    private var suzulmus: [Kovan] {
        var k = tumKovanlar
        switch filtre {
        case "tumu": break
        case "yildiz": k = k.filter(\.starred)
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
                    if hepsi.contains(where: \.starred) { cip("yildiz", "★ Öne çıkan") }
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
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

/// Kovan kartı: arka plan görseli, büyük kovan resmi, başlık + yıldız, tip · ırk · sağlık rozetleri tek satırda, dikey ayraçlı 2×2 bilgi.
struct KovanSatiri: View {
    @Environment(VeriDeposu.self) private var depo
    let kovan: Kovan
    var sonMuayene: Muayene? = nil

    var body: some View {
        let sekil = RoundedRectangle(cornerRadius: Olcu.kartYaricap, style: .continuous)
        HStack(spacing: 6) {
            VStack(spacing: 2) {
                Image(kovan.gorselAdi).resizable().scaledToFit()
                    .frame(width: 96, height: 108)
                    .grayscale(kovan.arisiz ? 1 : 0).opacity(kovan.arisiz ? 0.6 : 1)
                KovanRenkSeridi(kovan: kovan)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center) {
                    Text("Kovan \(kovan.num)").font(Yazi.nunito(21, .bold)).foregroundStyle(kovan.arisiz ? Color(white: 0.3) : Renk.orman).lineLimit(1)
                    Spacer(minLength: 0)
                    Button { depo.yildizDegistir(kovan.id) } label: {
                        Image(systemName: kovan.starred ? "star.fill" : "star")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(kovan.starred ? Color(red: 0.9, green: 0.62, blue: 0.05) : Renk.metin3)
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(kovan.starred ? "Yıldızı kaldır" : "Yıldızla")
                }
                rozetler
                Rectangle().fill(kartAltin.opacity(0.25)).frame(height: 1)
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        bilgi(AnyView(Image("IkonAnaAri").resizable().scaledToFit().frame(width: 17, height: 17)), "Ana arı", anaBilgisi, nokta: kovan.anaNoktasiGoster)
                        bilgi(AnyView(simge("hexagon")), "Koloni gücü", guc)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Rectangle().fill(kartAltin.opacity(0.25)).frame(width: 1).padding(.horizontal, 7)
                    VStack(alignment: .leading, spacing: 6) {
                        bilgi(AnyView(simge("oval.portrait")), "Yavru", yavru)
                        bilgi(AnyView(simge("calendar")), "Son kontrol", sonMuayene?.date.map { kisaTarih($0) } ?? "—")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, kovan.starred ? 16 : 8).padding(.bottom, 8).padding(.leading, 4).padding(.trailing, 12)
        .background {
            Image("KartKovan").resizable().scaledToFill()
                .grayscale(kovan.arisiz ? 1 : 0).opacity(kovan.arisiz ? 0.45 : 1)
        }
        .clipShape(sekil)
        .overlay(alignment: .topLeading) { if kovan.starred { OneCikanSeridi() } }
        .kovanKartiStili(kovan, yaricap: Olcu.kartYaricap)
        .accessibilityElement(children: .combine)
    }

    private var rozetler: some View {
        let irk = (kovan.race ?? "").isEmpty || kovan.arisiz ? nil : kovan.race
        return HStack(spacing: 5) {
            if let t = kovan.type, !t.isEmpty {
                Rozet(metin: t, simge: "square.stack.3d.up", arkaRenk: Color.white.opacity(0.7))
            }
            if let irk { Rozet(metin: irk, simge: "ladybug", arkaRenk: Renk.bal.opacity(0.22)) }
            switch kovan.saglikDurumu {
            case .saglikli: Rozet(metin: "Sağlıklı", tur: .iyi, simge: "checkmark.circle.fill")
            case .dikkat: Rozet(metin: kovan.dikkatNedeni, tur: .uyari, simge: "exclamationmark.triangle.fill")
            case .mudahale: Rozet(metin: "Ana yok", tur: .kotu, simge: "xmark.octagon.fill")
            case .arisiz: Rozet(metin: "Arısız")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var anaBilgisi: String {
        guard kovan.anaNoktasiGoster, let y = kovan.anaYili else { return kovan.anaDurumMetni }
        let yas = Calendar.current.component(.year, from: Date()) - y
        return yas <= 0 ? "\(y) · bu yıl" : "\(y) · \(yas) yaş"
    }

    private var guc: String {
        if kovan.arisiz { return "—" }
        if let s = sonMuayene?.strength, let g = Int(s) { return g >= 4 ? "Güçlü" : g == 3 ? "Orta" : "Zayıf" }
        return kovan.gucMetni ?? (kovan.frames.map { "\(Int($0)) çerçeve" } ?? "—")
    }

    private var yavru: String {
        guard let b = sonMuayene?.brood else { return "—" }
        return ["duzenli": "Düzenli", "seyrek": "Seyrek", "yok": "Yok"][b] ?? b
    }

    private func simge(_ ad: String) -> some View {
        Image(systemName: ad).font(.system(size: 14)).foregroundStyle(kartAltin)
    }

    private func bilgi(_ ikon: AnyView, _ baslik: String, _ deger: String, nokta: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 5) {
            ikon.frame(width: 18, height: 18).padding(.top, 2)
            VStack(alignment: .leading, spacing: 0) {
                Text(baslik).font(Yazi.nunito(11)).foregroundStyle(Renk.metin2)
                HStack(spacing: 4) {
                    if nokta { AnaNoktasi(renk: kovan.queenColor, boyut: 8) }
                    Text(deger).font(Yazi.nunito(13, .semibold)).lineLimit(1).minimumScaleFactor(0.75)
                }
            }
        }
    }
}

/// "Öne Çıkan" şeridi (kartın sol üst köşesi).
struct OneCikanSeridi: View {
    var yaricap: CGFloat = Olcu.kartYaricap
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "rosette").font(.system(size: 11, weight: .bold)).foregroundStyle(Renk.acikBal)
            Text("Öne Çıkan").font(Yazi.nunito(11, .bold)).foregroundStyle(.white)
        }
        .padding(.leading, 12).padding(.trailing, 10).padding(.vertical, 4)
        .background(
            LinearGradient(colors: [Color(red: 0.55, green: 0.36, blue: 0.05), Color(red: 0.75, green: 0.52, blue: 0.1)], startPoint: .leading, endPoint: .trailing),
            in: UnevenRoundedRectangle(topLeadingRadius: yaricap, bottomTrailingRadius: 14, style: .continuous)
        )
    }
}

/// Izgara hücresi: arka plan görseli, kovan resmi, "Kovan N", sağlık rozeti, ırk; sağ üstte yıldız.
struct KovanIzgaraHucresi: View {
    @Environment(VeriDeposu.self) private var depo
    let kovan: Kovan
    var body: some View {
        let sekil = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let (metin, renk, simge): (String, Color, String) = {
            switch kovan.saglikDurumu {
            case .saglikli: return ("Sağlıklı", Renk.iyi, "checkmark.circle.fill")
            case .dikkat: return (kovan.dikkatNedeni, Renk.uyari, "exclamationmark.triangle.fill")
            case .mudahale: return ("Ana yok", Renk.kotu, "xmark.octagon.fill")
            case .arisiz: return ("Arısız", Renk.metin3, "archivebox")
            }
        }()
        VStack(spacing: 3) {
            Image(kovan.gorselAdi).resizable().scaledToFit().frame(width: 76, height: 74)
                .grayscale(kovan.arisiz ? 1 : 0).opacity(kovan.arisiz ? 0.6 : 1)
                .overlay(alignment: .bottom) { KovanRenkSeridi(kovan: kovan) }
            HStack(spacing: 4) {
                if kovan.anaNoktasiGoster { AnaNoktasi(renk: kovan.queenColor, boyut: 9) }
                Text("Kovan \(kovan.num)").font(Yazi.nunito(15, .bold)).foregroundStyle(kovan.arisiz ? Color(white: 0.3) : Renk.orman).lineLimit(1).minimumScaleFactor(0.8)
            }
            HStack(spacing: 3) {
                Image(systemName: simge).font(.system(size: 9, weight: .semibold))
                Text(metin).font(Yazi.nunito(10, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(renk)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(renk.opacity(0.14), in: Capsule())
            Text((!(kovan.race ?? "").isEmpty && !kovan.arisiz ? kovan.race : kovan.type) ?? " ").font(Yazi.nunito(10)).foregroundStyle(Renk.metin2).lineLimit(1)
        }
        .padding(.top, 8).padding(.bottom, 9).padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background { Image("KartKovan").resizable().scaledToFill().grayscale(kovan.arisiz ? 1 : 0).opacity(kovan.arisiz ? 0.45 : 1) }
        .clipShape(sekil)
        .overlay(alignment: .topTrailing) {
            Button { depo.yildizDegistir(kovan.id) } label: {
                Image(systemName: kovan.starred ? "star.fill" : "star").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(kovan.starred ? Color(red: 0.9, green: 0.62, blue: 0.05) : Renk.metin3.opacity(0.7))
                    .frame(width: 30, height: 30).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(kovan.starred ? "Yıldızı kaldır" : "Yıldızla")
        }
        .overlay(alignment: .topLeading) {
            if kovan.starred {
                Image(systemName: "rosette").font(.system(size: 11, weight: .bold)).foregroundStyle(Renk.acikBal)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(LinearGradient(colors: [Color(red: 0.55, green: 0.36, blue: 0.05), Color(red: 0.75, green: 0.52, blue: 0.1)], startPoint: .leading, endPoint: .trailing),
                                in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomTrailingRadius: 12, style: .continuous))
            }
        }
        .kovanKartiStili(kovan, yaricap: 18)
    }
}

extension Kovan {
    /// Kart ışıması: yıldızlı altın; ana var ama dikkat (yaşlı/zayıf) turuncu; diğerleri ana durumuna göre.
    var kartIsigi: Color? {
        if arisiz { return nil }
        if starred { return Renk.bal }
        if queenStatus == "yes" && saglikDurumu == .dikkat { return Color(red: 1, green: 0.66, blue: 0.1) }
        return isimaRengi
    }
}

extension View {
    /// Kovan kartı: geçişli (gradyan) kenar + ana durumuna göre geniş renkli ışıma; arısız gri ve ışımasız.
    func kovanKartiStili(_ kovan: Kovan, yaricap: CGFloat) -> some View {
        let sekil = RoundedRectangle(cornerRadius: yaricap, style: .continuous)
        let isik = kovan.kartIsigi
        let kalin = kovan.starred || kovan.sorunlu
        return self
            .background(kovan.arisiz ? Color(white: 0.78) : Renk.krem, in: sekil)
            .overlay {
                if let isik {
                    sekil.strokeBorder(LinearGradient(colors: [isik, isik.opacity(0.12), isik.opacity(0.35), isik], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: kalin ? 2.5 : 2)
                }
            }
            .shadow(color: (isik ?? .black).opacity(isik == nil ? 0.2 : 0.7), radius: isik == nil ? 6 : (kalin ? 16 : 13))
            .shadow(color: .black.opacity(0.15), radius: 5, y: 4)
            .foregroundStyle(kovan.arisiz ? Color(white: 0.3) : Renk.metin)
    }
}
