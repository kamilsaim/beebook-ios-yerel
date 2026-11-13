import AuthenticationServices
import CryptoKit
import Foundation
import GoogleSignIn
import Observation
import Supabase
import UIKit

enum OturumDurumu: Equatable {
    case yukleniyor, girissiz, girisli
    /// Web "İnternetsiz Kullan" karşılığı: veri yalnız cihazda, eşitleme yok.
    case hesapsiz
}

enum OturumHatasi: LocalizedError {
    case appleBilgisiEksik
    var errorDescription: String? { "Apple'dan giriş bilgisi alınamadı. Tekrar dene." }
}

/// Oturum (Apple / Google). Web Beebook ile aynı Supabase hesabı (KSapp ortak girişi).
@Observable @MainActor
final class OturumYoneticisi {
    private(set) var kullanici: User?
    private(set) var durum: OturumDurumu = .yukleniyor
    /// İlk oturum olayı geldi mi (Türbedar dersi: kısayol/derin bağlantı bundan önce işlenmez).
    private(set) var hazir = false

    @ObservationIgnored private var appleNonce: String?
    @ObservationIgnored private var dinleniyor = false
    /// Oturum kapanınca (çıkış/silme) çağrılır — veri ve widget temizliği.
    @ObservationIgnored var cikistaTemizle: (() -> Void)?
    /// Çıkıştan önce bekleyen değişiklikleri gönder (gönderilmemiş veri silinmesin).
    @ObservationIgnored var cikmadanOnce: (() async -> Void)?

    var kullaniciId: String? { kullanici?.id.uuidString.lowercased() }

    var adSoyad: String {
        for anahtar in ["full_name", "name"] {
            if case let .string(s)? = kullanici?.userMetadata[anahtar], !s.isEmpty { return s }
        }
        return "—"
    }

    /// Apple "E-postamı gizle" adresi kullanıcıya anlamsız görünür.
    var epostaGorunen: String {
        guard let e = kullanici?.email, !e.isEmpty else { return "—" }
        return e.lowercased().hasSuffix("@privaterelay.appleid.com") ? "Gizli (Apple ile giriş)" : e
    }

    func baslat() async {
        guard !dinleniyor else { return }
        dinleniyor = true
        for await (_, oturum) in supabase.auth.authStateChanges {
            let yeni = oturum?.user
            if yeni?.id != kullanici?.id, kullanici != nil { cikistaTemizle?() }
            kullanici = yeni
            if yeni != nil { UserDefaults.standard.set(false, forKey: Self.hesapsizAnahtar) }
            durum = yeni == nil ? (UserDefaults.standard.bool(forKey: Self.hesapsizAnahtar) ? .hesapsiz : .girissiz) : .girisli
            hazir = true
        }
    }

    // MARK: Hesapsız kullanım

    static let hesapsizAnahtar = "bb_hesapsiz"

    func hesapsizDevam() {
        UserDefaults.standard.set(true, forKey: Self.hesapsizAnahtar)
        durum = .hesapsiz
        hazir = true
    }

    /// Hesapsız kipten giriş ekranına dön (veri cihazda kalır; giriş yapılınca hesaba eşitlenir).
    func girisEkraninaDon() {
        UserDefaults.standard.set(false, forKey: Self.hesapsizAnahtar)
        durum = .girissiz
    }

    // MARK: Apple ile giriş (yerel pencere)

    func appleIstegiHazirla(_ istek: ASAuthorizationAppleIDRequest) {
        let nonce = Self.rastgeleNonce()
        appleNonce = nonce
        istek.requestedScopes = [.fullName, .email]
        istek.nonce = Self.sha256(nonce)
    }

