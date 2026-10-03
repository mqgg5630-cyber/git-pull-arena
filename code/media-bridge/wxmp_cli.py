#!/usr/bin/env python3
# wxmp_cli.py - WeChat Official Account (MP) mini-CLI on wechatpy (green
# channel: official API). Calls api.weixin.qq.com DIRECTLY (domestic, no
# proxy needed); make sure the laptop's public IP is in the MP admin
# IP whitelist or token fetch returns 40164.
# Config: conf/wxmp.txt with two lines:  appid=...  secret=...
# Commands:
#   check              - read config, fetch access_token, report reachability
#   upload-thumb <img> - upload a permanent image as article cover (media id
#                        saved to conf/wxmp_thumb.txt)
#   draft <title> <md> - markdown file -> inline-styled HTML -> new draft,
#                        prints the draft media_id
#   publish <id>       - submit a draft for publish (needs certified account)
# ASCII-only.

import os
import re
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
CONF = os.path.join(BASE, 'conf')


def load_cfg():
    cfg = {}
    p = os.path.join(CONF, 'wxmp.txt')
    if not os.path.exists(p):
        return None
    try:
        for ln in open(p, encoding='utf-8'):
            ln = ln.strip()
            if '=' in ln and not ln.startswith('#'):
                k, v = ln.split('=', 1)
                cfg[k.strip()] = v.strip()
    except Exception:
        return None
    return cfg


def client():
    from wechatpy import WeChatClient
    cfg = load_cfg() or {}
    if not cfg.get('appid') or not cfg.get('secret'):
        print('config missing or incomplete:')
        print('  create conf/wxmp.txt with two lines: appid=... and secret=...')
        print('  (MP admin console -> settings & development -> developer info)')
        return None
    return WeChatClient(cfg['appid'], cfg['secret'])


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def md_to_html(md):
    out = []
    for block in md.split('\n\n'):
        b = block.strip()
        if not b:
            continue
        m = re.match(r'^(#{1,3})\s+(.*)', b)
        if m:
            sizes = {1: '20px', 2: '17px', 3: '15px'}
            out.append('<p style="font-size:%s;font-weight:bold;'
                       'margin:16px 8px 8px;color:#222;">%s</p>' % (
                           sizes[len(m.group(1))], esc(m.group(2))))
        else:
            body = ''.join(('<br/>' + esc(ln) if i else esc(ln))
                           for i, ln in enumerate(b.split('\n')))
            out.append('<p style="font-size:15px;line-height:1.75;'
                       'margin:8px;color:#333;">%s</p>' % body)
    return ''.join(out)


def thumb_id():
    try:
        with open(os.path.join(CONF, 'wxmp_thumb.txt')) as f:
            return f.read().strip() or None
    except Exception:
        return None


def main():
    args = sys.argv[1:]
    cmd = args[0] if args else 'check'
    if cmd == 'check':
        c = client()
        if not c:
            return 2
        try:
            c.fetch_access_token()
            print('access_token OK - appid reachable from this machine')
            print('note: draft/publish need a CERTIFIED subscription/'
                  'service account; a test (sandbox) account only proves'
                  ' the token path.')
            return 0
        except Exception as e:
            print('token fetch FAILED: %r' % (e,))
            print('if error code 40164: add this machine\'s public IP to '
                  'the MP admin IP whitelist and retry')
            return 1
    if cmd == 'upload-thumb':
        c = client()
        if not c:
            return 2
        with open(args[1], 'rb') as f:
            r = c.material.add('image', f)
        mid = r.get('media_id')
        with open(os.path.join(CONF, 'wxmp_thumb.txt'), 'w') as f:
            f.write(mid or '')
        print('cover uploaded, media_id =', mid)
        return 0
    if cmd == 'draft':
        c = client()
        if not c:
            return 2
        title, mdfile = args[1], args[2]
        mid = thumb_id()
        if not mid:
            print('no cover set - first run: '
                  'wxmp_cli.py upload-thumb <cover.jpg>')
            return 2
        html = md_to_html(open(mdfile, encoding='utf-8').read())
        r = c.draft.add([{
            'title': title,
            'content': html,
            'thumb_media_id': mid,
            'need_open_comment': 0,
            'only_fans_can_comment': 0,
        }])
        print('draft created, media_id =', r.get('media_id'))
        return 0
    if cmd == 'publish':
        c = client()
        if not c:
            return 2
        r = c.freepublish.submit(args[1])
        print('publish submitted:', r)
        return 0
    print('usage: check | upload-thumb <img> | draft <title> <md> | '
          'publish <media_id>')
    return 2


if __name__ == '__main__':
    sys.exit(main())
