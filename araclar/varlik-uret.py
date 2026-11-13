"""BeeBook iOS varlıklarını üretir (Arici/Assets.xcassets).

Kaynaklar (Kamil'in tasarım dosyaları, 13 Kas 2026):
  - Masaüstü `arı/` klasörü: kovan, ürün, arka plan, ikon setleri, `menu/ari.png`
  - aricilik/yenilogoo/: yeni logo
  - baldefterim/kimlik/: ürün simgeleri (Bal Defterim ile ortak tarz)
Çalıştır (ios-yerel klasöründen):  python araclar/varlik-uret.py
Çıktı depoya girer; bulut derlemesi bu betiği çalıştırmaz.
"""
import colorsys
import glob
import json
import os

from PIL import Image, ImageDraw, ImageFilter

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARICILIK = os.path.dirname(KOK)
PROGRAMLAR = os.path.dirname(ARICILIK)
MASA = os.path.join(os.path.expanduser('~'), 'Desktop', 'arı')
KIMLIK = os.path.join(PROGRAMLAR, 'baldefterim', 'kimlik')
VARLIK = os.path.join(KOK, 'Arici', 'Assets.xcassets')
BILGI = {'author': 'xcode', 'version': 1}
ORMAN = (13, 59, 46)

RENKLER = {
    'Orman': '#0D3B2E', 'Orman2': '#1E6B4E', 'OrmanKoyu': '#082A20', 'Bal': '#F9B233', 'AcikBal': '#FFD166',
    'Krem': '#F5E9D6', 'Krem2': '#ECDDC2', 'Kart': '#FFFDF8', 'Metin': '#1C2A22', 'Metin2': '#4F5D55',
    'Metin3': '#7F8A83', 'Iyi': '#2E8B3E', 'Uyari': '#C77A00', 'Kotu': '#C43C2C', 'Bilgi': '#2F6FB7',
    'Mor': '#7B4BB7', 'Turkuaz': '#60ECD6', 'PetekKenar': '#FFE3A0', 'SeciliMetin': '#FFD98A',
}


def yaz_json(yol, veri):
    os.makedirs(os.path.dirname(yol), exist_ok=True)
    with open(yol, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(veri, f, indent=2, ensure_ascii=False)
        f.write('\n')


def renk_seti(ad, hx):
    r, g, b = (int(hx[i:i + 2], 16) for i in (1, 3, 5))
    yaz_json(os.path.join(VARLIK, f'{ad}.colorset', 'Contents.json'), {'colors': [{'idiom': 'universal', 'color': {
        'color-space': 'srgb', 'components': {'red': f'{r / 255:.3f}', 'green': f'{g / 255:.3f}',
                                              'blue': f'{b / 255:.3f}', 'alpha': '1.000'}}}], 'info': BILGI})


def gorsel_seti(ad, img, en_fazla, jpeg=False):
    """Tek ölçekli (universal) görsel; en uzun kenar en_fazla px."""
    klasor = os.path.join(VARLIK, f'{ad}.imageset')
    os.makedirs(klasor, exist_ok=True)
    img = img.copy()
    img.thumbnail((en_fazla, en_fazla), Image.LANCZOS)
    dosya = ad.lower() + ('.jpg' if jpeg else '.png')
    if jpeg:
        img.convert('RGB').save(os.path.join(klasor, dosya), quality=82, optimize=True)
    else:
        img.save(os.path.join(klasor, dosya), optimize=True)
    yaz_json(os.path.join(klasor, 'Contents.json'), {'images': [{'idiom': 'universal', 'filename': dosya}], 'info': BILGI})


def bul(desen, kok=MASA):
    s = sorted(glob.glob(os.path.join(kok, desen)))
    if not s:
        raise SystemExit(f'Bulunamadı: {desen}')
    return s[0]


def arkaplan_temizle(img, tol=38):
    """Düz (beyaz/krem) arka planı kenarlardan taşan doldurmayla saydamlaştırır."""
    img = img.convert('RGBA')
    if img.getpixel((3, 3))[3] < 10:
        return img
    rgb = img.convert('RGB')
    w, h = img.size
    tohumlar = [(x, 0) for x in range(0, w, 40)] + [(x, h - 1) for x in range(0, w, 40)] + \
               [(0, y) for y in range(0, h, 40)] + [(w - 1, y) for y in range(0, h, 40)]
    for t in tohumlar:
        if rgb.getpixel(t) != (255, 0, 255):
            ImageDraw.floodfill(rgb, t, (255, 0, 255), thresh=tol)
    maske = Image.new('L', img.size, 0)
    p, m = rgb.load(), maske.load()
    for y in range(h):
        for x in range(w):
            m[x, y] = 0 if p[x, y] == (255, 0, 255) else 255
    maske = maske.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.2))
    img.putalpha(maske)
    return img.crop(img.getbbox())


