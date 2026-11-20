import AriCekirdek
import Supabase
import SwiftUI

// Android `ViziltiKilavuz.kt` + `ViziltiOneri.kt` ile aynı içerik.

private let ornekler: [(String, String)] = [
    ("3 numaralı kovan bakım. 5 çerçeve, ana görüldü, yumurta var, durumu güçlü.", "Muayene"),
    ("7 numaralı kovan. Ana görülmedi, yavru seyrek, zayıf. Bir litre şurup verdim. Üç gün sonra bakacağım.", "Muayene + besleme + hatırlatma"),
    ("4 numaralı kovan amitraz şerit taktım, 12 akar düştü.", "Varroa"),
    ("12 numaralı kovandan 10 çerçeve bal aldım.", "Bal sağımı"),
    ("5 nolu kovandan dört kilo bal aldım.", "Bal sağımı (kg ile)"),
]

/// Vızvız'lı yeşil kahraman kutusu.
private struct ViziltiKahraman: View {
    let baslik: String
    let metin: String
    var body: some View {
        HStack(spacing: 12) {
            Vizilti(cirpiyor: true).frame(width: 66, height: 92)
            VStack(alignment: .leading, spacing: 4) {
                Text(baslik).font(Yazi.nunito(19, .heavy)).foregroundStyle(Renk.acikBal)
                Text(metin).font(Yazi.kucuk).foregroundStyle(Renk.krem.opacity(0.9))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Renk.orman2, Renk.orman], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Renk.bal.opacity(0.6)))
    }
}

private struct Adim: View {
    let no: Int?
    let baslik: String
    let aciklama: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(no.map(String.init) ?? "•").font(Yazi.kucukOrta).foregroundStyle(Renk.ormanKoyu)
                .frame(width: 26, height: 26).background(no != nil ? Renk.bal : Renk.bal.opacity(0.25), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(baslik).font(Yazi.govdeOrta).foregroundStyle(Renk.metin)
                Text(aciklama).font(Yazi.kucuk).foregroundStyle(Renk.metin2)
            }
        }
    }
}

private struct Anlarim: View {
    let alan: String
    let ornek: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(alan).font(Yazi.kucukOrta).foregroundStyle(Renk.orman).frame(width: 84, alignment: .leading)
            Text(ornek).font(Yazi.kucuk).foregroundStyle(Renk.metin2)
        }
    }
}

