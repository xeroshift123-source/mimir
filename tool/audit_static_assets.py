"""Read-only asset inventory. Requires Pillow; run from any directory.

python tool/audit_static_assets.py --output docs/static-assets-inventory.md
Searches ignored/hidden project source too, including backups, but excludes
generated builds, SDKs, dependencies and this audit's own output.
"""
import argparse
import hashlib
import itertools
import json
from collections import defaultdict
from pathlib import Path
import subprocess

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
IMAGE_EXTS = {'.png', '.webp', '.jpg', '.jpeg', '.gif', '.bmp', '.avif'}


def audit():
    command = ['rg', '--files', '--hidden', '--no-ignore', '-g', '!.git/**',
               '-g', '!**/node_modules/**', '-g', '!**/build/**',
               '-g', '!**/.dart_tool/**', '-g', '!flutter/**',
               '-g', '!scratch/**', '-g', '!docs/static-assets*',
               '-g', '!tool/audit_static_assets.py', '-g', '!**/__pycache__/**']
    files = subprocess.check_output(command, cwd=ROOT).decode('utf-8').splitlines()
    sources = {}
    for name in files:
        path = ROOT / name
        try:
            data = path.read_bytes()
            if b'\0' not in data:
                sources[path.relative_to(ROOT).as_posix()] = data.decode('utf-8-sig')
        except (UnicodeError, OSError):
            pass
    rows = []
    exact = defaultdict(list)
    pixels = defaultdict(list)
    fingerprints = {}
    for path in sorted((ROOT / 'assets').rglob('*')):
        if not path.is_file():
            continue
        name = path.relative_to(ROOT).as_posix()
        row = {'path': name, 'bytes': path.stat().st_size, 'extension': path.suffix.lower()}
        if path.suffix.lower() in IMAGE_EXTS:
            with Image.open(path) as im:
                rgba = im.convert('RGBA')
                row['dimensions'] = list(im.size)
                exact[hashlib.sha256(path.read_bytes()).hexdigest()].append(name)
                key = (im.size, hashlib.sha256(rgba.tobytes()).hexdigest())
                pixels[key].append(name)
                # dHash is only a candidate detector, never a deletion decision.
                small = rgba.convert('L').resize((9, 8), Image.Resampling.LANCZOS)
                values = list(small.get_flattened_data())
                fingerprints[name] = sum((values[y*9+x] > values[y*9+x+1]) << (y*8+x)
                                         for y in range(8) for x in range(8))
            row['path_refs'] = [n for n, s in sources.items()
                                if name in s.replace('\\', '/')]
            row['filename_refs'] = [n for n, s in sources.items() if path.name in s]
        rows.append(row)
    nikkes = [r for r in rows if r['path'].startswith('assets/nikke/')]
    by_path = {r['path']: r for r in rows}
    pairs = []
    for r in nikkes:
        other = str(Path(r['path']).with_suffix('.webp')).replace('\\', '/')
        if r['extension'] == '.png' and other in by_path:
            pairs.append([r['path'], other])
    near = []
    for a, b in itertools.combinations([r['path'] for r in nikkes], 2):
        distance = (fingerprints[a] ^ fingerprints[b]).bit_count()
        if distance <= 4:
            near.append([a, b, distance])
    return {'files': rows, 'png_webp_pairs': pairs,
            'exact_duplicates': [v for v in exact.values() if len(v) > 1],
            'pixel_duplicates': [v for v in pixels.values() if len(v) > 1],
            'near_duplicates_dhash_le_4': near,
            'searched_text_files': len(sources), 'search_command': command}


def markdown(data):
    rows = data['files']
    nikke = [r for r in rows if r['path'].startswith('assets/nikke/')]
    lines = ['# 정적 에셋 인벤토리', '', '용량은 원본 파일 bytes / 1,048,576 = MiB. HTTP 압축·실제 방문량과 다릅니다.', '',
             '| 디렉터리 | 파일 수 | bytes | MiB |', '|---|---:|---:|---:|']
    for directory in ['assets/nikke/', 'assets/images/', 'assets/icons/', 'assets/data/']:
        selected = [r for r in rows if r['path'].startswith(directory)]
        total = sum(r['bytes'] for r in selected)
        lines.append(f'| `{directory}` | {len(selected)} | {total:,} | {total/1048576:.3f} |')
    lines += ['', '## 니케 포맷별 집계', '', '| 포맷 | 수 | bytes | MiB |', '|---|---:|---:|---:|']
    for label, exts in [('PNG', {'.png'}), ('WebP', {'.webp'}), ('JPG/JPEG', {'.jpg', '.jpeg'})]:
        selected = [r for r in nikke if r['extension'] in exts]
        total = sum(r['bytes'] for r in selected)
        lines.append(f'| {label} | {len(selected)} | {total:,} | {total/1048576:.3f} |')
    for title, selected in [('니케 이미지 TOP 20', nikke), ('전체 이미지 TOP 20', [r for r in rows if 'dimensions' in r])]:
        lines += ['', '## ' + title, '', '| 파일 | bytes | 크기 |', '|---|---:|---|']
        for r in sorted(selected, key=lambda r: r['bytes'], reverse=True)[:20]:
            lines.append(f"| `{r['path']}` | {r['bytes']:,} | {'×'.join(map(str,r['dimensions']))} |")
    lines += ['', '## 동일 basename PNG/WebP', '']
    lines += [f'- `{a}` / `{b}`' for a, b in data['png_webp_pairs']] or ['없음.']
    lines += ['', '## 니케 참조 조사 (전체 목록)', '',
              f"프로젝트 텍스트 {data['searched_text_files']}개 검색. 전체 경로와 basename+확장자를 각각 확인. 백업도 포함.",
              '동적 문자열 조합·원격 저장 데이터는 정적 검색으로 증명할 수 없으므로 참조 없음은 미사용 추정입니다.', '',
              '| 파일 | bytes | 전체 경로 참조 파일 | 파일명 참조 파일 |', '|---|---:|---|---|']
    for r in nikke:
        lines.append(f"| `{r['path']}` | {r['bytes']:,} | {', '.join(r['path_refs']) or '없음'} | {', '.join(r['filename_refs']) or '없음'} |")
    lines += ['', '## 미사용 추정 이미지 (전체 assets)', '']
    for r in rows:
        if 'path_refs' in r and not r['path_refs']:
            lines.append(f"- `{r['path']}` — 파일명 참조: {', '.join(r['filename_refs']) or '없음'}")
    for key, title in [('exact_duplicates', '동일 바이트'), ('pixel_duplicates', '동일 RGBA 픽셀')]:
        lines += ['', '## ' + title, '']
        lines += ['- ' + ' / '.join(f'`{p}`' for p in group) for group in data[key]] or ['없음.']
    lines += ['', '## 니케 유사 이미지 후보 (dHash Hamming ≤ 4)', '',
              '시각적 후보일 뿐입니다. 동일 캐릭터/스킨 판정이나 자동 삭제에 사용하지 않습니다.', '']
    lines += [f'- `{a}` / `{b}` — 거리 {distance}' for a,b,distance in data['near_duplicates_dhash_le_4']] or ['없음.']
    return '\n'.join(lines) + '\n'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    result = audit()
    target = ROOT / args.output
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(markdown(result), encoding='utf-8')
    target.with_suffix('.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(target)
