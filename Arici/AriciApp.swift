import AriCekirdek
import GoogleSignIn
import Supabase
import SwiftUI

@main
struct AriciApp: App {
    @State private var oturum = OturumYoneticisi()
    @State private var depo = VeriDeposu()
    @Environment(\.scenePhase) private var sahne

    var body: some Scene {
        WindowGroup {
            KokGorunum()
                .environment(oturum)
                .environment(depo)
                .task {
                    oturum.cikistaTemizle = { [depo] in depo.temizle() }
                    await oturum.baslat()
                }
                .onChange(of: oturum.kullaniciId) { _, yeni in depo.kullaniciId = yeni }
                .onOpenURL { url in
                    if !GIDSignIn.sharedInstance.handle(url) { supabase.auth.handle(url) }
                }
                .onChange(of: sahne) { _, yeni in
                    switch yeni {
                    case .background: Task { await depo.simdiGonder() }
                    case .active: Task { await depo.yukle() }
                    default: break
                    }
                }
        }
    }
}

struct KokGorunum: View {
    @Environment(OturumYoneticisi.self) private var oturum

    var body: some View {
        Group {
            if Baslatma.ornekVeri {
                AnaKabuk()
            } else {
                switch oturum.durum {
                case .yukleniyor: Acilis()
                case .girissiz: GirisEkrani()
                case .girisli, .hesapsiz: AnaKabuk()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct Acilis: View {
    var body: some View {
        ZStack {
            Renk.orman.ignoresSafeArea()
            Image("Acilis").resizable().scaledToFit().frame(width: 180)
        }
    }
}