def ari_katmanlari():
    """menu/ari.png → gövde + kanat (kanat ayrı katman: uçarken yalnız kanat çırpar)."""
    im = Image.open(os.path.join(MASA, 'menu', 'ari.png')).convert('RGBA')
    kutu = (120, 160, 1150, 1070)
    im = im.crop(kutu)
    p = im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            if p[x, y][3] < 40:
                p[x, y] = (0, 0, 0, 0)
    kanat = Image.new('RGBA', im.size, (0, 0, 0, 0))
    govde = im.copy()
    kp, gp = kanat.load(), govde.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = p[x, y]
            if a == 0:
                continue
            X, Y = x + kutu[0], y + kutu[1]
            bolge = (Y < 455 and X < 830) or (X < 665 and Y < 690)
            _, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if bolge and s < 0.62 and v > 0.5:
                kp[x, y] = (r, g, b, a)
                gp[x, y] = (0, 0, 0, 0)
    boyut = (300, int(300 * im.size[1] / im.size[0]))
    return govde.resize(boyut, Image.LANCZOS), kanat.resize(boyut, Image.LANCZOS)


def amblem():
    logo = Image.open(bul('*.png', os.path.join(ARICILIK, 'yenilogoo'))).convert('RGBA')
    return logo.crop((220, 75, 1035, 845))


def kare_kirp(img, ust_oran=1.0):
    w, h = img.size
    return img.crop((0, 0, w, int(h * ust_oran)))


