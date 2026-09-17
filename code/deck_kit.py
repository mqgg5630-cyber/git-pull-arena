#!/usr/bin/env python3
# deck_kit.py - the shared framework behind every deck this loop generates.
#
# A deck is 12 canonical SVG pages for PPT Master (route: Quick Generate). The
# parts that must NOT drift between decks live here: the canvas, the token
# palette, the escaping, the "one bounded group per module" authoring rule and
# the local version of the rule the machine's svg_quality_checker enforces
# (ordinary direct-root module zones may never overlap, XML must be well formed).
#
# A deck generator supplies the pages and one line of identity:
#
#   from deck_kit import Page, card, divider_page, run
#   Page.total_pages, Page.footer, Page.host = 12, FOOTER, HOST
#   BUILDERS = [('01_cover.svg', page_cover), ...]
#   if __name__ == '__main__':
#       sys.exit(run(BUILDERS, session=SESSION, apply_facts=..., title='...'))
#
# copy of the framework used by code/make_deck_pptmaster.py - the deck that
# proved this loop (git-sync v2.8.1 / ppt-master) - and by
# code/make_deck_umami.py (machine-learning screening of umami peptides).
import argparse
import glob
import hashlib
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

W, H = 1280, 720

# ----------------------------------------------------------------- tokens
BG = '#0B1220'
PANEL = '#121C2E'
PANEL_DEEP = '#0D1626'
LINE = '#1E3A5F'
LINE_SOFT = '#17293F'
CYAN = '#22D3EE'
BLUE = '#60A5FA'
LIME = '#A3E635'
AMBER = '#FBBF24'
INK = '#F1F5F9'
MUTED = '#94A3B8'
DIM = '#64748B'
MONO_INK = '#7DD3FC'

SANS = 'Microsoft YaHei, Segoe UI, sans-serif'
MONO = 'Consolas, monospace'

CJK_EM = 1.0      # advance estimate, only for the overflow guard
ASCII_EM = 0.55

def text_width(s, size):
    cjk = sum(1 for ch in s if ord(ch) > 0x2E80)
    return (cjk * CJK_EM + (len(s) - cjk) * ASCII_EM) * size


# XML 1.0 has no way to carry these, not even as numeric references: the C0
# controls other than tab/newline/carriage-return, DEL, the C1 block and lone
# surrogates. One of them in a page makes svg_quality_checker fail the whole
# page ("Invalid XML"), so drop them at the door instead of discovering it in
# the machine's round log.
BAD_XML_CHAR = re.compile(
    '[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f\ud800-\udfff\ufffe\uffff]')


def esc(s):
    s = BAD_XML_CHAR.sub('', s)
    return (s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
             .replace('"', '&quot;').replace("'", '&apos;'))


# ------------------------------------------------------- layout assertions
# svg_quality_checker fails a page when two of its ordinary direct-root module
# zones overlap ("keep ordinary direct-root module zones disjoint beyond the
# 1px tolerance") or when a page is not well-formed XML. Both are cheaper to
# catch here, where the page name and the two ids are still known, than in a
# machine round log (field report round 28: 08_numbers.svg, kpi-2/kpi-3 over
# bar-3, checker exit 1 / blocking=2).
STRUCTURAL_ROLES = frozenset({
    'background', 'chrome', 'decoration', 'footer', 'header', 'logo',
    'page-number', 'watermark'})
BOUNDS_TOLERANCE = 1.0


def root_bounds(svg):
    """[(id, (left, top, right, bottom))] for the ordinary root module zones."""
    root = ET.fromstring(svg)
    zones = []
    for g in list(root):
        if g.tag.split('}')[-1] != 'g':
            continue
        box = g.get('data-pptx-bounds')
        if not box:
            continue
        role = (g.get('data-pptx-role') or '').strip().lower()
        if role in STRUCTURAL_ROLES or g.get('data-pptx-placeholder') is not None:
            continue
        parts = box.split()
        if len(parts) != 4:
            continue
        x, y, w, h = [float(v) for v in parts]
        zones.append((g.get('id') or '?', (x, y, x + w, y + h)))
    return zones


