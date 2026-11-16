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
### Bal Defterim yedeğini içe aktarma (Kamil test ettikten sonra)
Ayarlar › Yedek'e "Bal Defterim yedeğini içe aktar" düğmesi. Bal Defterim yedeği (`bal-defterim-yedek-*.json`,
`V = {sezonlar, aktifSezon, fiyatlar, urunler, hasatlar, siparisler, zekatlar}`) BeeBook verisine dönüştürülür:

| Bal Defterim | BeeBook |
|---|---|
| `urunler` `{id, ad, birim, zekat, pasif}` + `fiyatlar` | `settings.stockTypes` `{v, l, unit, zakat, pasif}` + `stockPrices`; süzme/petek/karakovan → `suzme_bal`/`petek_bal`/`karakovan_bal` |
| `hasatlar` `{urun, miktar, tarih, aciklama, tip}` | `stock` `action:"in"`; `tip:"devir"` → not "… devri" (zekata girmez) |
| `siparisler` `{musteri, tel, urun, miktar, fiyat, tutar, tarih, aciklama, hediye, teslim, odendi, odenen}` | `sales` (`total = tutar ?? miktar*fiyat`; ödeme: hediye → `hediye`, tam → `paid`, `odenen>0` → `partial`+`paidAmount`, yoksa `pending`; `teslim:false` → `orderStatus:"preorder"`) + `saleId`'li stok `out` kaydı |
| `zekatlar` `{urun, miktar, tarih}` | `payment:"zekat"` satış + stok `out` |
| `sezonlar` | `seasons` `{id, year, name, start}` |

- Kimlikler `bd-<eski id>` → aynı yedek ikinci kez yüklenirse kopya oluşmaz (güncellenir).
- Çıta adedi (`cita_adet`) taşınmaz (çıta takibi istenmedi).
- Yüklemeden önce özet + onay ("N sipariş, N hasat eklenecek"): aynı satışlar BeeBook'a elle de girildiyse çift sayılır.
