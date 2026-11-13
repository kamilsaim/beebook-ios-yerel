import AuthenticationServices
import SwiftUI

/// Giriş: amblem, BeeBook, iki satır, Apple / Google, hesapsız devam.
struct GirisEkrani: View {
    @Environment(OturumYoneticisi.self) private var oturum
    @Environment(\.openURL) private var urlAc
    @State private var bekle: String?
    @State private var sorun: String?

    var body: some View {
        ZStack {
            Image("ArkaYesil").resizable().scaledToFill().ignoresSafeArea()
            LinearGradient(colors: [Renk.ormanKoyu.opacity(0.35), Renk.orman.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    Image("Amblem").resizable().scaledToFit()
                        .frame(width: 170, height: 170)
                        .shadow(color: Renk.bal.opacity(0.4), radius: 18)
                        .accessibilityHidden(true)
                    (Text("Bee").foregroundStyle(Renk.krem) + Text("Book").foregroundStyle(Renk.bal))
                        .font(Yazi.logo(52))
                        .padding(.top, 14)
                        .accessibilityAddTraits(.isHeader)
                    Text("Arıcının El Defteri")
                        .font(Yazi.nunito(17, .semibold))
                        .foregroundStyle(Renk.acikBal)
                    Text("Kovanların, ana arıların, satış ve stoğun\nher yerde yanında.")
                        .font(Yazi.govde)
                        .foregroundStyle(Color(white: 0.85))
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                    Spacer(minLength: 48)
                    dugmeler
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var dugmeler: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.continue) { istek in
                oturum.appleIstegiHazirla(istek)
            } onCompletion: { sonuc in
                Task { await gir("apple") { try await oturum.appleSonucu(sonuc) } }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .disabled(bekle != nil)

            Button {
                Task { await gir("google") { try await oturum.googleIleGir() } }
            } label: {
                HStack(spacing: 10) {
                    if bekle == "google" { ProgressView().tint(Renk.metin) } else {
                        Text("G").font(.system(size: 19, weight: .bold)).foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                    }
                    Text("Google ile devam et").font(.system(size: 19, weight: .semibold))
                }
                .foregroundStyle(Renk.metin)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Renk.krem, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(bekle != nil)

            Button { oturum.hesapsizDevam() } label: {
                Text("Hesapsız devam et").font(Yazi.govdeOrta).foregroundStyle(Renk.acikBal)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(bekle != nil)

            if let sorun {
                Text(sorun).font(Yazi.kucukOrta).foregroundStyle(Color(red: 1, green: 0.6, blue: 0.55))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 4) {
                Text("Kayıtların yalnızca sana görünür. Hesapsız kullanımda veriler yalnız bu telefonda kalır.")
                    .multilineTextAlignment(.center)
                Button("Gizlilik politikası") { urlAc(Sabitler.gizlilik) }
                    .foregroundStyle(Renk.acikBal)
                    .frame(minHeight: 44)
            }
            .font(Yazi.kucuk)
            .foregroundStyle(Color(white: 0.75))
            .padding(.top, 6)
        }
    }

    private func gir(_ ad: String, _ islem: () async throws -> Void) async {
        bekle = ad
        sorun = nil
        do { try await islem() } catch { sorun = "Giriş yapılamadı: \(error.localizedDescription)" }
        bekle = nil
    }
}
