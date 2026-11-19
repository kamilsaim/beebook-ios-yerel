import AriCekirdek
import SwiftUI
import UserNotifications

/// Yerel hatırlatmalar (Android Hatirlatici karşılığı). iOS'ta arka plan işi saatinde çalışmadığı için
/// önümüzdeki günlerin bildirimleri gunlukHatirlatmalar kuralıyla önceden takvime kurulur; veri değişince
/// ve uygulama arka plana geçince yeniden kurulur. Tercihler cihaza özel (eşitlenmez).
@MainActor
enum Hatirlatici {
    private static let t = UserDefaults.standard
    private static let onek = "bb-hatirlatma-"
    /// iOS en fazla 64 bekleyen bildirim tutar.
    private static let gunSayisi = 14, enFazla = 60

    static var acik: Bool {
        get { t.object(forKey: "bb_bildirim_acik") as? Bool ?? true }
        set { t.set(newValue, forKey: "bb_bildirim_acik") }
    }
    static var turler: HatirlatmaTurleri {
        get {
            HatirlatmaTurleri(anaAri: t.object(forKey: "bb_bildirim_ana") as? Bool ?? true,
                              isler: t.object(forKey: "bb_bildirim_isler") as? Bool ?? true,
                              odeme: t.object(forKey: "bb_bildirim_odeme") as? Bool ?? true)
        }
        set {
            t.set(newValue.anaAri, forKey: "bb_bildirim_ana"); t.set(newValue.isler, forKey: "bb_bildirim_isler")
            t.set(newValue.odeme, forKey: "bb_bildirim_odeme")
        }
    }
    static var saat: Int {
        get { t.object(forKey: "bb_bildirim_saat") as? Int ?? 8 }
        set { t.set(newValue, forKey: "bb_bildirim_saat") }
    }
    static var izinSoruldu: Bool {
        get { t.bool(forKey: "bb_bildirim_izinSoruldu") }
        set { t.set(newValue, forKey: "bb_bildirim_izinSoruldu") }
    }

    static func izinDurumu() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    static func izinIste() async -> Bool {
        izinSoruldu = true
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    private static var takvim: Calendar { Calendar(identifier: .gregorian) }

    private static func iso(_ d: Date) -> String {
        let c = takvim.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Bekleyen hatırlatmaları sil, önümüzdeki günleri yeniden kur.
    static func planla(_ v: BBVeri) async {
        let m = UNUserNotificationCenter.current()
        let eski = await m.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(onek) }
        m.removePendingNotificationRequests(withIdentifiers: eski)
        guard acik, await izinDurumu() == .authorized else { return }
        let simdi = Date(), tr = turler, h = saat
        var sayi = 0
        for n in 0..<gunSayisi {
            guard let gun = takvim.date(byAdding: .day, value: n, to: simdi),
                  let an = takvim.date(bySettingHour: h, minute: 0, second: 0, of: gun), an > simdi else { continue }
            let pazartesi = takvim.component(.weekday, from: gun) == 2
            for x in gunlukHatirlatmalar(v, bugun: iso(gun), pazartesi: pazartesi, turler: tr) {
                guard sayi < enFazla else { return }
                let tetik = UNCalendarNotificationTrigger(dateMatching: takvim.dateComponents([.year, .month, .day, .hour, .minute], from: an), repeats: false)
                try? await m.add(UNNotificationRequest(identifier: "\(onek)\(iso(gun))-\(x.id)", content: icerik(x), trigger: tetik))
                sayi += 1
            }
        }
    }

    /// "Şimdi dene": bugünün hatırlatmalarını birkaç saniye sonra göster.
    static func simdiDene(_ v: BBVeri) async -> Int {
        let simdi = Date()
        let l = gunlukHatirlatmalar(v, bugun: iso(simdi), pazartesi: takvim.component(.weekday, from: simdi) == 2, turler: turler)
        for x in l {
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(
                identifier: "bb-dene-\(x.id)", content: icerik(x), trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)))
        }
        return l.count
    }

    private static func icerik(_ x: Hatirlatma) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = x.baslik
        c.body = x.metin
        c.sound = .default
        c.userInfo = ["hedef": x.hedef.rawValue]
        return c
    }
}