/// Vızvız kullanım kılavuzu: Daha kartı, Ayarlar › Vızvız, dinleme paneli.
struct ViziltiKilavuzu: View {
    @Environment(\.dismiss) private var kapat
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ViziltiKahraman(baslik: "Eller dolu mu?", metin: "Kovan başında eldivenle yazmak zor. Bana söyle, ben formu doldurayım; sen bir bakıp kaydet.")
                }
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                Section("Nasıl çalışır") {
                    Adim(no: 1, baslik: "Ekranın kenarındaki Vızvız'a dokun", aciklama: "\"Bana emret\" yazan arı. Mikrofon iznini ilk seferde sorar.")
                    Adim(no: 2, baslik: "Kovan numarasıyla başlayıp konuş", aciklama: "\"3 numaralı kovan…\" de, sonra gördüklerini sırayla söyle. Bitince \"Bitir\"e bas ya da sus.")
                    Adim(no: 3, baslik: "Formu kontrol et", aciklama: "Anladıklarım dolu gelir. Anlamadığım alan boş (—) kalır, tahmin yazmam. Yanlışı düzelt.")
                    Adim(no: 4, baslik: "Kaydet", aciklama: "Alttaki büyük Kaydet'e bas. Kovanın çerçeve sayısı ve katı da güncellenir; \"3 gün sonra bak\" dediysen işlere eklenir.")
                }
                Section {
                    ForEach(ornekler, id: \.0) { cumle, tur in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tur).font(Yazi.minik).foregroundStyle(Renk.orman2)
                                Text("“\(cumle)”").font(Yazi.govde).foregroundStyle(Renk.metin)
                            }
                            Spacer(minLength: 0)
                            Button {
                                kapat()
                                ViziltiAyari.paylasilan.deneme = cumle
                            } label: {
                                Text("Dene").font(Yazi.kucukOrta).foregroundStyle(Renk.ormanKoyu)
                                    .padding(.horizontal, 12).padding(.vertical, 6).background(Renk.bal, in: Capsule())
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } header: { Text("Örnek cümleler") } footer: { Text("\"Dene\"ye basınca cümle bana söylenmiş gibi işlenir; formu kaydetmezsen hiçbir şey değişmez.") }
                Section("Neleri anlarım") {
                    Anlarim(alan: "Kovan", ornek: "\"3 numaralı\", \"üç nolu\", \"kovan 3\". Kovan detayındaysan numarasız da olur.")
                    Anlarim(alan: "Ana arı", ornek: "\"ana görüldü / görülmedi\", \"ana yok\" (nota yazılır; kovan durumunu kendim değiştirmem)")
                    Anlarim(alan: "Yumurta", ornek: "\"yumurta var / yok\", \"larva var\"")
                    Anlarim(alan: "Açık / kapalı yavru", ornek: "\"açık yavru var\", \"kapalı yavru yok\", \"açık ve kapalı yavru var\"")
                    Anlarim(alan: "Yavru", ornek: "\"yavru düzenli\", \"yavru seyrek / dağınık\", \"yavru yok\"")
                    Anlarim(alan: "Güç", ornek: "\"çok güçlü\", \"güçlü\", \"orta\", \"zayıf\", \"çok zayıf\"")
                    Anlarim(alan: "Çerçeve", ornek: "\"8 çerçeve\" → kovanın çerçeve sayısı; kat kendiliğinden ayarlanır (≤10 → 1, 11–20 → 2, 21+ → 3)")
                    Anlarim(alan: "Besleme", ornek: "\"bir litre şurup verdim\", \"yarım kilo kek\", \"polen verdim\"")
                    Anlarim(alan: "Varroa", ornek: "\"şerit taktım / şeridi çıkardım\", \"oksalik asit damlattım\", \"12 akar düştü\", \"varroa yok\". Şerit takınca 6 hafta sonrasına \"şeridi çıkar\" işi eklenir.")
                    Anlarim(alan: "Hatırlatma", ornek: "\"üç gün sonra bakacağım\", \"haftaya\", \"yarın\", \"iki hafta sonra\"")
                    Anlarim(alan: "Bal sağımı", ornek: "\"10 çerçeve bal aldım\" → çerçeve × kg tahmini (Ayarlar › Vızvız), \"4 kilo bal aldım\". Stoğa girer, kovanın çerçevesi düşer.")
                    Anlarim(alan: "Not", ornek: "Anlamadığım her şey (\"kapakta rutubet var\") nota yazılır.")
                }
                Section("Taşıma ve gizleme") {
                    Adim(no: nil, baslik: "Taşı", aciklama: "Vızvız'ı sürükle; bırakınca en yakın kenara yapışır, yerini hatırlarım.")
                    Adim(no: nil, baslik: "Gizle", aciklama: "Basılı tut → \"Vızvız'ı gizle\". Ana sayfadaki simgelerin en soluna geçerim; oradan basılı tutunca ya da Ayarlar › Vızvız'dan geri gelirim.")
                }
                Section("İpuçları") {
                    Adim(no: nil, baslik: "Kısa ve sırayla", aciklama: "Önce kovan numarası, sonra gördüklerin. Uzun duraklarsan dinlemeyi bitiririm.")
                    Adim(no: nil, baslik: "Rüzgârda", aciklama: "Telefonu ağzına yakın tut ya da kulaklık mikrofonu kullan.")
                    Adim(no: nil, baslik: "Çalışmazsa", aciklama: "\"Yaz\"a basıp aynı cümleyi yazabilirsin.")
                }
            }
            .navigationTitle("Vızvız nasıl kullanılır")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Kapat") { kapat() } } }
        }
    }
}

