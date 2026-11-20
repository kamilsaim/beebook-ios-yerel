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
