"""Simülatör ve App Store ekran görüntüleri için zengin örnek veri (gerçek kişi yok).
Çalıştır (ios-yerel klasöründen): python araclar/ornek-veri-uret.py  → Arici/Kaynaklar/ornek-veri.json
"""
import json
import os
import random

random.seed(7)
KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
irklar = ['Karniyol', 'Kafkas', 'Buckfast', 'Anadolu']
tipler = [('Langstroth', 2), ('Langstroth', 1), ('Dadant', 3), ('Langstroth', 3), ('Yerli', 1), ('Langstroth', 2),
          ('Dadant', 2), ('Nükleus/Ruşet', 1), ('Langstroth', 4), ('Ana Arı Kovanı', 1), ('Langstroth', 2), ('Langstroth', 1)]
durumlar = ['yes', 'yes', 'yes', 'yes', 'no', 'yes', 'bakire', 'yes', 'yes', 'meme', 'yes', 'yes']
yillar = ['2025', '2025', '2024', '2025', '', '2026', '2026', '2025', '2024', '', '2025', '2023']
renk = {'2026': 'white', '2025': 'blue', '2024': 'green', '2023': 'red', '': 'white'}

hives, pos = [], {}
for i in range(12):
    t, f = tipler[i]
    y = yillar[i]
    hives.append({'id': f'h{i+1}', 'num': str(i + 1), 'type': t, 'queenStatus': durumlar[i], 'queenColor': renk[y],
                  'strength': '2' if durumlar[i] == 'no' else str(random.choice([3, 4, 5])),
                  'race': irklar[i % 4], 'generation': random.choice(['F1', 'F2', '']), 'year': y,
                  'frames': str(random.choice([8, 10, 10, 6])), 'floors': f, 'notes': '', 'createdAt': '2025-04-03', '_up': 1})
    pos[f'h{i+1}'] = {'x': 30 + (i % 4) * 90, 'y': 40 + (i // 4) * 120}

def satis(id, prod, tip, musteri, tarih, qty, unit, price, payment, **ek):
    s = {'id': id, 'type': tip, 'product': prod, 'customer': musteri, 'date': tarih, 'qty': qty, 'unit': unit,
         'price': price, 'total': 0 if payment == 'hediye' else round(qty * price, 2), 'payment': payment,
         'orderStatus': ek.pop('orderStatus', 'delivered'), '_up': 1}
    if tip == 'honey':
        s['honeyType'] = prod
    s.update(ek)
    return s

sales = [
    satis('s1', 'suzme_bal', 'honey', 'Ahmet Yılmaz', '2026-11-11', 15, 'kg', 350, 'paid', phone='05551112233'),
    satis('s2', 'bal_sirkesi', 'other', 'Ayşe Demir', '2026-11-13', 3, 'lt', 150, 'partial', paidAmount=150, batchId='b1', phone='05552223344'),
    satis('s3', 'suzme_bal', 'honey', 'Ayşe Demir', '2026-11-13', 1, 'kg', 350, 'partial', paidAmount=0, batchId='b1', phone='05552223344'),
    satis('s4', 'propolis', 'other', 'Şifa Eczanesi', '2026-11-09', 0.5, 'lt', 4800, 'pending'),
    satis('s5', 'ana_ari', 'queen', 'Mustafa Usta', '2026-11-12', 5, 'adet', 800, 'pending', orderStatus='preorder', phone='05553334455'),
    satis('s6', 'petek_bal', 'honey', 'Komşu Mehmet', '2026-11-08', 2, 'kg', 0, 'hediye'),
]
stock = [
    {'id': 'k1', 'product': 'suzme_bal', 'action': 'in', 'amount': 200, 'unit': 'kg', 'date': '2026-08-20', 'note': 'Yaz hasadı'},
    {'id': 'k2', 'product': 'petek_bal', 'action': 'in', 'amount': 42, 'unit': 'kg', 'date': '2026-08-20', 'note': 'Yaz hasadı'},
    {'id': 'k3', 'product': 'bal_sirkesi', 'action': 'in', 'amount': 24, 'unit': 'lt', 'date': '2026-09-15', 'note': ''},
    {'id': 'k4', 'product': 'propolis', 'action': 'in', 'amount': 2, 'unit': 'lt', 'date': '2026-09-20', 'note': ''},
    {'id': 'k5', 'product': 'ari_sutu', 'action': 'in', 'amount': 620, 'unit': 'gr', 'date': '2026-06-10', 'note': 'Hasat', 'milkId': 'm1'},
    {'id': 'k6', 'product': 'polen', 'action': 'in', 'amount': 12, 'unit': 'kg', 'date': '2026-07-01', 'note': ''},
    {'id': 'k7', 'product': 'ana_ari', 'action': 'in', 'amount': 14, 'unit': 'adet', 'date': '2026-11-01', 'note': 'Seri A-26'},
]
for k in stock:
    k['_up'] = 1
for s in sales:
    stock.append({'id': 'o' + s['id'], 'product': s['product'], 'action': 'out', 'amount': s['qty'], 'unit': s['unit'],
                  'date': s['date'], 'note': ('Hediye' if s['payment'] == 'hediye' else 'Satış') + ': ' + s['customer'],
                  'saleId': s['id'], '_up': 1})

memeler = ['kovana_aktarildi'] * 9 + ['satildi'] * 4 + ['pending'] * 6 + ['oldu']
data = {
    'hives': hives, 'sales': sales, 'stock': stock,
    'expenses': [
        {'id': 'e1', 'type': 'feed', 'amount': 6500, 'date': '2026-10-02', 'desc': 'Şurup şekeri', 'payment': 'paid', '_up': 1},
        {'id': 'e2', 'type': 'medicine', 'amount': 1800, 'date': '2026-09-12', 'desc': 'Varroa şeridi', 'payment': 'pending', '_up': 1}],
    'milk': [{'id': 'm1', 'amount': 620, 'date': '2026-06-10', 'hiveCount': 8, 'note': '', '_up': 1}],
    'queens': [{'id': 'q1', 'name': 'Seri A-26', 'race': 'Karniyol', 'generation': 'F1', 'motherHive': 'h1', 'starterHive': 'h4',
                'transfer': '2026-11-04', 'grafted': 30, 'accepted': 20, 'emerged': 0, 'sold': 0, 'status': 'active', 'notes': '',
                'queens': [{'id': f'mm{i}', 'num': str(i + 1), 'status': st, 'targetHive': ''} for i, st in enumerate(memeler)], '_up': 1}],
    'tasks': [
        {'id': 't1', 'text': 'Şurup ver (1 lt)', 'done': True, 'dueDate': '2026-11-13', 'scope': '5-11',
         'hiveIds': [f'h{i}' for i in range(5, 12)], '_up': 1},
        {'id': 't2', 'text': 'Varroa şeridi tak', 'done': False, 'dueDate': '2026-11-13', 'scope': 'Tüm Langstroth',
         'hiveIds': [h['id'] for h in hives if h['type'] == 'Langstroth'], '_up': 1},
        {'id': 't3', 'text': 'Seri A-26 meme dağıtımı', 'done': False, 'dueDate': '2026-11-14', '_up': 1},
        {'id': 't4', 'text': 'Kışlık kontrol', 'done': False, 'dueDate': '2026-11-16', '_up': 1}],
    'seasons': [{'id': 's2026', 'year': 2026, 'name': '2026 Sezonu', 'active': True, 'start': '2026-01-01', '_up': 1}],
    'inventory': [{'id': 'i1', 'name': 'Ballık', 'qty': 24, 'status': 'saglam', 'note': '', '_up': 1},
                  {'id': 'i2', 'name': 'Körük', 'qty': 2, 'status': 'tamir', 'note': '', '_up': 1}],
    'inspections': [
        {'id': 'n1', 'hiveId': 'h1', 'date': '2026-11-12', 'queenSeen': True, 'eggs': True, 'brood': 'duzenli', 'strength': '5',
         'feeding': '1 lt şurup', 'note': '', '_up': 1},
        {'id': 'n2', 'hiveId': 'h5', 'date': '2026-11-10', 'queenSeen': False, 'eggs': False, 'brood': 'yok', 'strength': '2',
         'feeding': '', 'note': 'Ana yok, birleştirilecek', '_up': 1}],
    'araziLayout': {'positions': pos, 'spacers': [], '_up': 1},
    'deleted': [],
}
settings = {
    'city': 'Muğla', 'userName': 'Örnek Arıcı', 'activeSeason': 's2026', 'hiveView': 'list',
    'stockTypes': [
        {'v': 'suzme_bal', 'l': '🍯 Süzme Bal', 'unit': 'kg'}, {'v': 'petek_bal', 'l': '🍯 Petek Bal', 'unit': 'kg'},
        {'v': 'ari_sutu', 'l': '🥛 Arı Sütü', 'unit': 'gr'}, {'v': 'karakovan_bal', 'l': '🫙 Karakovan Bal', 'unit': 'kg'},
        {'v': 'bal_sirkesi', 'l': 'Bal Sirkesi', 'unit': 'lt', 'zakat': True}, {'v': 'propolis', 'l': 'Propolis', 'unit': 'lt', 'zakat': True},
        {'v': 'polen', 'l': 'Polen', 'unit': 'kg', 'image': 'hazir:UrunPolen'}, {'v': 'ana_ari', 'l': 'Ana Arı', 'unit': 'adet', 'image': 'hazir:UrunAnaari'}],
    'stockPrices': {'suzme_bal': 350, 'petek_bal': 400, 'ari_sutu': 12, 'bal_sirkesi': 150, 'propolis': 4800, 'polen': 900, 'ana_ari': 800},
    '_up': 1,
}
cikti = os.path.join(KOK, 'Arici', 'Kaynaklar', 'ornek-veri.json')
with open(cikti, 'w', encoding='utf-8', newline='\n') as f:
    json.dump({'data': data, 'settings': settings}, f, ensure_ascii=False, indent=1)
print('ornek-veri.json yazıldı')
