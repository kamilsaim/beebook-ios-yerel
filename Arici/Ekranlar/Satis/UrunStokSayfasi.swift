import SwiftUI
import AriCekirdek

/// Ürünün stok sayfası (Stok › ürün kartına dokununca; Android UrunStokSayfasi ile aynı): mevcut miktar ve değer,
/// sayım düzeltmesi (gerçek miktar → fark kadar giriş/çıkış kaydı), ürünün stok kayıtları, ürün ayarları.
struct UrunStokSayfasi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let urunId: String

    @State private var gercek: Double = 0
    @State private var yuklendi = false
    @State private var not = ""
    @State private var onay = false
    @State private var hareketForm: HareketHedefi?
    @State private var girisFormu = false
    @State private var ayarlar = false

    var body: some View {
        let u = depo.urunler.first { $0.v == urunId }
        let birim = Birim(rawValue: u?.unit ?? "")
        let mevcut = stokSeviyesi(depo.veri, urun: urunId)
        let fiyat = depo.ayarlar.stockPrices[urunId] ?? 0
        let rezerve = rezerveMiktar(depo.veri, urun: urunId, urunBirimi: birim)
        let adim: Double = { switch birim { case .kg, .lt: return 0.5; case .gr, .ml: return 50; default: return 1 } }()
        let fark = ((gercek - mevcut) * 1000).rounded() / 1000
        let kayitlar = depo.veri.stokKayitlari.filter { $0.product == urunId }.sorted { ($0.date ?? "") > ($1.date ?? "") }
        let birimAdi = u?.unit ?? ""

        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        UrunGorseli(urun: u, boyut: 72, yaricap: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(u?.temizAd ?? "Ürün").font(Yazi.nunito(20, .heavy)).foregroundStyle(Renk.orman).lineLimit(1)
                            Text("Mevcut stok").font(Yazi.minik).foregroundStyle(Renk.metin2)
                            Text(miktar(mevcut, birimAdi)).font(Yazi.nunito(24, .heavy)).foregroundStyle(mevcut < 0 ? Renk.kotu : Renk.metin)
                            HStack(spacing: 5) {
                                if fiyat > 0 { Rozet(metin: tl(max(0, mevcut) * fiyat), simge: "turkishlirasign.circle", arkaRenk: Renk.bal.opacity(0.2)) }
                                if rezerve > 0 { Rozet(metin: "+\(miktar(rezerve, birimAdi)) rezerve", tur: .uyari) }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    HStack(spacing: 10) {
                        adimDugmesi("minus") { gercek = max(0, gercek - adim) }
                        HStack {
                            TextField("0", value: $gercek, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.center)
                                .font(Yazi.nunito(18, .bold))
                            Text(birimAdi).font(Yazi.nunito(15, .bold)).foregroundStyle(kartAltin)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Renk.bal.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Renk.bal.opacity(0.35)))
                        adimDugmesi("plus") { gercek += adim }
                    }
                    if fark != 0 {
                        TextField("Not (ör. Sayım, kırılan kavanoz)", text: $not)
                        HStack(spacing: 8) {
                            Image(systemName: fark > 0 ? "arrow.up" : "arrow.down").foregroundStyle(fark > 0 ? Renk.iyi : Renk.kotu)
                            Text((fark > 0 ? "+" : "−") + miktar(abs(fark), birimAdi) + (fark > 0 ? " giriş eklenecek" : " çıkış eklenecek"))
                                .font(Yazi.govdeOrta).foregroundStyle(fark > 0 ? Renk.iyi : Renk.kotu)
                            Spacer()
                            Button("Stoku güncelle") { onay = true }
                                .font(Yazi.nunito(13, .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Renk.orman2, in: Capsule())
                                .buttonStyle(.borderless)
                        }
                    }
                } header: { Label("Sayım düzeltmesi", systemImage: "slider.horizontal.3") } footer: {
                    Text("Elindeki gerçek miktarı yaz; aradaki fark bugünün tarihiyle giriş ya da çıkış kaydı olarak eklenir. Eski kayıtlar değişmez.")
                }

                Section {
                    Button { girisFormu = true } label: { Label("Stok girişi ekle", systemImage: "plus.circle.fill") }
                }

                Section {
                    if kayitlar.isEmpty { Text("Bu ürünün stok kaydı yok.").foregroundStyle(Renk.metin3) }
                    ForEach(kayitlar, id: \.id) { k in
                        let giris = k.action == "in"
                        let tur: String = {
                            if giris { return k.milkId != nil ? "Hasat" : "Giriş" }
                            guard k.saleId != nil else { return "Çıkış" }
                            let n = (k.note ?? "").components(separatedBy: ":").first ?? ""
                            return n == "Hediye" || n == "Zekat" ? n : "Satış"
                        }()
                        Button {
                            if let s = k.saleId { hareketForm = .satis(s) }
                            else if let m = k.milkId { hareketForm = .hasat(m) }
                            else { hareketForm = .giris(k.id) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: giris ? "arrow.up" : "arrow.down").font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(giris ? Renk.iyi : Renk.kotu)
                                    .frame(width: 30, height: 30).background((giris ? Renk.iyi : Renk.kotu).opacity(0.12), in: Circle())
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(tur).font(Yazi.kucukOrta).foregroundStyle(Renk.metin)
                                    Text([k.date.map { uzunTarih(String($0.prefix(10))) }, k.note.flatMap { $0.isEmpty ? nil : $0 }].compactMap { $0 }.joined(separator: " · "))
                                        .font(Yazi.minik).foregroundStyle(Renk.metin2).lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                Text((giris ? "+" : "−") + miktar(k.amount ?? 0, k.unit ?? ""))
                                    .font(Yazi.kucukOrta).foregroundStyle(giris ? Renk.iyi : Renk.kotu)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background((giris ? Renk.iyi : Renk.kotu).opacity(0.12), in: Capsule())
                            }
                        }
                    }
                } header: { Label("Stok kayıtları (\(kayitlar.count))", systemImage: "clock.arrow.circlepath") } footer: {
                    Text("Dokununca kayıt açılır: elle giriş/çıkış düzenlenir; satıştan düşenler o satışı, hasattan gelenler o hasadı açar.")
                }

                Section {
                    Button { ayarlar = true } label: { Label("Ürün ayarları (ad, birim, fiyat, görsel)", systemImage: "gearshape") }
                }
            }
            .navigationTitle(u?.temizAd ?? "Ürün")
            .navigationBarTitleDisplayMode(.inline)
            .formArkaplani()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { kapat() } } }
            .onAppear {
                guard !yuklendi else { return }
                yuklendi = true
                gercek = max(0, mevcut)
            }
            .onChange(of: mevcut) { _, yeni in gercek = max(0, yeni) }
            .alert("Stok güncellensin mi?", isPresented: $onay) {
                Button("Vazgeç", role: .cancel) {}
                Button("Güncelle") {
                    let f = fark, n = not.trimmingCharacters(in: .whitespaces)
                    depo.degistir { v in
                        var k = StokKaydi(["id": .metin(yeniKimlik())])
                        k.product = urunId; k.action = f > 0 ? "in" : "out"; k.amount = abs(f); k.unit = birimAdi
                        k.date = bugunISO(); k.note = n.isEmpty ? "Sayım düzeltmesi" : n
                        v.stokKayitlari = v.stokKayitlari + [k]
                    }
                    not = ""
                }
            } message: {
                Text("\(u?.temizAd ?? ""): \(miktar(mevcut, birimAdi)) → \(miktar(gercek, birimAdi)). " + (fark > 0 ? "\(miktar(fark, birimAdi)) giriş" : "\(miktar(-fark, birimAdi)) çıkış") + " kaydı eklenecek.")
            }
            .sheet(item: $hareketForm) { h in
                switch h {
                case .satis(let id): SatisFormu(satisId: id)
                case .hasat(let id): HasatFormu(hasatId: id)
                case .giris(let id): StokGirisFormu(kayitId: id)
                }
            }
            .sheet(isPresented: $girisFormu) { StokGirisFormu() }
            .sheet(isPresented: $ayarlar) { UrunFormu(urunId: urunId) }
        }
    }

    private func adimDugmesi(_ simge: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Image(systemName: simge).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(LinearGradient(colors: [Renk.orman2, Renk.orman], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
        }
        .buttonStyle(.borderless)
    }
}
