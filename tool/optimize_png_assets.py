"""Losslessly recompress static PNG IDAT chunks, preserving all other chunks.

Requires Pillow. Dry run by default; --apply writes only smaller, pixel-identical
files. Animated/mislabeled files and changed PNG layouts are skipped.
Do not reuse an immutable published URL for changed content in future releases.
"""
import argparse
import io
import json
from pathlib import Path
import struct

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SIGNATURE = b'\x89PNG\r\n\x1a\n'


def chunks(data):
    offset = 8
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        yield data[offset + 4:offset + 8], data[offset:offset + length + 12]
        offset += length + 12


def optimize(path, apply):
    original = path.read_bytes()
    if not original.startswith(SIGNATURE):
        return None
    old_chunks = list(chunks(original))
    if any(kind == b'acTL' for kind, _ in old_chunks):
        return None
    with Image.open(io.BytesIO(original)) as im:
        encoded = io.BytesIO()
        im.save(encoded, format='PNG', optimize=True)
        new_chunks = list(chunks(encoded.getvalue()))
        # Retain the original color mode, depth, palette, alpha and metadata.
        for kind in [b'IHDR', b'PLTE']:
            if [data for k, data in old_chunks if k == kind] != [data for k, data in new_chunks if k == kind]:
                return None
        idat = b''.join(data for kind, data in new_chunks if kind == b'IDAT')
        output = bytearray(SIGNATURE)
        inserted = False
        for kind, data in old_chunks:
            if kind == b'IDAT':
                if not inserted:
                    output.extend(idat)
                    inserted = True
            else:
                output.extend(data)
        if len(original) - len(output) < max(1024, len(original) * .01):
            return None
        with Image.open(io.BytesIO(output)) as result:
            assert result.size == im.size
            assert result.convert('RGBA').tobytes() == im.convert('RGBA').tobytes(), path
        assert [(k, d) for k, d in chunks(output) if k != b'IDAT'] == [(k, d) for k, d in old_chunks if k != b'IDAT']
    if apply:
        path.write_bytes(output)
    return {'path': path.relative_to(ROOT).as_posix(), 'before': len(original),
            'after': len(output), 'saved': len(original)-len(output),
            'rgba_pixels_identical': True, 'non_idat_chunks_identical': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--output')
    args = parser.parse_args()
    results = []
    for directory in ['assets/images', 'assets/icons']:
        for path in sorted((ROOT / directory).rglob('*.png')):
            result = optimize(path, args.apply)
            if result:
                results.append(result)
    report = json.dumps(results, ensure_ascii=False, indent=2) + '\n'
    if args.output:
        (ROOT / args.output).write_text(report, encoding='utf-8')
    print(report)
