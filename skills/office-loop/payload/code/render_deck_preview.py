#!/usr/bin/env python3
# render_deck_preview.py - approximate raster preview of the authored deck SVG.
#
# The sandbox has no cairo / rsvg / LibreOffice, so the pages cannot be rendered
# with a real SVG engine. This is a small PNG renderer for the SVG subset the
# deck generator actually emits (rect / circle / line / path M-H-V-L-Z / text
# with the deck's fonts). It exists so a human can *see* the layout without
# leaving the workspace - it is a preview of the SVG sources, NOT the output of
# PowerPoint, and it ignores filters and gradients.
#
# Usage: python3 code/render_deck_preview.py --svg <svg_dir> --out preview.png

import argparse
import glob
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

SANS_CANDIDATES = ['/tmp/fonts/NotoSansSC.ttf', '/tmp/gfonts/ofl/notosanssc/NotoSansSC[wght].ttf',
                   os.path.expanduser('~/.fonts/NotoSansSC.ttf'),
                   os.path.expanduser('~/.fonts/NotoSansSC[wght].ttf'),
                   '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']
MONO_CANDIDATES = ['/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf']

TOKEN = re.compile(r'[MmLlHhVvZz]|-?\d*\.?\d+')


def pick(cands):
    for path in cands:
        if os.path.isfile(path):
            return path
    return None