/// Bildirime dokununca ilgili sekme; uygulama açıkken de afiş göster.
final class BildirimTemsilcisi: NSObject, UNUserNotificationCenterDelegate {
    static let paylasilan = BildirimTemsilcisi()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let hedef = response.notification.request.content.userInfo["hedef"] as? String
        Task { @MainActor in
            switch hedef {
            case HatirlatmaHedefi.anaAri.rawValue: UygulamaYasami.paylasilan.kisayol = "b_anaari"
            case HatirlatmaHedefi.satis.rawValue: UygulamaYasami.paylasilan.kisayol = "b_satis"
            default: UygulamaYasami.paylasilan.kisayol = "b_ana"
            }
            completionHandler()
        }
    }
}

/// Ayarlar › Bildirimler (Android BildirimAyarlari ile aynı).
struct BildirimAyarlariBolumu: View {
    @Environment(VeriDeposu.self) private var depo
    @Environment(\.scenePhase) private var sahne
    @State private var acik = Hatirlatici.acik
    @State private var turler = Hatirlatici.turler
    @State private var saat = Hatirlatici.saat
    @State private var izin: UNAuthorizationStatus = .notDetermined
    @State private var mesaj: String?

    var body: some View {
        Section(header: Label("Bildirimler", systemImage: "bell.badge"),
                footer: Text("Her sabah seçtiğin saatte telefona hatırlatma gelir. İnternet gerekmez.")) {
            Toggle(isOn: $acik) { Label("Hatırlatmalar", systemImage: "bell").foregroundStyle(Renk.metin) }
            if acik && izin != .authorized {
                Button {
                    Task {
                        if izin == .notDetermined { await Hatirlatici.izinIste() }
                        else if let u = URL(string: UIApplication.openNotificationSettingsURLString) { await UIApplication.shared.open(u) }
                        await tazele()
                        kaydet()
                    }
                } label: { Label("Bildirim izni kapalı, dokun izin ver", systemImage: "bell.slash").foregroundStyle(Renk.kotu) }
            }
            if acik {
                Toggle(isOn: $turler.anaAri) { etiket("Ana arı takvimi", "Kapanma, Pupa, Dağıtım (G+10), Çıkım (G+12)", "crown") }
                Toggle(isOn: $turler.isler) { etiket("Günün işleri", "Bugün tarihli ve geciken işler", "checklist") }
                Toggle(isOn: $turler.odeme) { etiket("Bekleyen ödemeler", "Her pazartesi özet (ön siparişler hariç)", "turkishlirasign.circle") }
                Picker(selection: $saat) {
                    ForEach([6, 7, 8, 9, 10, 12, 18, 20], id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                } label: { Label("Bildirim saati", systemImage: "clock").foregroundStyle(Renk.metin) }
                Button {
                    Task {
                        let n = await Hatirlatici.simdiDene(depo.veri)
                        mesaj = izin != .authorized ? "Önce bildirim iznini aç" : (n == 0 ? "Bugün hatırlatılacak bir şey yok" : "\(n) bildirim gönderildi")
                    }
                } label: { etiket("Şimdi dene", mesaj ?? "Bugünün hatırlatmalarını hemen gönder", "paperplane") }
            }
        }
        .tint(Renk.orman2)
        .task { await tazele() }
        .onChange(of: sahne) { _, s in if s == .active { Task { await tazele() } } }
        .onChange(of: acik) { _, _ in kaydet() }
        .onChange(of: turler) { _, _ in kaydet() }
        .onChange(of: saat) { _, _ in kaydet() }
    }

    private func etiket(_ b: String, _ a: String, _ s: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(b).foregroundStyle(Renk.metin)
                Text(a).font(Yazi.minik).foregroundStyle(Renk.metin2)
            }
        } icon: { Image(systemName: s) }
    }

    private func tazele() async { izin = await Hatirlatici.izinDurumu() }

    private func kaydet() {
        Hatirlatici.acik = acik; Hatirlatici.turler = turler; Hatirlatici.saat = saat
        let v = depo.veri
        Task { await Hatirlatici.planla(v) }
    }
}
