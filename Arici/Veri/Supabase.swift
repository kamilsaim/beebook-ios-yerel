import Foundation
import Supabase

/// Web aricilik.html ile aynı Supabase projesi ve anon (yayımlanabilir) anahtar — güvenlik RLS'te.
enum Sabitler {
    static let supabaseURL = URL(string: "https://pdxnpnlwrtswwifevlil.supabase.co")!
    static let supabaseAnahtar = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBkeG5wbmx3cnRzd3dpZmV2bGlsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4MTk3MDIsImV4cCI6MjA5NDM5NTcwMn0.y5-rmssEre3GnaxenCMoo78XK69aIyR3P2XyGeMiU_g"
    static let girisDonusu = URL(string: "com.kamilsaim.arici://auth-callback")!
    static let gizlilik = URL(string: "https://kamilsaim.github.io/beebook/gizlilik-politikasi.html")!
    static let urunBucket = "beebook-urun"
    static let silmeFonksiyonu = "beebook-delete-account"
}

/// Tek Supabase istemcisi.
let supabase = SupabaseClient(
    supabaseURL: Sabitler.supabaseURL,
    supabaseKey: Sabitler.supabaseAnahtar,
    options: SupabaseClientOptions(
        db: .init(decoder: JSONDecoder()),
        auth: .init(redirectToURL: Sabitler.girisDonusu, emitLocalSessionAsInitialSession: true)
    )
)
