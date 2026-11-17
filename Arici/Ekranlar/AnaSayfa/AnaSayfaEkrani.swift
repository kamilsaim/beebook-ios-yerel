import AriCekirdek
import SwiftUI

struct AnaSayfaEkrani: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(MenuDurumu.self) private var menu
    @State private var hava: HavaDurumu?
    @State private var havaHata = false
    @State private var bildirimler = false

    var body: some View {
        SekmeKaydirma(arka: "SayfaManzara") {
            ManzaraBasligi {
                HStack { Marka(); Spacer(); CamDugme(simge: "bell", nokta: !depo.bildirimler.isEmpty) { bildirimler = true }
                    .accessibilityLabel("Bildirimler") }
                SezonSecici().padding(.top, 14)
                HavaKarti(hava: hava, hata: havaHata, sehir: depo.ayarlar.city).padding(.top, 12)
                    .onTapGesture { menu.git(.daha) }
            }
            VStack(spacing: 12) {
                OzetKartlari()
                HizliErisim()
                YapilacaklarKarti()
                OzetRaporKarti()
                AnaAriDikkatKarti()
                IrkOzeti()
            }
            .padding(.horizontal, Olcu.kenar)
            .padding(.top, 12)
        }
        .task(id: depo.ayarlar.city) { await havaYukle() }
        .sheet(isPresented: $bildirimler) { BildirimlerSayfasi() }
    }

    private func havaYukle() async {
        let sehir = (depo.ayarlar.city?.isEmpty == false ? depo.ayarlar.city : nil) ?? "Muğla"
        do { hava = try await HavaServisi.paylasilan.getir(sehir: sehir); havaHata = false } catch { havaHata = hava == nil }
    }
}

/// Sezon seçici (menü) — `settings.activeSeason`.
struct SezonSecici: View {
    @Environment(VeriDeposu.self) private var depo
    var body: some View {
        let sezonlar = depo.veri.sezonlar.sorted { sezonBaslangici($0) > sezonBaslangici($1) }
        let aktif = sezonlar.first { $0.id == depo.ayarlar.activeSeason } ?? sezonlar.first
        Menu {
            ForEach(sezonlar, id: \.id) { s in
                Button { depo.ayarDegistir { $0.activeSeason = s.id } } label: {
                    if s.id == aktif?.id { Label(s.name ?? "Sezon", systemImage: "checkmark") } else { Text(s.name ?? "Sezon") }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "calendar").foregroundStyle(Renk.bal)
                Text(aktif?.name ?? "Sezon").font(Yazi.kucukOrta)
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Renk.ormanKoyu.opacity(0.6), in: Capsule())
            .overlay(Capsule().strokeBorder(Renk.bal.opacity(0.6)))
            .foregroundStyle(.white)
        }
        .accessibilityLabel("Sezon: \(aktif?.name ?? "")")
    }
}