    func appleSonucu(_ sonuc: Result<ASAuthorization, Error>) async throws {
        switch sonuc {
        case .failure(let hata):
            if (hata as? ASAuthorizationError)?.code == .canceled { return }
            throw hata
        case .success(let yetki):
            guard let k = yetki.credential as? ASAuthorizationAppleIDCredential,
                  let jetonVerisi = k.identityToken,
                  let jeton = String(data: jetonVerisi, encoding: .utf8),
                  let nonce = appleNonce
            else { throw OturumHatasi.appleBilgisiEksik }
            try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: jeton, nonce: nonce))
            // Apple adı yalnız ilk girişte verir — hesaba yaz (Ayarlar'da görünür).
            let parcalar = [k.fullName?.givenName, k.fullName?.familyName].compactMap { $0 }
            let ad = parcalar.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !ad.isEmpty {
                _ = try? await supabase.auth.update(user: UserAttributes(data: ["full_name": .string(ad)]))
            }
        }
    }

    // MARK: Google ile giriş

    /// Yerel Google girişi (sistem hesap penceresi): GoogleSignIn → ID token → Supabase.
    /// Info.plist `GIDClientID` boşsa ya da yerel giriş iptal dışında hata verirse eski tarayıcı akışına düşer.
    /// Rehber: C:\mac\GOOGLE-YEREL-GIRIS-REHBERI.md
    func googleIleGir() async throws {
        let istemci = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? ""
        guard !istemci.isEmpty, let ust = Self.enUstDenetleyici() else { return try await googleTarayici() }
        do {
            // Google'a nonce'un SHA-256'sı, Supabase'e ham hali gider (GoogleSignIn 9+).
            let ham = Self.rastgeleNonce()
            let sonuc = try await GIDSignIn.sharedInstance.signIn(withPresenting: ust, hint: nil, additionalScopes: nil, nonce: Self.sha256(ham))
            guard let jeton = sonuc.user.idToken?.tokenString else { return try await googleTarayici() }
            try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .google, idToken: jeton,
                                                      accessToken: sonuc.user.accessToken.tokenString, nonce: ham))
        } catch let h as GIDSignInError where h.code == .canceled {
            return
        } catch is GIDSignInError {
            try await googleTarayici()
        }
        // GoogleSignIn dışı hata (ör. Supabase ID token'ı reddetti) yukarı iletilir.
    }

    private func googleTarayici() async throws {
        do {
            try await supabase.auth.signInWithOAuth(provider: .google, redirectTo: Sabitler.girisDonusu)
        } catch let h as ASWebAuthenticationSessionError where h.code == .canceledLogin {
            return
        }
    }

    private static func enUstDenetleyici() -> UIViewController? {
        let sahneler = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let sahne = sahneler.first { $0.activationState == .foregroundActive } ?? sahneler.first
        var vc = sahne?.windows.first(where: \.isKeyWindow)?.rootViewController ?? sahne?.windows.first?.rootViewController
        while let s = vc?.presentedViewController { vc = s }
        return vc
    }

    // MARK: Çıkış ve hesap silme

    func cikis() async {
        await cikmadanOnce?()
        cikistaTemizle?()
        try? await supabase.auth.signOut()
    }

    private struct SilmeYaniti: Decodable {
        let success: Bool?
        let account_deleted: Bool?
    }

    /// `beebook-delete-account` (akıllı silme). Dönüş: hesap tümüyle silindi mi
    /// (false → başka KSapp uygulamasında verisi var, yalnız Beebook verisi silindi).
    func hesabiSil() async throws -> Bool {
        let y: SilmeYaniti = try await supabase.functions.invoke(Sabitler.silmeFonksiyonu)
        cikistaTemizle?()
        try? await supabase.auth.signOut()
        return y.account_deleted != false
    }

    // MARK: Yardımcılar

    private static func rastgeleNonce(_ uzunluk: Int = 32) -> String {
        let karakterler = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var sonuc = ""
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<uzunluk { sonuc.append(karakterler[Int(rng.next() % UInt64(karakterler.count))]) }
        return sonuc
    }

    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