def bounds_overlaps(svg):
    """Messages for every pair of root module zones that overlap on both axes."""
    bad = []
    zones = root_bounds(svg)
    for i in range(len(zones)):
        for j in range(i + 1, len(zones)):
            id_a, a = zones[i]
            id_b, b = zones[j]
            ox = min(a[2], b[2]) - max(a[0], b[0])
            oy = min(a[3], b[3]) - max(a[1], b[1])
            if ox > BOUNDS_TOLERANCE and oy > BOUNDS_TOLERANCE:
                bad.append('%s overlaps %s by %.0fpx x %.0fpx' % (id_a, id_b, ox, oy))
    return bad


def xml_invalid_chars(svg):
    """Code points in the text that XML 1.0 cannot carry."""
    return sorted({ord(ch) for ch in svg if BAD_XML_CHAR.search(ch)})



class Page(object):
    # a deck sets these once (Page.total_pages = 12; Page.footer = ...; Page.host = ...)
    total_pages = 12
    footer = ''
    host = ''

    def __init__(self, role, number=None, kicker=None, title=None, subtitle=None):
        self.role = role
        self.number = number
        self.kicker = kicker
        self.title = title
        self.subtitle = subtitle
        self.stack = [[]]          # stacking so groups nest in the output
        self.warn = []

    # -- structure ----------------------------------------------------
    def group(self, gid, x, y, w, h):
        children = []
        self.stack[-1].append('<g id="%s" data-pptx-bounds="%s %s %s %s">' % (gid, x, y, w, h))
        self.stack.append(children)
        self._pending = children
        return self

    def end(self):
        children = self.stack.pop()
        self.stack[-1].extend(children)
        self.stack[-1].append('</g>')
        return self

    # -- primitives ---------------------------------------------------
    def _add(self, line):
        self.stack[-1].append(line)
        return self

    def text(self, x, y, s, size, fill, family=None, weight=None, anchor='start',
             spacing=None, limit=None, role=None, tid=None):
        if limit and text_width(s, size) > limit:
            self.warn.append('overflow: %r needs %.0fpx > limit %dpx (size %s)'
                             % (s, text_width(s, size), limit, size))
        attrs = ['x="%s"' % x, 'y="%s"' % y, 'font-size="%s"' % size, 'fill="%s"' % fill]
        if tid:
            attrs.append('id="%s"' % tid)
        if role:
            attrs.append('data-pptx-role="%s"' % role)
        if family:
            attrs.append('font-family="%s"' % family)
        if weight:
            attrs.append('font-weight="%s"' % weight)
        if anchor != 'start':
            attrs.append('text-anchor="%s"' % anchor)
        if spacing:
            attrs.append('letter-spacing="%s"' % spacing)
        return self._add('<text %s>%s</text>' % (' '.join(attrs), esc(s)))

    def rect(self, x, y, w, h, fill='none', stroke=None, rx=None, width=None,
             opacity=None, role=None, rid=None):
        attrs = ['x="%s"' % x, 'y="%s"' % y, 'width="%s"' % w, 'height="%s"' % h,
                 'fill="%s"' % fill]
        if rid:
            attrs.append('id="%s"' % rid)
        if role:
            attrs.append('data-pptx-role="%s"' % role)
        if stroke:
            attrs.append('stroke="%s"' % stroke)
        if width:
            attrs.append('stroke-width="%s"' % width)
        if rx:
            attrs.append('rx="%s"' % rx)
        if opacity is not None:
            attrs.append('opacity="%s"' % opacity)
        return self._add('<rect %s/>' % ' '.join(attrs))

    def circle(self, cx, cy, r, fill, opacity=None, glow=False, role=None, rid=None):
        attrs = ['cx="%s"' % cx, 'cy="%s"' % cy, 'r="%s"' % r, 'fill="%s"' % fill]
        if rid:
            attrs.append('id="%s"' % rid)
        if role:
            attrs.append('data-pptx-role="%s"' % role)
        if opacity is not None:
            attrs.append('opacity="%s"' % opacity)
        if glow:
            attrs.append('filter="url(#glow)"')
        return self._add('<circle %s/>' % ' '.join(attrs))

    def path(self, d, fill='none', stroke=None, width=None, opacity=None, cap=None,
             join=None, role=None, rid=None):
        attrs = ['d="%s"' % d, 'fill="%s"' % fill]
        if rid:
            attrs.append('id="%s"' % rid)
        if role:
            attrs.append('data-pptx-role="%s"' % role)
        if stroke:
            attrs.append('stroke="%s"' % stroke)
        if width:
            attrs.append('stroke-width="%s"' % width)
        if opacity is not None:
            attrs.append('opacity="%s"' % opacity)
        if cap:
            attrs.append('stroke-linecap="%s"' % cap)
        if join:
            attrs.append('stroke-linejoin="%s"' % join)
        return self._add('<path %s/>' % ' '.join(attrs))

    def line(self, x1, y1, x2, y2, stroke, width=1, opacity=None, role=None, rid=None):
        attrs = ['x1="%s"' % x1, 'y1="%s"' % y1, 'x2="%s"' % x2, 'y2="%s"' % y2,
                 'stroke="%s"' % stroke, 'stroke-width="%s"' % width]
        if rid:
            attrs.append('id="%s"' % rid)
        if role:
            attrs.append('data-pptx-role="%s"' % role)
        if opacity is not None:
            attrs.append('opacity="%s"' % opacity)
        return self._add('<line %s/>' % ' '.join(attrs))

    # -- shared composites --------------------------------------------
    def background(self, grid=True):
        self.rect(0, 0, W, H, fill=BG, role='background', rid='bg')
        if grid:
            d = []
            x = 80
            while x < W:
                d.append('M%s 0V%s' % (x, H))
                x += 80
            y = 90
            while y < H:
                d.append('M0 %sH%s' % (y, W))
                y += 90
            self.path(''.join(d), fill='none', stroke=LINE_SOFT, width=1, opacity='0.5',
                      role='decoration', rid='bg-grid')
        return self

    def page_title(self):
        self.group('page-title', 70, 44, 1140, 144)
        if self.kicker:
            self.text(74, 78, self.kicker, 16, CYAN, family=MONO, spacing='3')
        if self.title:
            self.text(70, 138, self.title, 44, INK, weight='700', limit=1130)
        if self.subtitle:
            self.text(72, 176, self.subtitle, 20, MUTED, limit=1120)
        self.end()
        self.text(1208, 78, '%02d / %02d' % (self.number, self.total_pages), 16, DIM,
                  family=MONO, anchor='end', role='page-number', tid='page-number')
        self.line(72, 622, 1208, 622, LINE_SOFT, 1, role='decoration', rid='frame-rule')
        self.text(72, 652, self.footer, 14, DIM, family=MONO, role='footer', tid='footer-left')
        self.text(1208, 652, self.host, 14, DIM, family=MONO, anchor='end', role='footer',
                  tid='footer-right')
        return self

    def svg(self):
        out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" lang="zh-CN" '
               'font-family="%s" data-pptx-page-role="%s">' % (W, H, SANS, self.role)]
        out.append('  <defs>')
        out.append('    <filter id="glow" x="-60%" y="-60%" width="220%" height="220%">'
                   '<feGaussianBlur stdDeviation="7" result="b"/>'
                   '<feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>'
                   '</filter>')
        out.append('  </defs>')
        for item in self.stack[0]:
            if item.startswith('<g '):
                out.append('  ' + item)
            elif item == '</g>':
                out.append('  ' + item)
            elif item.startswith('<text') or item.startswith('<rect') or item.startswith('<path') \
                    or item.startswith('<line') or item.startswith('<circle'):
                out.append('  ' + item)
            else:
                out.append(item)
        out.append('</svg>')
        return '\n'.join(out) + '\n'



