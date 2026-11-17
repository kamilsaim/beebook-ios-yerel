# BeeBook iOS — yerel SwiftUI uygulaması (com.kamilsaim.beebook)

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

## Bekleyen işler
### Bal Defterim yedeğini içe aktarma (yapıldı, 17 Kas 2026 — Android'de emülatörde denendi)
Ayarlar › Yedek › "Bal Defterim yedeğini içe aktar". Kod: `Paketler/AriCekirdek/.../BalDefterimAktarim.swift`
(Android `cekirdek/.../BalDefterimAktarim.kt` ile birebir, 4 test her iki tarafta).

| Bal Defterim | BeeBook |
|---|---|
| `urunler` + `fiyatlar` | süzme/petek/karakovan → `suzme_bal`/`petek_bal`/`karakovan_bal`; `ana-ari` → `ana_ari`; diğerleri ada göre eşleşir, yoksa yeni `stockTypes` ürünü. Fiyat yalnız boş olana yazılır |
| `hasatlar` | `stock` `in` (`bd-h-<id>`); `tip:"devir"` → not "Bal Defterim devri" (zekata girmez) |
| `siparisler` | `sales` (`bd-s-<id>`): hediye → `hediye` (tutar 0), `odendi` → `paid`, `odenen>0` → `partial`, yoksa `pending`; `teslim:false` → `preorder`; stok `out` (`bd-o-…`, saleId'li) |
| `zekatlar` | `payment:"zekat"` satış (`bd-z-<id>`) + stok `out` |
| `sezonlar` | yalnız BeeBook'ta o yıl yoksa `seasons` (`bd-sez-<id>`, start = yıl-01-01); kayıtlar tarihine göre sezona düşer |

- Mevcut veri silinmez; aynı yedek ikinci kez yüklenirse kopya oluşmaz (aynı kimlikler güncellenir).
- Çıta adedi (`cita_adet`) taşınmaz.
- Onay penceresinde özet ("N sipariş · N hasat …") + çift sayım uyarısı.

### 17 Kas 2026 değişiklikleri (Android ile aynı)
- Ana Sayfa: hızlı erişim kaydırılabilir, 12 simge (Daha sayfaları `menu.dahaIstegi` ile açılır), ekran kenarına uzanır.
- Ana Sayfa: "Yapılan İşler" kartı kaldırıldı (Yapılacaklar'dan açılıyor); en alta ana arı ırk/yaş özeti (`IrkOzeti`).
- Stok: "Son Satışlar" aktif sezondan (önceden tüm sezonlar); "Gider Özeti" ikinci sırada.
- Alt menü petek ve arı 4 pt aşağı.
- Bekleyen (yalnız Android'de): ana sayfa hava kartı → geniş Hava sayfası (24 saat, 7 gün, yağış/rüzgâr, "Arıcılık için" yorumu).