class Renderer(object):
    def __init__(self, scale):
        self.scale = scale
        self.sans = pick(SANS_CANDIDATES)
        self.mono = pick(MONO_CANDIDATES) or self.sans
        self._fonts = {}

    def font(self, family, size, weight):
        fam = (family or '').lower()
        mono = 'consolas' in fam or 'mono' in fam or 'courier' in fam
        path = self.mono if mono else self.sans
        key = (path, int(size), weight)
        if key not in self._fonts:
            font = ImageFont.truetype(path, int(round(size * self.scale)))
            if weight == '700':
                try:
                    font.set_variation_by_axes([700])
                except Exception:
                    pass
            self._fonts[key] = font
        return self._fonts[key]

    # ---------------------------------------------------------------- paint
    @staticmethod
    def _rgb(color):
        color = color.strip()
        if color in ('none', ''):
            return None
        if color.startswith('url('):
            return (40, 60, 90)
        if color.startswith('#'):
            h = color[1:]
            if len(h) == 3:
                h = ''.join(c * 2 for c in h)
            return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
        return (200, 200, 200)

    def draw_page(self, path):
        import xml.etree.ElementTree as ET
        tree = ET.parse(path)
        root = tree.getroot()
        vb = [float(v) for v in root.get('viewBox').split()]
        w, h = int(vb[2] * self.scale), int(vb[3] * self.scale)
        img = Image.new('RGB', (w, h), (11, 18, 32))
        d = ImageDraw.Draw(img, 'RGBA')
        root_font = root.get('font-family') or 'sans-serif'
        for el in root.iter():
            tag = el.tag.split('}')[-1]
            if tag in ('svg', 'defs', 'filter', 'feGaussianBlur', 'feMerge', 'feMergeNode',
                       'linearGradient', 'stop', 'g'):
                continue
            if tag == 'rect':
                self._rect(d, el)
            elif tag == 'circle':
                self._circle(d, el)
            elif tag == 'line':
                self._line(d, el)
            elif tag == 'path':
                self._path(d, el)
            elif tag == 'text':
                self._text(d, el, root_font)
        return img

    def _rect(self, d, el):
        s = self.scale
        x, y = float(el.get('x', 0)) * s, float(el.get('y', 0)) * s
        w, h = float(el.get('width', 0)) * s, float(el.get('height', 0)) * s
        fill = self._rgb(el.get('fill', 'none'))
        stroke = self._rgb(el.get('stroke', 'none'))
        width = float(el.get('stroke-width', 1)) * s
        if fill or stroke:
            d.rectangle([x, y, x + w, y + h], fill=fill, outline=stroke,
                        width=max(1, int(round(width))))

    def _circle(self, d, el):
        s = self.scale
        cx, cy, r = float(el.get('cx')) * s, float(el.get('cy')) * s, float(el.get('r')) * s
        fill = self._rgb(el.get('fill', 'none'))
        if fill:
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)

    def _line(self, d, el):
        s = self.scale
        stroke = self._rgb(el.get('stroke', 'none'))
        if not stroke:
            return
        width = max(1, int(round(float(el.get('stroke-width', 1)) * s)))
        d.line([float(el.get('x1')) * s, float(el.get('y1')) * s,
                float(el.get('x2')) * s, float(el.get('y2')) * s], fill=stroke, width=width)

    def _path(self, d, el):
        s = self.scale
        cmds = TOKEN.findall(el.get('d', ''))
        pts, poly, cur = [], [], (0.0, 0.0)
        i = 0
        closed = False
        while i < len(cmds):
            c = cmds[i]
            if c in 'MmLl':
                i += 1
                x, y = float(cmds[i]), float(cmds[i + 1])
                i += 2
                if c == 'm':
                    x, y = cur[0] + x, cur[1] + y
                cur = (x, y)
                poly.append(cur)
            elif c in 'HhVv':
                i += 1
                v = float(cmds[i])
                i += 1
                x, y = cur
                if c == 'H':
                    cur = (v, y)
                elif c == 'h':
                    cur = (x + v, y)
                elif c == 'V':
                    cur = (x, v)
                else:
                    cur = (x, y + v)
                poly.append(cur)
            elif c in 'Ll':
                i += 1
                x, y = float(cmds[i]), float(cmds[i + 1])
                i += 2
                if c == 'l':
                    x, y = cur[0] + x, cur[1] + y
                cur = (x, y)
                poly.append(cur)
            elif c in 'Zz':
                i += 1
                closed = True
            else:
                i += 1
        pts = [(p[0] * s, p[1] * s) for p in poly]
        fill = self._rgb(el.get('fill', 'none'))
        stroke = self._rgb(el.get('stroke', 'none'))
        width = max(1, int(round(float(el.get('stroke-width', 1)) * s)))
        if fill and (closed or el.get('fill') not in (None, 'none')):
            d.polygon(pts, fill=fill)
        if stroke and len(pts) > 1:
            d.line(pts, fill=stroke, width=width, joint='curve')

    def _text(self, d, el, root_font):
        s = self.scale
        content = ''.join(el.itertext())
        if not content.strip():
            return
        size = float(el.get('font-size', 16))
        family = el.get('font-family') or root_font
        weight = el.get('font-weight')
        font = self.font(family, size, weight)
        fill = self._rgb(el.get('fill', '#FFFFFF')) or (255, 255, 255)
        x = float(el.get('x', 0)) * s
        y = float(el.get('y', 0)) * s
        anchor = el.get('text-anchor', 'start')
        spacing = float(el.get('letter-spacing', 0)) * s
        if anchor == 'middle':
            x -= font.getlength(content) / 2.0
        elif anchor == 'end':
            x -= font.getlength(content)
        if spacing:
            cx = x
            for ch in content:
                d.text((cx, y), ch, font=font, fill=fill, anchor='ls')
                cx += font.getlength(ch) + spacing
        else:
            d.text((x, y), content, font=font, fill=fill, anchor='ls')


def contact_sheet(svg_dir, out, scale=1.0, thumb=0.42):
    files = sorted(glob.glob(os.path.join(svg_dir, '*.svg')))
    if not files:
        print('[ERROR] no SVG in %s' % svg_dir, file=sys.stderr)
        return 1
    r = Renderer(scale)
    pages = [r.draw_page(f) for f in files]
    pw, ph = pages[0].size
    tw, th = int(pw * thumb), int(ph * thumb)
    cols, gap, pad = 3, 16, 26
    rows = (len(pages) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * tw + (cols + 1) * gap, rows * th + (rows + 1) * gap),
                      (6, 10, 20))
    for i, page in enumerate(pages):
        img = page.resize((tw, th), Image.LANCZOS)
        cx = gap + (i % cols) * (tw + gap)
        cy = gap + (i // cols) * (th + gap)
        sheet.paste(img, (cx, cy))
    sheet.save(out)
    print('sheet: %s (%dx%d, %d page(s))' % (out, sheet.size[0], sheet.size[1], len(pages)))
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--svg', required=True)
    ap.add_argument('--out', default='deck_preview.png')
    ap.add_argument('--scale', type=float, default=1.0)
    args = ap.parse_args()
    return contact_sheet(args.svg, args.out, args.scale)


if __name__ == '__main__':
    sys.exit(main())