# ----------------------------------------------------------------- helpers
def card(p, cx, cy, w, h, accent, title, lines, gid, title_size=24, line_size=17):
    """One bounded card group: panel + title + bullet lines."""
    p.group(gid, cx, cy, w, h)
    p.rect(cx, cy, w, h, fill=PANEL, stroke=LINE, rx=14, width=1)
    p.rect(cx, cy, 4, h, fill=accent, rx=2)
    p.text(cx + 32, cy + 48, title, title_size, INK, weight='700', limit=w - 60)
    ly = cy + 90
    for line, family, size in lines:
        p.text(cx + 32, ly, line, size or line_size, MUTED, family=family, limit=w - 64)
        ly += 36
    p.end()


def divider_page(number, tag, title, subtitle, note):
    p = Page('section')
    p.background(grid=True)
    p.group('chapter-number', 70, 150, 400, 210)
    p.text(88, 310, number, 140, PANEL, family=MONO, weight='700')
    p.end()
    p.group('chapter-title', 70, 362, 1150, 80)
    p.text(96, 416, title, 60, INK, weight='700', limit=1100)
    p.end()
    p.group('chapter-subtitle', 70, 446, 1010, 44)
    p.text(100, 472, subtitle, 26, MONO_INK, limit=980)
    p.end()
    p.group('chapter-rule', 90, 496, 240, 14)
    p.rect(96, 500, 220, 3, fill=CYAN)
    p.end()
    p.group('chapter-note', 70, 520, 1100, 44)
    p.text(96, 552, note, 20, MUTED, limit=1060)
    p.end()
    p.text(96, 656, Page.footer, 14, DIM, family=MONO, role='footer', tid='footer-left')
    p.text(1204, 656, '%s · %s' % (tag, Page.host), 14, DIM, family=MONO, anchor='end',
           role='footer', tid='footer-right')
    return p