struct HavaKarti: View {
    let hava: HavaDurumu?
    let hata: Bool
    let sehir: String?
    var body: some View {
        CamKart {
            if let hava {
                HStack(spacing: 10) {
                    Image(systemName: hava.simge).symbolRenderingMode(.multicolor).font(.system(size: 32))
                    Text("\(hava.derece)°").font(.system(size: 38, weight: .light)).monospacedDigit()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hava.durumMetni).font(Yazi.govdeOrta).foregroundStyle(.white)
                        Text(hava.sehir + (hava.rakim.map { " · \($0) m" } ?? "")).font(Yazi.kucuk).foregroundStyle(Color(white: 0.82))
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("En yüksek \(hava.enYuksek)°")
                        Text("Nem %\(hava.nem) · \(hava.ruzgar) km/s")
                    }
                    .font(Yazi.etiket).foregroundStyle(Color(white: 0.82))
                }
                Divider().overlay(.white.opacity(0.15))
                HStack {
                    ForEach(hava.saatlik) { s in
                        VStack(spacing: 3) {
                            Text(String(format: "%02d", s.saat)).font(Yazi.etiket).foregroundStyle(Color(white: 0.8))
                            Image(systemName: HavaDurumu.simge(s.kod)).symbolRenderingMode(.multicolor).font(.system(size: 15))
                            Text("\(s.derece)°").font(Yazi.kucukOrta)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                HStack {
                    Image(systemName: hata ? "wifi.slash" : "cloud.sun").font(.system(size: 22))
                    Text(hata ? "Hava durumu alınamadı" : "Hava durumu yükleniyor…").font(Yazi.kucuk)
                    Spacer()
                    Text(sehir ?? "").font(Yazi.kucuk).foregroundStyle(Color(white: 0.7))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct OzetKartlari: View {
    @Environment(VeriDeposu.self) private var depo
    var body: some View {
        let kovanlar = depo.veri.kovanlar
        let satislar = depo.sezonda(depo.veri.satislar)
        let gelir = satislar.reduce(0) { $0 + ($1.total ?? 0) }
        let bekleyen = bekleyenToplam(satislar: satislar)
        let haftaBasi = bugunISO(Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for: Date())?.start ?? Date())
        let bugun = bugunISO()
        // Bu hafta: tarihi bu haftaya düşen işler + bu hafta yapıldı işaretlenenler (tarihsiz olanlar dahil).
        let haftaIsleri = depo.veri.isler.filter { i in
            let d = String((i.dueDate ?? "").prefix(10))
            return (d >= haftaBasi && d <= bugun) || (i.done && i.yapildigiGun >= haftaBasi && i.yapildigiGun <= bugun)
        }
        let yapilan = haftaIsleri.filter(\.done).count
        let stokDegeri = depo.urunler.reduce(0) { $0 + max(0, stokSeviyesi(depo.veri, urun: $1.v)) * (depo.ayarlar.stockPrices[$1.v] ?? 0) }
        VStack(spacing: 10) {
        HStack(spacing: 10) {
            ozet(baslik: "Kovanlar", deger: "\(kovanlar.count)", gorsel: "UrunKovan") {
                (Text("\(kovanlar.filter { $0.queenStatus == "yes" }.count) analı").foregroundStyle(Renk.iyi)
                 + Text(" · ") + Text("\(kovanlar.filter { $0.queenStatus == "no" }.count) anasız").foregroundStyle(Renk.kotu))
            }
            ozet(baslik: "Sezon geliri", deger: tl(gelir), gorsel: "UrunSuzme") {
                bekleyen > 0 ? Text("\(tl(bekleyen)) bekliyor").foregroundStyle(Renk.uyari) : Text("Bekleyen yok").foregroundStyle(Renk.metin3)
            }
        }
        HStack(spacing: 10) {
            ozetSimgeli(baslik: "Yapılan işler", deger: "\(yapilan)/\(haftaIsleri.count)", simge: "checklist.checked") {
                Ilerleme(oran: haftaIsleri.isEmpty ? 0 : Double(yapilan) / Double(haftaIsleri.count))
                Text("Bu hafta").font(Yazi.minik).foregroundStyle(Renk.metin3)
            }
            ozetSimgeli(baslik: "Stok değeri", deger: tl(stokDegeri), simge: "shippingbox.fill") {
                Text("\(depo.urunler.filter { stokSeviyesi(depo.veri, urun: $0.v) > 0 }.count) üründe stok").font(Yazi.minik).foregroundStyle(Renk.metin3)
            }
        }
        }
    }

    private func ozetSimgeli<A: View>(baslik: String, deger: String, simge: String, @ViewBuilder alt: () -> A) -> some View {
        HStack(spacing: 8) {
            Image(systemName: simge).font(.system(size: 20)).foregroundStyle(Color(red: 0.8, green: 0.55, blue: 0.05))
                .frame(width: 40, height: 40).background(Renk.bal.opacity(0.18), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(baslik).font(Yazi.etiket).foregroundStyle(Renk.metin2)
                Text(deger).font(Yazi.nunito(19, .bold)).lineLimit(1).minimumScaleFactor(0.6)
                alt()
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Renk.krem, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 9, y: 6)
        .foregroundStyle(Renk.metin)
        .accessibilityElement(children: .combine)
    }

    private func ozet(baslik: String, deger: String, gorsel: String, @ViewBuilder alt: () -> Text) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(baslik).font(Yazi.etiket).foregroundStyle(Renk.metin2)
                Text(deger).font(Yazi.buyukSayi).lineLimit(1).minimumScaleFactor(0.6)
                alt().font(Yazi.minik).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            Image(gorsel).resizable().scaledToFill().frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Renk.krem, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 9, y: 6)
        .foregroundStyle(Renk.metin)
        .accessibilityElement(children: .combine)
    }
}

/// Işıklı hızlı erişim simgeleri.
struct HizliErisim: View {
    @Environment(MenuDurumu.self) private var menu
    var body: some View {
        HStack(spacing: 8) {
            simge("SimgeKovan", "Kovan") { menu.git(.kovanlar) }
            simge("SimgeAnaAri", "Ana Arı") { menu.git(.anaAri) }
            simge("SimgeSatis", "Satış") { menu.git(.satis); menu.yeniSatisIstegi += 1 }
            simge("SimgeArazi", "Arazi") { menu.git(.kovanlar); menu.araziIstegi += 1 }
        }
        .padding(.vertical, 4)
    }

    private func simge(_ gorsel: String, _ ad: String, _ eylem: @escaping () -> Void) -> some View {
        Button(action: eylem) {
            VStack(spacing: 6) {
                SimgeKutusu(ad: gorsel, boyut: 74)
                Text(ad).font(Yazi.etiket).foregroundStyle(Renk.krem)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ad)
    }
}
