import AriCekirdek
import Foundation
import Observation
import Supabase

/// Uygulamanın tek veri kaynağı. Offline-first: her değişiklik önce önbelleğe yazılır,
/// 2 sn sonra web'deki gibi read-merge-write ile `user_data` satırına gönderilir.
@Observable @MainActor
final class VeriDeposu {
    private(set) var durum = DepoDurumu()
    private(set) var esitleniyor = false
    private(set) var sonHata: String?
    /// Giriş yapılmamış (hesapsız) kullanım: gönderim yok.
    var kullaniciId: String? { didSet { if kullaniciId != oldValue { Task { await yukle() } } } }
    /// Simülatör/inceleme örnek verisi — asla gönderilmez.
    private(set) var ornekKipi = false
    /// Hesapsız kullanım: eşitleme yok; ilk sezon yerelde oluşturulur.
    var hesapsiz = false {
        didSet {
            guard hesapsiz, !ornekKipi else { return }
            durum.sezonYoksaOlustur(buYil: Calendar.current.component(.year, from: Date()), simdi: Self.simdiMs)
            Onbellek.yaz(durum)
        }
    }
    @ObservationIgnored private var tekrarGerekli = false

    @ObservationIgnored private var gonderimGorevi: Task<Void, Never>?

    var veri: BBVeri { durum.veri }
    var ayarlar: Ayarlar { durum.ayarlar }

    init() {
        if Baslatma.ornekVeri {
            ornekKipi = true
            durum = OrnekVeri.durum()
        } else if let d = Onbellek.oku() {
            durum = d
        }
    }

    static var simdiMs: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    // MARK: Değişiklik

    func degistir(_ f: (inout BBVeri) -> Void) {
        durum.degistir(simdi: Self.simdiMs, f)
        kaydetVePlanla()
    }

    func ayarDegistir(_ f: (inout Ayarlar) -> Void) {
        durum.ayarDegistir(simdi: Self.simdiMs, f)
        kaydetVePlanla()
    }

    /// Yedekten içe aktarma vb. tüm veriyi değiştirme (değişiklikler damgalanır).
    func tumunuDegistir(veri yeni: BBVeri, ayarlar yeniAyar: Ayarlar?) {
        durum.degistir(simdi: Self.simdiMs) { v in
            for c in BBVeri.esitlenenler { v.koleksiyonYaz(c, yeni.koleksiyon(c)) }
            if let lay = yeni.araziLayout { v.araziLayout = lay }
        }
        if let yeniAyar { durum.ayarDegistir(simdi: Self.simdiMs) { $0 = Ayarlar(ham: yeniAyar.ham) } }
        kaydetVePlanla()
    }

    private func kaydetVePlanla() {
        guard !ornekKipi else { return }
        Onbellek.yaz(durum)
        gonderimGorevi?.cancel()
        gonderimGorevi = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await self?.esitle()
        }
    }

    /// Bekleyen değişikliği hemen gönder (arka plana geçerken).
    func simdiGonder() async {
        gonderimGorevi?.cancel()
        if durum.bekleyen { await esitle() }
    }

    // MARK: Eşitleme

    private struct Satir: Decodable {
        let data: BBVeri?
        let settings: Ayarlar?
    }

    private struct Yazim: Encodable {
        let user_id: String
        let data: BBVeri
        let settings: Ayarlar
        let updated_at: String
    }

    /// Uzağı çek → birleştir → gerekiyorsa gönder (web syncToSupabase/syncFromSupabase).
    func yukle() async { await esitle(zorlaGonder: false) }

    private func esitle(zorlaGonder: Bool = true) async {
        guard !ornekKipi, let uid = kullaniciId else { return }
        // Gönderim sürüyorsa bırakma: bitince yeniden dene (değişiklik kaybolmasın).
        guard !esitleniyor else { tekrarGerekli = true; return }
        esitleniyor = true
        defer { esitleniyor = false }
        do {
            let satirlar: [Satir] = try await supabase.from("user_data")
                .select("data, settings").eq("user_id", value: uid).limit(1).execute().value
            let uzak = satirlar.first
            let uzakVeriVar = !(uzak?.data?.ham.isEmpty ?? true)
            if durum.veri.demo || uzakVeriVar {
                durum.uzakIleBirlestir(uzak?.data, uzak?.settings)
            }
            durum.sezonYoksaOlustur(buYil: Calendar.current.component(.year, from: Date()), simdi: Self.simdiMs)
            Onbellek.yaz(durum)
            if durum.bekleyen || (zorlaGonder && !uzakVeriVar) {
                let simdi = ISO8601DateFormatter().string(from: Date())
                let sayac = durum.degisiklikSayaci
                let yazim = Yazim(user_id: uid, data: durum.veri, settings: durum.ayarlar, updated_at: simdi)
                try await supabase.from("user_data").upsert(yazim, onConflict: "user_id").execute()
                durum.gonderildi(sayac: sayac)
                Onbellek.yaz(durum)
            }
            sonHata = nil
        } catch is CancellationError {
        } catch {
            sonHata = error.localizedDescription
        }
        if tekrarGerekli {
            tekrarGerekli = false
            if durum.bekleyen { Task { await esitle() } }
        }
    }

    /// Çıkış / hesap silme: yerel veriyi temizle.
    func temizle() {
        gonderimGorevi?.cancel()
        durum = DepoDurumu()
        Onbellek.sil()
    }
}

/// Son durum `Application Support/beebook-durum.json` (bekleyen bayrağıyla).
enum Onbellek {
    private static var url: URL {
        let k = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: k, withIntermediateDirectories: true)
        return k.appendingPathComponent("beebook-durum.json")
    }
    static func oku() -> DepoDurumu? { (try? Data(contentsOf: url)).flatMap { try? DepoDurumu.coz($0) } }
    static func yaz(_ d: DepoDurumu) { if let v = try? d.kodla() { try? v.write(to: url, options: .atomic) } }
    static func sil() { try? FileManager.default.removeItem(at: url) }
}