# ----------------------------------------------------------------- runner
def run(builders, session, apply_facts=None, title='deck'):
    """Author every page, then refuse to hand a fragile page to the machine.

    Validates what the machine's checker validates (XML well-formedness, no
    overlapping ordinary root module zones), reports the pages' hash so two runs
    can be compared byte for byte, and fails on stray .svg files in the output
    directory. Exit 0 = the pages are safe to check, 1 = generator pinned to
    another session, 2 = at least one page would be rejected.
    """
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='.', help='svg_output directory of the ppt-master project')
    ap.add_argument('--session', default=session)
    ap.add_argument('--facts', default=None,
                    help='JSON object replacing the repo-derived numbers '
                         '(used by code/deck_layout_selftest.py to stress the layout)')
    args = ap.parse_args()

    if args.session != session:
        print('[ERROR] this generator is pinned to session %s' % session, file=sys.stderr)
        return 1
    if args.facts and apply_facts:
        apply_facts(json.loads(args.facts))

    os.makedirs(args.out, exist_ok=True)
    problems = []
    notes = []
    digest = hashlib.sha256()
    written = []
    for name, builder in builders:
        page = builder()
        svg = page.svg()
        with open(os.path.join(args.out, name), 'w', encoding='utf-8') as fh:
            fh.write(svg)
        digest.update(svg.encode('utf-8'))
        written.append(name)
        print('wrote %-24s %6d B  zones=%2d' % (name, len(svg.encode('utf-8')),
                                                len(root_bounds(svg))))
        notes.extend('%s: %s' % (name, w) for w in page.warn)
        bad_chars = xml_invalid_chars(svg)
        try:
            ET.fromstring(svg)
        except ET.ParseError as exc:
            problems.append('%s: not well-formed XML (%s); illegal code point(s) %s'
                            % (name, exc, [hex(c) for c in bad_chars] or 'none'))
        else:
            if bad_chars:
                problems.append('%s: XML-illegal code point(s) %s survived escaping'
                                % (name, [hex(c) for c in bad_chars]))
        problems.extend('%s: %s' % (name, m) for m in bounds_overlaps(svg))

    stray = sorted(set(os.path.basename(f) for f in glob.glob(os.path.join(args.out, '*.svg')))
                   - set(written))
    if stray:
        problems.append('unexpected page file(s) in %s: %s' % (args.out, stray))

    total = sum(len(open(os.path.join(args.out, n), encoding='utf-8').read().encode('utf-8'))
                for n in written)
    print('pages sha256=%s bytes=%d' % (digest.hexdigest()[:16], total))
    if notes:
        print('[WARN] %d estimated text overflow(s):' % len(notes))
        for item in notes:
            print('       ' + item)
    if problems:
        print('[FAIL] %d page problem(s) - the machine checker would reject these:'
              % len(problems))
        for item in problems:
            print('       ' + item)
        return 2
    print('== %d %s page(s) written to %s - xml ok, no overlapping module zones'
          % (len(builders), title, os.path.abspath(args.out)))
    return 0