/// Daha sayfasındaki geniş "Vızvız nasıl kullanılır" kartı.
struct ViziltiKilavuzKarti: View {
    @State private var ac = false
    var body: some View {
        Button { ac = true } label: {
            HStack(spacing: 12) {
                Vizilti(cirpiyor: false).frame(width: 48, height: 66)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Vızvız nasıl kullanılır").font(Yazi.govdeOrta).foregroundStyle(Renk.acikBal)
                    Text("Sesle muayene ve bal sağımı kaydı, örnek cümleler").font(Yazi.kucuk).foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
                Text("›").font(Yazi.nunito(24, .bold)).foregroundStyle(Renk.acikBal)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(LinearGradient(colors: [Renk.orman2.opacity(0.92), Renk.ormanKoyu.opacity(0.92)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Renk.bal.opacity(0.6)))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $ac) { ViziltiKilavuzu() }
    }
}

// MARK: - Öneriler (Supabase `beebook_vizilti_oneri`)

/// Kimliksiz: yalnız rastgele kurulum kodu. Uygulamada 24 saatte bir, en çok 5 cümle; sunucu tetikleyicisi de sınırlar.
/// Okuma/işaretleme/silme yalnız `beebook_yonetici` hesapları (RLS + `beebook_yonetici_mi()`).
enum ViziltiOneri {
    static let enCok = 5
    private static let t = UserDefaults.standard

    static var cihaz: String {
        if let c = t.string(forKey: "bb_vizilti_cihaz") { return c }
        let c = UUID().uuidString.lowercased(); t.set(c, forKey: "bb_vizilti_cihaz"); return c
    }
    /// Bir sonraki gönderime kalan süre (sn); 0 → gönderilebilir.
    static var bekleme: Double { max(0, t.double(forKey: "bb_vizilti_sonGonderim") + 86_400 - Date().timeIntervalSince1970) }

    private struct Satir: Encodable, Sendable {
        let cihaz: String; let metin: String; let kalan: String?; let surum: String; let platform: String; let zaman: String
    }

    struct Oneri: Decodable, Identifiable, Sendable {
        let id: Int
        let created_at: String?
        let metin: String
        let kalan: String?
        let surum: String?
        let platform: String?
        let islendi: Bool
    }

    /// Gönderilen cümle sayısı; hata mesajıyla atar.
    @MainActor static func gonder(_ liste: [Anlamadigi]) async throws -> Int {
        if bekleme > 0 { throw OneriHatasi("Bugün gönderdin; yarın tekrar gönderebilirsin.") }
        let secilen = Array(liste.suffix(enCok))
        let surum = String((Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "").prefix(20))
        let iso = ISO8601DateFormatter()
        let satirlar = secilen.map { a in
            Satir(cihaz: cihaz, metin: String(a.metin.prefix(300)), kalan: a.kalan.map { String($0.prefix(300)) }, surum: surum, platform: "ios",
                  zaman: iso.string(from: Date(timeIntervalSince1970: a.zaman / 1000)))
        }
        do {
            try await supabase.from("beebook_vizilti_oneri").insert(satirlar, returning: .minimal).execute()
        } catch {
            if "\(error)".contains("beebook_oneri_sinir") { throw OneriHatasi("Bugünlük gönderim sınırı doldu; yarın tekrar dene.") }
            throw OneriHatasi("Gönderilemedi (internet?). Sonra tekrar dene.")
        }
        t.set(Date().timeIntervalSince1970, forKey: "bb_vizilti_sonGonderim")
        ViziltiAyari.paylasilan.anlamadiklariCikar(secilen)
        return secilen.count
    }

    static func yoneticiMi() async -> Bool {
        do {
            let r: PostgrestResponse<Bool> = try await supabase.rpc("beebook_yonetici_mi").execute()
            return r.value
        } catch { return false }
    }

    static func listele(islenenler: Bool) async throws -> [Oneri] {
        try await supabase.from("beebook_vizilti_oneri").select()
            .eq("islendi", value: islenenler).order("created_at", ascending: false).limit(300).execute().value
    }

    static func isaretle(_ id: Int, _ islendi: Bool) async {
        _ = try? await supabase.from("beebook_vizilti_oneri").update(["islendi": islendi]).eq("id", value: id).execute()
    }

    static func sil(_ id: Int) async {
        _ = try? await supabase.from("beebook_vizilti_oneri").delete().eq("id", value: id).execute()
    }
}

struct OneriHatasi: LocalizedError {
    let mesaj: String
    init(_ m: String) { mesaj = m }
    var errorDescription: String? { mesaj }
}

/// Ayarlar › Vızvız › Anlamadıklarım: tek dokunuşla gönder (günde bir kez, en çok 5). Kendiliğinden gitmez.
struct ViziltiAnlamadiklari: View {
    @Environment(\.dismiss) private var kapat
    private var ayar: ViziltiAyari { .paylasilan }
    @State private var durum: String?
    @State private var gonderiyor = false
    @State private var bekleme = ViziltiOneri.bekleme

    var body: some View {
        let liste = Array(ayar.anlamadiklari.reversed())
        NavigationStack {
            Form {
                Section {
                    ViziltiKahraman(baslik: "Bunları henüz anlamıyorum", metin: "Anlamadığım cümleler bu telefonda durur. \"Gönder\"e basarsan geliştiriciye gider (adın, hesabın gitmez); sonraki sürümde bunları da öğrenirim. Günde bir kez, en çok \(ViziltiOneri.enCok) cümle.")
                }
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                if let durum { Text(durum).font(Yazi.govdeOrta).foregroundStyle(Renk.orman2) }
                if bekleme > 0 && !liste.isEmpty { Text("Bugün gönderdin; yarın yine gönderebilirsin.").font(Yazi.kucuk).foregroundStyle(Renk.metin3) }
                if liste.isEmpty {
                    Text("Henüz yok. Vızvız'ın anlamadığı ya da nota yazdığı cümleler burada birikir.").font(Yazi.govde).foregroundStyle(Renk.metin2)
                } else {
                    Section("Cümleler (\(liste.count))") {
                        ForEach(liste, id: \.self) { a in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("“\(a.metin)”").font(Yazi.govde).foregroundStyle(Renk.metin)
                                Text(tarih(a.zaman) + (a.kalan.map { " · anlamadığım: \($0)" } ?? " · hiç anlamadım")).font(Yazi.minik).foregroundStyle(Renk.metin3)
                            }
                        }
                    }
                    Section { Button("Listeyi temizle", role: .destructive) { ayar.anlamadiklariSil() } }
                }
            }
            .navigationTitle("Anlamadıklarım")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Kapat") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(gonderiyor ? "Gönderiliyor…" : "Gönder") {
                        gonderiyor = true
                        Task {
                            do {
                                let n = try await ViziltiOneri.gonder(Array(liste.reversed()))
                                durum = "Teşekkürler! \(n) cümle gönderildi, Vızvız bunları öğrenecek."
                            } catch { durum = error.localizedDescription }
                            bekleme = ViziltiOneri.bekleme
                            gonderiyor = false
                        }
                    }
                    .disabled(liste.isEmpty || bekleme > 0 || gonderiyor)
                }
            }
        }
    }

    private func tarih(_ ms: Double) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "tr_TR"); f.dateFormat = "d MMM HH:mm"
        return f.string(from: Date(timeIntervalSince1970: ms / 1000))
    }
}

