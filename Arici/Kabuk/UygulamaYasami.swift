import SwiftUI
import UIKit
import UserNotifications

/// Uygulama yaşam döngüsü yardımcıları (Android UygulamaYasami ile aynı): ana ekran kısayolları,
/// App Store'da yeni sürüm bandı, "güncellendi" notu ve uygulama içi puanlama zamanlaması.
@MainActor @Observable
final class UygulamaYasami {
    static let paylasilan = UygulamaYasami()
    static let appStoreKimligi = "6823056758"

    /// Ana ekran kısayolu: "satis" | "kovan" (AnaKabuk formu açar ve temizler).
    var kisayol: String?
    /// App Store'daki daha yeni sürüm (varsa).
    var magazaSurumu: String?
    /// Uygulama yeni sürüme güncellendiyse bir kez gösterilecek sürüm.
    var guncellendiSurum: String?

    private let tercih = UserDefaults.standard
    private var kontrolEdildi = false

    var surum: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }
    private var derleme: Int { Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0 }

    func kisayolIsle(_ k: UIApplicationShortcutItem) {
        if k.type.hasSuffix(".satis") { kisayol = "satis" } else if k.type.hasSuffix(".kovan") { kisayol = "kovan" }
    }

    /// Derleme numarası öncekinden büyükse (ilk kurulum hariç) notu açar.
    func surumKontrol() {
        let onceki = tercih.integer(forKey: "bb_derleme")
        if onceki > 0, derleme > onceki { guncellendiSurum = surum }
        if onceki != derleme { tercih.set(derleme, forKey: "bb_derleme") }
    }

    /// App Store'da yayındaki sürümü sorar; bizimkinden yeniyse bandı açar.
    func guncellemeKontrol() async {
        guard !kontrolEdildi else { return }
        kontrolEdildi = true
        guard let bundle = Bundle.main.bundleIdentifier,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundle)&country=tr") else { return }
        guard let (veri, _) = try? await URLSession.shared.data(from: url),
              let j = try? JSONSerialization.jsonObject(with: veri) as? [String: Any],
              let sonuc = (j["results"] as? [[String: Any]])?.first,
              let magaza = sonuc["version"] as? String else { return }
        if magaza.compare(surum, options: .numeric) == .orderedDescending { magazaSurumu = magaza }
    }

    func magazayiAc(yorum: Bool = false) {
        let ek = yorum ? "?action=write-review" : ""
        if let u = URL(string: "https://apps.apple.com/app/id\(Self.appStoreKimligi)\(ek)") { UIApplication.shared.open(u) }
    }

    /// Açılış sayacı; 6+ açılış, ilk açılıştan 5+ gün, 5+ kayıt ve son istekten 90+ gün geçtiyse true
    /// (iOS ayrıca yılda en fazla 3 kez gösterir).
    func puanlamaUygun(kayitSayisi: Int) -> Bool {
        let simdi = Date().timeIntervalSince1970
        var ilk = tercih.double(forKey: "bb_ilkAcilis")
        if ilk == 0 { ilk = simdi; tercih.set(ilk, forKey: "bb_ilkAcilis") }
        let acilis = tercih.integer(forKey: "bb_acilis") + 1
        tercih.set(acilis, forKey: "bb_acilis")
        let son = tercih.double(forKey: "bb_sonPuanIstegi")
        let gun: Double = 86_400
        guard acilis >= 6, simdi - ilk >= 5 * gun, simdi - son >= 90 * gun, kayitSayisi >= 5 else { return false }
        tercih.set(simdi, forKey: "bb_sonPuanIstegi")
        return true
    }
}

/// Ana ekran kısayolları (Info.plist UIApplicationShortcutItems): uygulama kapalıyken ve açıkken.
final class UygulamaTemsilcisi: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Telefon bildirimine dokunma → ilgili sekme (uygulama kapalıyken de)
        UNUserNotificationCenter.current().delegate = BildirimTemsilcisi.paylasilan
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let k = options.shortcutItem { UygulamaYasami.paylasilan.kisayolIsle(k) }
        let c = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        c.delegateClass = SahneTemsilcisi.self
        return c
    }
}

final class SahneTemsilcisi: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        UygulamaYasami.paylasilan.kisayolIsle(shortcutItem)
        completionHandler(true)
    }
}

/// App Store'da yeni sürüm varsa ana sayfada bant.
struct GuncellemeBandi: View {
    private var yasam: UygulamaYasami { .paylasilan }
    var body: some View {
        if let v = yasam.magazaSurumu {
            HStack(spacing: 10) {
                Image(systemName: "icloud.and.arrow.down").font(.system(size: 17, weight: .semibold)).foregroundStyle(Renk.acikBal)
                    .frame(width: 34, height: 34).background(Renk.bal.opacity(0.25), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("Yeni sürüm var (\(v))").font(Yazi.govdeOrta).foregroundStyle(.white)
                    Text("BeeBook'un yeni sürümü App Store'da").font(Yazi.minik).foregroundStyle(Color(white: 0.85))
                }
                Spacer(minLength: 4)
                Button { yasam.magazayiAc() } label: {
                    Text("Güncelle").font(Yazi.nunito(13, .bold)).foregroundStyle(Renk.ormanKoyu)
                        .padding(.horizontal, 14).padding(.vertical, 8).background(Renk.bal, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(LinearGradient(colors: [Renk.orman2, Renk.orman], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Renk.bal.opacity(0.7)))
        }
    }
}
