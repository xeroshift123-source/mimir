"""Refresh the score dummy favorite-item catalog from BLABLALINK's public CDN."""
import ctypes
import hashlib
import json
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
BASE = 'https://sg-tools-cdn.blablalink.com'


def url(path):
    plain = path.lstrip('/')
    parts = plain.split('/')
    result = []
    for index, part in enumerate(parts[:-1]):
        prime = [224737, 1000639, 2654435761][index]
        value = prime
        for char in plain:
            value = ctypes.c_int32(value * 33 + ord(char)).value
        value %= prime
        result.append(chr(97 + value // 26 % 26) + chr(97 + value % 26)
                      + '-' + str(value % 99).zfill(2))
    result.append(hashlib.md5(plain.encode()).hexdigest() + '.' + parts[-1].split('.')[-1])
    return BASE + '/' + '/'.join(result)


def fetch(path):
    with urlopen(Request(url(path), headers={'User-Agent': 'Mozilla/5.0'}), timeout=30) as response:
        return json.load(response)


def main():
    ids = fetch('/equip/favorite_rare_map.json')['SSR']
    with ThreadPoolExecutor(max_workers=6) as pool:
        rows = list(pool.map(lambda tid: fetch(f'/equip/ko/favorite_{tid}.json'), ids))
    items = {}
    for row in rows:
        code = str(row['name_code'])
        assert row['favorite_rare'] == 'SSR' and row['favorite_type'] == 'Favorite'
        assert row['max_level'] == 2 and code not in items
        items[code] = {'tid': row['id'], 'level': row['max_level'],
                       'weapon': row['weapon_type'],
                       'source': url(f"/equip/ko/favorite_{row['id']}.json")}
    output = {'source': url('/equip/favorite_rare_map.json'),
              'verifiedAt': datetime.now(timezone.utc).isoformat(), 'items': items}
    (ROOT / 'services/nikke_score/favorite_items.json').write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'favoriteItems': len(items), 'nameCodes': list(items)}))


if __name__ == '__main__':
    main()