/// Ayarlar › Vızvız › Gelen öneriler (yalnız yönetici).
struct ViziltiOneriler: View {
    @Environment(\.dismiss) private var kapat
    @State private var islenen = false
    @State private var liste: [ViziltiOneri.Oneri]?
    @State private var hata: String?
    @State private var yenile = 0

    var body: some View {
        NavigationStack {
            Form {
                Picker("", selection: $islenen) { Text("Yeni").tag(false); Text("İşlenenler").tag(true) }.pickerStyle(.segmented)
                if let hata { Text(hata).foregroundStyle(Renk.kotu) }
                else if let l = liste {
                    if l.isEmpty { Text(islenen ? "İşlenmiş öneri yok." : "Yeni öneri yok.").foregroundStyle(Renk.metin2) }
                    else {
                        Section {
                            ForEach(l) { o in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("“\(o.metin)”").font(Yazi.govde).foregroundStyle(Renk.metin)
                                    Text([o.created_at.map { String($0.prefix(10)) }, o.platform, o.surum, o.kalan.map { "anlamadığı: \($0)" } ?? "hiç anlamadı"].compactMap { $0 }.joined(separator: " · "))
                                        .font(Yazi.minik).foregroundStyle(Renk.metin3)
                                    HStack(spacing: 8) {
                                        Button(o.islendi ? "Yeniye al" : "İşlendi ✓") { Task { await ViziltiOneri.isaretle(o.id, !o.islendi); yenile += 1 } }
                                            .font(Yazi.kucukOrta).buttonStyle(.bordered).tint(Renk.orman2)
                                        Button("Sil", role: .destructive) { Task { await ViziltiOneri.sil(o.id); yenile += 1 } }
                                            .font(Yazi.kucukOrta).buttonStyle(.bordered)
                                    }
                                }
                            }
                        } header: { Text("\(l.count) cümle") } footer: { Text("Kural ekledikten sonra \"İşlendi\" de; sil kalıcı siler.") }
                    }
                } else { ProgressView() }
            }
            .navigationTitle("Vızvız önerileri")
            .formArkaplani()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Kapat") { kapat() } } }
            .task(id: "\(islenen)-\(yenile)") {
                liste = nil; hata = nil
                do { liste = try await ViziltiOneri.listele(islenenler: islenen) } catch { hata = "Yüklenemedi: \(error.localizedDescription)" }
            }
        }
    }
}
