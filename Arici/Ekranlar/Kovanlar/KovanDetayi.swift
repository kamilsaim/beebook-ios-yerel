import AriCekirdek
import SwiftUI

/// Kovan detayı (yenilogoo/kovandetayı): üst çubuk, büyük görsel + başlık + rozetler, özet şerit,
/// yan yana Kovan Bilgileri / Hızlı Durum, son aktiviteler, notlar ve alt eylemler.
struct KovanDetayi: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var geri
    let kovanId: String
    @State private var duzenle = false
    @State private var muayene = false
    @State private var tumMuayeneler = false

    var body: some View {
        if let k = depo.kovan(kovanId) {
            let liste = depo.veri.muayeneler.filter { $0.hiveId == k.id }.sorted { ($0.date ?? "") > ($1.date ?? "") }
            let son = liste.first
            let gucSayi = (son?.strength ?? k.strength).flatMap { Int($0) }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ustCubuk(k)
                    baslik(k)
                    ozetSerit(k, son: son, guc: gucSayi)
                    HStack(alignment: .top, spacing: 10) {
                        bilgiler(k)
                        if !k.arisiz { hizliDurum(k, son: son, guc: gucSayi) }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    aktiviteler(liste)
                    if let n = k.notes, !n.trimmingCharacters(in: .whitespaces).isEmpty {
                        Kart { BolumBasligi(simge: "note.text", baslik: "Notlar", kucuk: true); Text(n).font(Yazi.govde) }
                    }
                    eylemler(k)
                }
                .padding(.horizontal, Olcu.kenar)
                .padding(.bottom, Olcu.altCubukPayi)
            }
            .scrollIndicators(.hidden)
            .background(SayfaArkaplani(gorsel: "SayfaBokeh", koyuluk: 0.95))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $duzenle) { KovanFormu(kovanId: k.id) }
            .sheet(isPresented: $muayene) { MuayeneFormu(kovanId: k.id) }
        } else {
            BosDurum(simge: "archivebox", baslik: "Kovan silindi").onAppear { geri() }
        }
    }

    // MARK: Parçalar

    private func ustCubuk(_ k: Kovan) -> some View {
        HStack {
            CamDugme(simge: "chevron.left") { geri() }.accessibilityLabel("Geri")
            Spacer()
            VStack(spacing: 0) {
                Marka(kucuk: true)
                Text("KOVAN DETAYI").font(Yazi.nunito(10, .bold)).tracking(3).foregroundStyle(Renk.acikBal)
            }
            Spacer()
            CamDugme(simge: k.starred ? "star.fill" : "star") { depo.yildizDegistir(k.id) }
                .accessibilityLabel(k.starred ? "Yıldızı kaldır" : "Yıldızla")
            CamDugme(simge: "pencil") { duzenle = true }.accessibilityLabel("Düzenle")
        }
    }

    private func baslik(_ k: Kovan) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(k.gorselAdi).resizable().scaledToFit().frame(width: 132, height: 150)
                .grayscale(k.arisiz ? 1 : 0)
                .shadow(color: .black.opacity(0.45), radius: 10, y: 10)
            VStack(alignment: .leading, spacing: 6) {
                if k.starred {
                    HStack(spacing: 4) {
                        Image(systemName: "rosette").font(.system(size: 11, weight: .bold))
                        Text("Öne Çıkan").font(Yazi.nunito(12, .bold))
                    }
                    .foregroundStyle(Renk.acikBal)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Renk.bal.opacity(0.18), in: Capsule())
                    .overlay(Capsule().strokeBorder(Renk.bal))
                }
                Text("Kovan \(k.num)").font(Yazi.nunito(30, .bold)).foregroundStyle(Renk.krem)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2).lineLimit(1).minimumScaleFactor(0.7)
                saglikRozeti(k)
                if let t = k.type, !t.isEmpty { hap("square.stack.3d.up", t) }
                let irk = [k.race, k.generation.map { kusakDuzelt($0) }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                if !irk.isEmpty, !k.arisiz { hap("ladybug", irk) }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func saglikRozeti(_ k: Kovan) -> some View {
        switch k.saglikDurumu {
        case .saglikli: Rozet(metin: "Sağlıklı", tur: .iyi, simge: "checkmark.circle.fill")
        case .dikkat: Rozet(metin: k.dikkatNedeni, tur: .uyari, simge: "exclamationmark.triangle.fill")
        case .mudahale: Rozet(metin: "Ana yok", tur: .kotu, simge: "xmark.octagon.fill")
        case .arisiz: Rozet(metin: "Arısız")
        }
    }

    private func hap(_ simge: String, _ metin: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: simge).font(.system(size: 12, weight: .semibold)).foregroundStyle(Renk.acikBal)
            Text(metin).font(Yazi.nunito(14, .semibold)).foregroundStyle(Renk.krem).lineLimit(1)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Renk.ormanKoyu.opacity(0.6), in: Capsule())
        .overlay(Capsule().strokeBorder(Renk.bal.opacity(0.6)))
    }

    private func ozetSerit(_ k: Kovan, son: Muayene?, guc: Int?) -> some View {
        let yas: String = {
            guard k.anaNoktasiGoster, let y = k.anaYili else { return k.anaDurumMetni }
            let f = Calendar.current.component(.year, from: Date()) - y
            return f <= 0 ? "Bu yıl" : "\(f) yaş"
        }()
        let gucAd = k.arisiz ? "—" : guc.map { $0 >= 4 ? "Güçlü" : $0 == 3 ? "Orta" : "Zayıf" } ?? "—"
        return HStack(spacing: 0) {
            seritHucre(AnyView(Image("IkonAnaAri").resizable().scaledToFit().frame(width: 26, height: 26)), "Ana arı yaşı", yas)
            Rectangle().fill(Renk.bal.opacity(0.4)).frame(width: 1, height: 34)
            seritHucre(AnyView(Image(systemName: "hexagon").font(.system(size: 20)).foregroundStyle(Renk.bal)), "Koloni gücü", gucAd)
            Rectangle().fill(Renk.bal.opacity(0.4)).frame(width: 1, height: 34)
            seritHucre(AnyView(Image(systemName: "calendar").font(.system(size: 20)).foregroundStyle(Renk.bal)), "Son kontrol", son?.date.map { kisaTarih($0) } ?? "—")
        }
        .padding(.vertical, 10)
        .background(Renk.ormanKoyu.opacity(0.75), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(LinearGradient(colors: [Renk.acikBal, Renk.bal.opacity(0.4), Renk.acikBal], startPoint: .leading, endPoint: .trailing), lineWidth: 2))
    }

    private func seritHucre(_ ikon: AnyView, _ e: String, _ d: String) -> some View {
        HStack(spacing: 8) {
            ikon
            VStack(alignment: .leading, spacing: 0) {
                Text(e).font(Yazi.minik).foregroundStyle(Color(white: 0.85)).lineLimit(1)
                Text(d).font(Yazi.nunito(15, .bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func bilgiler(_ k: Kovan) -> some View {
        let seri = depo.veri.seriler.first { s in s.memeler.contains { $0.targetHive == k.id } }
        var satirlar: [(String, String, String?, String?)] = [("number", "Kovan no", k.num, nil), ("square.stack.3d.up", "Tip", k.type, nil), ("crown", "Ana arı", k.anaDurumMetni, nil)]
        if !k.arisiz {
            satirlar.append(("ladybug", "Irk", k.race, nil))
            satirlar.append(("point.3.connected.trianglepath.dotted", "Kuşak", k.generation.map { kusakDuzelt($0) }, nil))
            satirlar.append(("birthday.cake", "Ana yılı", k.year, k.anaNoktasiGoster ? k.queenColor : nil))
            satirlar.append(("rectangle.split.3x1", "Çerçeve", k.frames.map { "\(Int($0))" }, nil))
        }
        satirlar.append(("square.3.layers.3d", "Kat", "\(k.katSayisi)", nil))
        if let seri { satirlar.append(("flask", "Seri", seri.name, nil)) }
        if let c = k.createdAt, c.count >= 10 { satirlar.append(("calendar.badge.plus", "Kayıt", kisaTarih(String(c.prefix(10))), nil)) }
        return Kart(dolgu: 11) {
            BolumBasligi(simge: "info.circle", baslik: "Kovan Bilgileri", kucuk: true)
            VStack(spacing: 0) {
                ForEach(Array(satirlar.enumerated()), id: \.offset) { i, s in
                    HStack(spacing: 6) {
                        Image(systemName: s.0).font(.system(size: 12)).foregroundStyle(kartAltin).frame(width: 16)
                        Text(s.1).font(Yazi.nunito(12)).foregroundStyle(Renk.metin2).lineLimit(1)
                        Spacer(minLength: 2)
                        if let n = s.3 { AnaNoktasi(renk: n, boyut: 9) }
                        Text((s.2?.isEmpty == false ? s.2 : nil) ?? "—").font(Yazi.nunito(12, .bold)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(.vertical, 5)
                    if i < satirlar.count - 1 { Rectangle().fill(Renk.krem2).frame(height: 1) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .layoutPriority(1)
    }

    private func hizliDurum(_ k: Kovan, son: Muayene?, guc: Int?) -> some View {
        let gucAd = guc.map { $0 >= 4 ? "Güçlü" : $0 == 3 ? "Orta" : "Zayıf" } ?? ""
        let yavru = son?.brood.map { ["duzenli": "Düzenli", "seyrek": "Seyrek", "yok": "Yok"][$0] ?? $0 } ?? "—"
        return Kart(dolgu: 11) {
            BolumBasligi(simge: "gauge.with.dots.needle.33percent", baslik: "Hızlı Durum", kucuk: true)
            KoloniGostergesi(oran: Double(guc ?? 0) / 5).frame(height: 72).frame(maxWidth: .infinity)
            kutu("hexagon", "Güç", guc.map { "\($0)/5 · \(gucAd)" } ?? "—")
            kutu("oval.portrait", "Yavru", yavru)
            kutu("eye", "Ana görüldü", son?.queenSeen.map { $0 ? "Evet" : "Hayır" } ?? "—")
        }
        .frame(width: 140)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func kutu(_ simge: String, _ e: String, _ d: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: simge).font(.system(size: 13)).foregroundStyle(kartAltin)
            VStack(alignment: .leading, spacing: 0) {
                Text(e).font(Yazi.nunito(10)).foregroundStyle(Renk.metin2)
                Text(d).font(Yazi.nunito(13, .bold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Renk.kart, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Renk.krem2))
    }

    private func aktiviteler(_ liste: [Muayene]) -> some View {
        Kart {
            HStack {
                BolumBasligi(simge: "clock.arrow.circlepath", baslik: "Son Aktiviteler", kucuk: true)
                Spacer()
                Button { muayene = true } label: { Label("Kontrol", systemImage: "plus").font(Yazi.kucukOrta).foregroundStyle(Renk.orman2) }.buttonStyle(.plain)
            }
            if liste.isEmpty {
                Text("Henüz kontrol kaydı yok. Alttaki \"Kontrol ekle\" ile ilkini gir.").font(Yazi.kucuk).foregroundStyle(Renk.metin3)
            }
            ForEach(Array(liste.prefix(tumMuayeneler ? liste.count : 4)), id: \.id) { m in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "list.clipboard").font(.system(size: 14)).foregroundStyle(Renk.orman2)
                        .frame(width: 32, height: 32).background(Renk.orman2.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kisaTarih(m.date ?? "")).font(Yazi.kucukOrta)
                        Text(muayeneOzeti(m)).font(Yazi.kucuk).foregroundStyle(Renk.metin2)
                        if let n = m.note, !n.isEmpty { Text(n).font(Yazi.kucuk).foregroundStyle(Renk.metin3) }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 3)
                .contentShape(Rectangle())
                .contextMenu {
                    Button(role: .destructive) { depo.degistir { v in v.muayeneler = v.muayeneler.filter { $0.id != m.id } } } label: { Label("Sil", systemImage: "trash") }
                }
            }
            if liste.count > 4 {
                Button(tumMuayeneler ? "Daha az göster" : "Tümünü göster (\(liste.count))") { tumMuayeneler.toggle() }
                    .font(Yazi.kucukOrta).foregroundStyle(Renk.orman2)
            }
        }
    }

    private func eylemler(_ k: Kovan) -> some View {
        HStack(spacing: 8) {
            eylem("doc.badge.plus", "Kontrol ekle") { muayene = true }
            eylem("plus.square", "Kat ekle") { katDegistir(k, 1) }.disabled(k.katSayisi >= 4).opacity(k.katSayisi >= 4 ? 0.45 : 1)
            eylem("minus.square", "Kat çıkar") { katDegistir(k, -1) }.disabled(k.katSayisi <= 1).opacity(k.katSayisi <= 1 ? 0.45 : 1)
            eylem("pencil", "Düzenle") { duzenle = true }
        }
    }

    private func eylem(_ simge: String, _ ad: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            VStack(spacing: 6) {
                Image(systemName: simge).font(.system(size: 22, weight: .medium)).foregroundStyle(Renk.bal)
                Text(ad).font(Yazi.etiket).foregroundStyle(Renk.krem).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(Renk.ormanKoyu.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Renk.bal.opacity(0.5)))
        }
        .buttonStyle(.plain)
    }

    private func katDegistir(_ k: Kovan, _ d: Int) {
        depo.degistir { v in
            var l = v.kovanlar
            if let i = l.firstIndex(where: { $0.id == k.id }) { l[i].floors = Double(max(1, min(4, k.katSayisi + d))); v.kovanlar = l }
        }
    }
}

/// Yarım daire koloni gücü göstergesi (yeşilden sarıya geçişli).
struct KoloniGostergesi: View {
    let oran: Double
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let r = min(w / 2, h) - 6
            let merkez = CGPoint(x: w / 2, y: h - 2)
            ZStack {
                Path { p in p.addArc(center: merkez, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false) }
                    .stroke(Renk.krem2, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                Path { p in p.addArc(center: merkez, radius: r, startAngle: .degrees(180), endAngle: .degrees(180 + 180 * max(0, min(1, oran))), clockwise: false) }
                    .stroke(LinearGradient(colors: [Renk.iyi, Color(red: 0.55, green: 0.8, blue: 0.3), Renk.bal], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                VStack(spacing: 0) {
                    Text("%\(Int((oran * 100).rounded()))").font(Yazi.nunito(20, .bold))
                    Text("Koloni gücü").font(Yazi.nunito(9)).foregroundStyle(Renk.metin2)
                }
                .position(x: w / 2, y: h - 18)
            }
        }
    }
}

func muayeneOzeti(_ m: Muayene) -> String {
    var p: [String] = []
    if let q = m.queenSeen { p.append(q ? "Ana görüldü" : "Ana görülmedi") }
    if m.eggs == true { p.append("Yumurta var") }
    if let b = m.brood { p.append("Yavru: " + (["duzenli": "düzenli", "seyrek": "seyrek", "yok": "yok"][b] ?? b)) }
    if let s = m.strength, let g = Int(s) { p.append("Güç: \(g >= 4 ? "güçlü" : g == 3 ? "orta" : "zayıf")") }
    if let f = m.feeding, !f.isEmpty { p.append("Besleme: \(f)") }
    return p.joined(separator: " · ")
}

/// Muayene formu (v2.7.0 `inspections`). Güç kovanın 1–5 ölçeğiyle; kovanın gücünü de günceller.
struct MuayeneFormu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.dismiss) private var kapat
    let kovanId: String
    @State private var tarih = Date()
    @State private var anaGoruldu = true
    @State private var yumurta = true
    @State private var yavru = "duzenli"
    @State private var guc = 4
    @State private var besleme = ""
    @State private var not = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Tarih", selection: $tarih, displayedComponents: .date)
                Section("Ana arı") {
                    Toggle("Ana görüldü", isOn: $anaGoruldu)
                    Toggle("Yumurta / genç larva", isOn: $yumurta)
                }
                Section("Koloni") {
                    Picker("Yavru", selection: $yavru) {
                        Text("Düzenli").tag("duzenli"); Text("Seyrek").tag("seyrek"); Text("Yok").tag("yok")
                    }
                    .pickerStyle(.segmented)
                    Stepper("Güç: \(guc)/5 · \(guc >= 4 ? "güçlü" : guc == 3 ? "orta" : "zayıf")", value: $guc, in: 1...5)
                }
                Section("Besleme ve not") {
                    TextField("Besleme (ör. 1 lt şurup)", text: $besleme)
                    TextField("Not", text: $not, axis: .vertical)
                }
            }
            .navigationTitle("Muayene")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { kapat() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { kaydet(); kapat() } }
            }
        }
    }

    private func kaydet() {
        let g = String(guc)
        depo.degistir { v in
            var m = Muayene(["id": .metin(yeniKimlik())])
            m.hiveId = kovanId
            m.date = bugunISO(tarih)
            m.queenSeen = anaGoruldu
            m.eggs = yumurta
            m.brood = yavru
            m.strength = g
            m.feeding = besleme.isEmpty ? nil : besleme
            m.note = not.isEmpty ? nil : not
            v.muayeneler = v.muayeneler + [m]
            var l = v.kovanlar
            if let i = l.firstIndex(where: { $0.id == kovanId }) { l[i].strength = g; v.kovanlar = l }
        }
    }
}