def main():
    yaz_json(os.path.join(VARLIK, 'Contents.json'), {'info': BILGI})
    for ad, hx in RENKLER.items():
        renk_seti(ad, hx)

    # Uygulama simgesi: koyu yeşil zemin + amblem (%78), saydamlık yok
    a = amblem()
    ikon = Image.new('RGBA', (1024, 1024), ORMAN + (255,))
    gen = int(1024 * 0.78)
    b = a.copy(); b.thumbnail((gen, gen), Image.LANCZOS)
    ikon.alpha_composite(b, ((1024 - b.width) // 2, (1024 - b.height) // 2))
    klasor = os.path.join(VARLIK, 'AppIcon.appiconset')
    os.makedirs(klasor, exist_ok=True)
    ikon.convert('RGB').save(os.path.join(klasor, 'ikon-1024.png'), optimize=True)
    yaz_json(os.path.join(klasor, 'Contents.json'), {
        'images': [{'filename': 'ikon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
        'info': BILGI})
    gorsel_seti('Amblem', a, 360)
    gorsel_seti('Acilis', a, 540)

    govde, kanat = ari_katmanlari()
    gorsel_seti('AriGovde', govde, 300)
    gorsel_seti('AriKanat', kanat, 300)

    # Kovanlar (arka planı temizlenmiş)
    kovanlar = {
        'Kovan1Kat': '1kat.png', 'Kovan2Kat': '2kat.png', 'Kovan3Kat': '3kat.png', 'Kovan4Kat': '4kat.png',
        'Langstroth1': '*15_14_01-1.png', 'Langstroth2': '*15_14_05-2.png', 'Langstroth3': '*15_14_07-3.png',
        'Langstroth4': '*15_14_08-4.png', 'Karakovan': '*13_39_51-3.png', 'AnaAriKutusu': 'anaarikutusu.png',
        'Ruset': 'ruset.png',
    }
    for ad, desen in kovanlar.items():
        gorsel_seti(ad, arkaplan_temizle(Image.open(bul(desen))), 420)

    # Arka planlar
    gorsel_seti('ArkaManzara', Image.open(bul('*12_21_32-9.png')), 1290, jpeg=True)
    gorsel_seti('ArkaYesil', Image.open(bul('*12_21_31-8.png')), 1290, jpeg=True)
    gorsel_seti('ArkaKrem', Image.open(bul('*12_21_33-10.png')), 1000, jpeg=True)
    dort = Image.open(bul('*15_14_26-10.png')).convert('RGB')
    gorsel_seti('ArkaCicek', dort.crop((0, 0, 627, 627)), 900, jpeg=True)
    gorsel_seti('ArkaDag', dort.crop((627, 0, 1254, 627)), 900, jpeg=True)
    gorsel_seti('ArkaPetek', dort.crop((0, 627, 627, 1254)), 900, jpeg=True)
    gorsel_seti('ArkaIsik', dort.crop((627, 627, 1254, 1254)), 900, jpeg=True)

    # Hızlı erişim ikon karoları
    ikonlar = Image.open(bul('*15_14_16-7.png')).convert('RGB')
    xs = [(37, 260), (282, 500), (520, 738), (758, 976), (996, 1215)]
    adlar = [['Kovanlar', 'AnaAri', 'AriSutu', 'Satislar', 'Envanter'], ['Arazi', 'Hava', 'Raporlar', 'Sezon', 'Cevrimdisi']]
    for r, (y0, y1) in enumerate([(340, 570), (697, 930)]):
        for c, (x0, x1) in enumerate(xs):
            gorsel_seti('Ikon' + adlar[r][c], ikonlar.crop((x0, y0, x1, y1)), 300)
    durum = Image.open(bul('*15_14_20-8.png')).convert('RGB')
    xs = [(45, 318), (343, 613), (640, 910), (935, 1208)]
    adlar = [['Saglikli', 'Kontrol', 'Mudahale', 'Pasif'], ['Ekle', 'Duzenle', 'KatEkle', 'KatCikar']]
    for r, (y0, y1) in enumerate([(408, 660), (772, 1025)]):
        for c, (x0, x1) in enumerate(xs):
            gorsel_seti('Durum' + adlar[r][c], durum.crop((x0, y0, x1, y1)), 300)

    # Ürün simgeleri (Bal Defterim kimliği, krem zemin kare)
    for ad in ('suzme', 'petek', 'karakovan', 'polen'):
        gorsel_seti('Urun' + ad.capitalize(), Image.open(os.path.join(KIMLIK, f'urun-{ad}.png')).convert('RGB'), 300)
    simge = Image.open(os.path.join(KIMLIK, 'Arıcılık Simgeleri_ Ana Arı ve Kovan.png')).convert('RGBA')
    for ad, kutu in (('UrunAnaari', (30, 255, 622, 945)), ('UrunKovan', (640, 255, 1232, 945))):
        gorsel_seti(ad, kare_kirp(simge.crop(kutu), 0.74), 300)
    sut = arkaplan_temizle(Image.open(bul('*12_21_28-6.png')))
    zemin = Image.new('RGBA', (300, 300), (253, 246, 231, 255))
    sut.thumbnail((250, 250), Image.LANCZOS)
    zemin.alpha_composite(sut, ((300 - sut.width) // 2, (300 - sut.height) // 2 + 8))
    gorsel_seti('UrunSut', zemin.convert('RGB'), 300)
    print('varlıklar üretildi:', len(os.listdir(VARLIK)) - 1)


if __name__ == '__main__':
    main()
