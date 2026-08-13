#!/usr/bin/env python3
"""Generate every icon MediaKeyGuardForSafari needs — stdlib only (zlib+struct).

Draws a flat rounded-square badge with two white "pause bars" (media-key
motif). Produces three sets:

  extension/images/icon-*.png        coloured — manifest + active toolbar state
  extension/images/icon-*-grey.png   grey — toolbar state when a page is excluded
  app icon set                       macOS AppIcon.appiconset PNGs + Contents.json

Run from anywhere:  python3 tools/make_icons.py
"""
import json
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXT_IMAGES = os.path.join(ROOT, 'extension', 'images')
APPICONSET = os.path.join(
    ROOT, 'app', 'MediaKeyGuardForSafari', 'MediaKeyGuardForSafari',
    'Assets.xcassets', 'AppIcon.appiconset')

EXT_SIZES = [48, 96, 128, 256, 512]
# macOS app icon: (point size, scale) pairs Xcode expects.
APP_SIZES = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
             (256, 1), (256, 2), (512, 1), (512, 2)]

BLUE = (43, 99, 199)     # active badge
GREY = (128, 132, 140)   # excluded/inactive badge
FG = (255, 255, 255)     # white pause bars


def png_chunk(tag, data):
    """Wrap raw bytes in a PNG chunk: length + tag + data + CRC."""
    return (struct.pack('>I', len(data)) + tag + data
            + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))


def make_icon(size, path, bg):
    """Rounded-square background with two centred vertical bars (RGBA)."""
    r = size * 0.22          # corner radius
    bar_w = size * 0.14      # each pause bar's width
    bar_h = size * 0.44
    gap = size * 0.10        # gap between the bars
    cx, cy = size / 2, size / 2

    rows = []
    for y in range(size):
        row = bytearray([0])  # filter byte: None
        for x in range(size):
            # Rounded-rect hit test: inside if within radius of the inset box.
            ix = min(max(x, r), size - 1 - r)
            iy = min(max(y, r), size - 1 - r)
            inside = (x - ix) ** 2 + (y - iy) ** 2 <= r * r
            if not inside:
                row += bytes((0, 0, 0, 0))
                continue
            # Pause bars: two rectangles mirrored about the centre.
            dx = abs(x - cx) - gap / 2
            in_bar = (0 <= dx <= bar_w) and abs(y - cy) <= bar_h / 2
            row += bytes(FG if in_bar else bg) + b'\xff'
        rows.append(bytes(row))

    ihdr = struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)  # 8-bit RGBA
    png = (b'\x89PNG\r\n\x1a\n'
           + png_chunk(b'IHDR', ihdr)
           + png_chunk(b'IDAT', zlib.compress(b''.join(rows), 9))
           + png_chunk(b'IEND', b''))
    with open(path, 'wb') as f:
        f.write(png)
    print(f'wrote {os.path.relpath(path, ROOT)}')


def main():
    # Extension toolbar/manifest icons — coloured and grey variants.
    os.makedirs(EXT_IMAGES, exist_ok=True)
    for s in EXT_SIZES:
        make_icon(s, os.path.join(EXT_IMAGES, f'icon-{s}.png'), BLUE)
        make_icon(s, os.path.join(EXT_IMAGES, f'icon-{s}-grey.png'), GREY)

    # macOS app icon set + the Contents.json Xcode needs to map them.
    os.makedirs(APPICONSET, exist_ok=True)
    images = []
    for pts, scale in APP_SIZES:
        px = pts * scale
        name = f'appicon-{pts}@{scale}x.png'
        make_icon(px, os.path.join(APPICONSET, name), BLUE)
        images.append({
            'filename': name,
            'idiom': 'mac',
            'scale': f'{scale}x',
            'size': f'{pts}x{pts}',
        })
    contents = {'images': images, 'info': {'author': 'xcode', 'version': 1}}
    with open(os.path.join(APPICONSET, 'Contents.json'), 'w') as f:
        json.dump(contents, f, indent=2)
    print(f'wrote {os.path.relpath(os.path.join(APPICONSET, "Contents.json"), ROOT)}')


if __name__ == '__main__':
    sys.exit(main())
