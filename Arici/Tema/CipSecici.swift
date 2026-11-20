import SwiftUI

/// Alt alta sarılan yerleşim (çipler için).
struct AkisDuzeni: Layout {
    var aralik: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, satir: CGFloat = 0, enGenis: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x > 0 && x + z.width > w { x = 0; y += satir + aralik; satir = 0 }
            x += z.width + aralik
            satir = max(satir, z.height)
            enGenis = max(enGenis, x - aralik)
        }
        return CGSize(width: w.isFinite ? w : enGenis, height: y + satir)
    }

    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, satir: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x > 0 && x + z.width > b.width { x = 0; y += satir + aralik; satir = 0 }
            s.place(at: CGPoint(x: b.minX + x, y: b.minY + y), proposal: .unspecified)
            x += z.width + aralik
            satir = max(satir, z.height)
        }
    }
}

/// Tek dokunuşla seçim (Android `FormCipler`): başlık üstte, seçenekler çip; arılıkta eldivenle açılır menüden hızlı.
struct CipSecici<T: Hashable>: View {
    let baslik: String?
    let secenekler: [(T, String)]
    let secili: T?
    var nokta: ((T) -> Color?)? = nil
    let sec: (T) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let baslik { Text(baslik).font(Yazi.kucukOrta).foregroundStyle(Renk.metin2) }
            AkisDuzeni {
                ForEach(secenekler, id: \.0) { d, ad in
                    let acik = d == secili
                    Button { sec(d) } label: {
                        HStack(spacing: 6) {
                            if let r = nokta?(d) { Circle().fill(r).frame(width: 10, height: 10).overlay(Circle().strokeBorder(.black.opacity(0.15))) }
                            Text(ad).font(Yazi.govdeOrta).lineLimit(1)
                        }
                        .foregroundStyle(acik ? .white : Renk.metin)
                        .padding(.horizontal, 14).frame(minHeight: 40)
                        .background(acik ? Renk.orman2 : Renk.krem2.opacity(0.55), in: Capsule())
                        .overlay(Capsule().strokeBorder(acik ? Renk.orman2 : Renk.krem2))
                        .contentShape(Capsule())
                    }
                    // Form satırında birden çok düğme: satırın tamamı değil yalnız çip basılsın
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(acik ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Sayı girişi (Android `FormSayi`): − [kutu] + ve altında tek dokunuşluk hazır değerler
/// (ör. 20 larva için 20 kez + yerine bir dokunuş). Kutuya klavyeyle de yazılır; boş = girilmedi.
struct SayiGirisi: View {
    let etiket: String
    @Binding var deger: String
    var hizli: [Int] = []
    var alt: String? = nil
    var body: some View {
        let n = Int(deger) ?? 0
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(etiket).font(Yazi.govde).foregroundStyle(Renk.metin)
                    if let alt { Text(alt).font(Yazi.minik).foregroundStyle(Renk.metin3) }
                }
                Spacer(minLength: 4)
                adimDugmesi("minus", etkin: n > 0) { deger = n - 1 > 0 ? String(n - 1) : "" }
                TextField("—", text: Binding(get: { deger }, set: { yeni in
                    deger = String(String(yeni.filter(\.isNumber).prefix(4)).drop(while: { $0 == "0" }))
                }))
                .keyboardType(.numberPad).multilineTextAlignment(.center)
                .font(Yazi.nunito(21, .bold)).foregroundStyle(Renk.orman).frame(width: 64)
                adimDugmesi("plus", etkin: n < 9999) { deger = String(n + 1) }
            }
            if !hizli.isEmpty {
                CipSecici(baslik: nil, secenekler: hizli.map { ($0, "\($0)") }, secili: n) { deger = String($0) }
            }
        }
        .padding(.vertical, 2)
    }
    private func adimDugmesi(_ simge: String, etkin: Bool, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Image(systemName: simge).font(.system(size: 17, weight: .bold))
                .foregroundStyle(etkin ? Renk.orman : Renk.metin3)
                .frame(width: 40, height: 40)
                .background(Renk.krem2.opacity(etkin ? 0.8 : 0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain).disabled(!etkin)
    }
}
