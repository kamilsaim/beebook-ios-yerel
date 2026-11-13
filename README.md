# BeeBook iOS — yerel SwiftUI uygulaması (com.kamilsaim.arici)

Beebook web'in (aricilik.html) yerel iPhone sürümü. Aynı Supabase `user_data` satırını kullanır, web'le kayıt bazında eşitlenir.

- Tasarım: `../docs/superpowers/specs/2026-11-13-ios-yerel-arici-design.md`
- Plan: `../docs/superpowers/plans/2026-11-13-ios-yerel-arici.md`
- Görsel tasarım: `../.superpowers/brainstorm/1534-1794559212/content/ios-tasarim-v6.html`
- Gizli depo: `kamilsaim/beebook-ios-yerel`

## Yapı
- `Paketler/AriCekirdek` — yalnız Foundation: modeller, eşitleme (web BB-MERGE birebir), stok, sezon, ana arı, raporlar. Linux CI'da `swift test` (her push).
- `Arici/` — SwiftUI uygulaması (Swift 5 dil kipi, iOS 17, yalnız iPhone).
- `project.yml` — XcodeGen; Xcode projesi bulut Mac'te üretilir.

## Derleme (yalnız Kamil onay verince)
```
gh workflow run ios-simulator.yml -R kamilsaim/beebook-ios-yerel        # ekran görüntüleri
gh workflow run ios-testflight.yml -R kamilsaim/beebook-ios-yerel -f surum=3.0
```
Derleme no = çalıştırma×10 + deneme (yeni App Store kaydı).
