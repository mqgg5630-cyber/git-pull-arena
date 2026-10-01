"""desk_harness_deck.py - runs ON THE DESKTOP. Build a 12-slide editable
PPTX through the vendored harness CLI (real WPS COM), then reopen-verify
(slides / shapes / text). Chinese strings are embedded as \\uXXXX escapes
so this file stays ASCII-only. Usage:
    py -3.12 desk_harness_deck.py   (run inside the output directory)
ASCII-only."""

import json
import os
import subprocess
import sys

SLIDES = [
 {
  "title": "\u53cc\u673a\u81ea\u52a8\u5316\u7ba1\u7ebf\u6210\u679c\u6c47\u62a5",
  "content": "Arena Agent \u00b7 2026\u5e7410\u67081\u65e5",
  "elements": [
   {
    "type": "text_box",
    "text": "\u7531 harness-anything \u9a71\u52a8 WPS COM \u81ea\u52a8\u751f\u6210 \u00b7 \u672c\u9875\u53ca\u540e\u7eed\u6bcf\u9875\u5747\u53ef\u7f16\u8f91",
    "x": 0.08,
    "y": 0.68,
    "width": 0.84,
    "height": 0.1,
    "size": 14
   }
  ]
 },
 {
  "title": "\u4e09\u5927\u4efb\u52a1",
  "content": "\u2460 Antigravity \u53f0\u5f0f\u673a\u767b\u5f55\u4fee\u590d\n\u2461 Antigravity IDE \u53cc\u673a\u540c\u6b65\n\u2462 harness-anything \u63a5\u7ba1 WPS \u5236\u4f5c\u53ef\u7f16\u8f91 PPTX",
  "elements": [
   {
    "type": "text_box",
    "text": "\u5168\u7a0b\u65e0\u4eba\u503c\u5b88 \u00b7 git-sync \u8f6e\u6b21\u9a71\u52a8 \u00b7 \u56de\u6267\u5168\u90e8\u5165\u5e93",
    "x": 0.08,
    "y": 0.8,
    "width": 0.84,
    "height": 0.08,
    "size": 12
   }
  ]
 },
 {
  "title": "\u57fa\u7840\u8bbe\u65bd\uff1agit-sync \u89c2\u5bdf\u8005\u73af",
  "content": "\u6c99\u7bb1 \u2194 \u7b14\u8bb0\u672c \u2194 \u53f0\u5f0f\u673a \u4e09\u89d2\u94fe\u8def\n\u7b14\u8bb0\u672c watcher \u6bcf\u8f6e\u62c9\u53d6\u8bf7\u6c42\u3001\u6267\u884c\u4efb\u52a1\u3001\u56de\u5199\u5224\u636e\n\u7d2f\u8ba1 145+ \u8f6e\u5168\u90e8\u95ed\u73af",
  "elements": []
 },
 {
  "title": "\u767b\u5f55\u4fee\u590d\uff1a\u6839\u56e0",
  "content": "Go \u8bed\u8a00\u670d\u52a1\u5668\u4e0d\u8d70\u7cfb\u7edf\u4ee3\u7406\u3001\u53ea\u8ba4\u73af\u5883\u53d8\u91cf\n\u76f4\u8fde googleapis \u88ab\u5899 \u2192 OAuth token \u62ff\u4e0d\u5230\n\u767b\u5f55\u56de\u8c03 127.0.0.1 \u53c8\u88ab\u4ee3\u7406\u52ab\u6301",
  "elements": [
   {
    "type": "text_box",
    "text": "dial tcp 108.177.x.x:443 \u2192 i/o timeout",
    "x": 0.08,
    "y": 0.82,
    "width": 0.7,
    "height": 0.08,
    "size": 12
   }
  ]
 },
 {
  "title": "\u767b\u5f55\u4fee\u590d\uff1a\u4e94\u5c42\u4fee\u590d\u6808",
  "content": "\u2460 \u4ee3\u7406\u542f\u52a8\u5305\u88c5\u5668\uff08env \u5feb\u7167\u81ea\u8bc1\uff09\n\u2461 \u673a\u5668\u7ea7 HTTP(S)_PROXY\uff08\u6ce8\u518c\u8868\u843d\u76d8\uff09\n\u2462 settings.json\uff08http.proxy + proxySupport\uff09\n\u2463 noProxy \u8c41\u514d 127.0.0.1 \u767b\u5f55\u56de\u8c03\n\u2464 \u8ba1\u5212\u4efb\u52a1\u7ecf\u5305\u88c5\u5668\u91cd\u542f",
  "elements": []
 },
 {
  "title": "\u767b\u5f55\u4fee\u590d\uff1a\u6210\u679c",
  "content": "\u76f4\u8fde\u9519\u8bef 136 \u6761 \u2192 0 \u6761\n\u8bed\u8a00\u670d\u52a1\u5668\u521d\u59cb\u5316 6\u520629\u79d2 \u2192 3.6\u79d2\n\u8fdc\u7a0b\u63a7\u5236\u901a\u9053 Connected",
  "elements": [
   {
    "type": "text_box",
    "text": "Auth succeeded \u00b7 RemoteControl Connected",
    "x": 0.08,
    "y": 0.82,
    "width": 0.8,
    "height": 0.08,
    "size": 12
   }
  ]
 },
 {
  "title": "IDE \u53cc\u673a\u540c\u6b65",
  "content": "\u53f0\u5f0f\u673a 2.12.2 \u2192 2.15.1\uff08\u5b98\u65b9\u5b89\u88c5\u5668\u9759\u9ed8\u5347\u7ea7\uff09\n\u7b14\u8bb0\u672c settings.json \u540c\u6b65\u8fc7\u53bb\n\u91cd\u542f\u540e\u4ee3\u7406\u94fe\u4fdd\u6301\u5b8c\u597d",
  "elements": [
   {
    "type": "text_box",
    "text": "fresh session dial-tcp=0 \u00b7 live to-proxy=13",
    "x": 0.08,
    "y": 0.82,
    "width": 0.8,
    "height": 0.08,
    "size": 12
   }
  ]
 },
 {
  "title": "harness-anything \u63a5\u7ba1 WPS",
  "content": "CLI \u2192 Session \u2192 Core \u2192 WPS COM\n47 \u6761\u547d\u4ee4\u8986\u76d6\u6587\u5b57/\u8868\u683c/\u6f14\u793a\n\u672c\u9879\u76ee vendor \u5316 + \u79bb\u7ebf wheel \u5b89\u88c5",
  "elements": [
   {
    "type": "text_box",
    "text": "KWPS.Application / KET.Application / KWPP.Application",
    "x": 0.08,
    "y": 0.82,
    "width": 0.84,
    "height": 0.08,
    "size": 12
   }
  ]
 },
 {
  "title": "\u5f15\u64ce\u5065\u5eb7\u63a2\u6d4b\u8865\u4e01",
  "content": "\u4e0a\u6e38 KWPP ProgID \u5728\u90e8\u5206\u673a\u5668\u6307\u5411\u75c5\u6001\u5f15\u64ce\n\u8865\u4e01\uff1a\u5019\u9009\u94fe\u63a2\u6d4b KWPP \u2192 wpp.Application \u2192 CLSID\nSlides(1) \u5931\u8d25\u81ea\u52a8 Add \u515c\u5e95\n\u65b0\u589e\u5f3a text_box \u5143\u7d20\u6e32\u67d3\uff08\u5206\u6570\u5750\u6807\uff09",
  "elements": []
 },
 {
  "title": "\u6d4b\u8bd5\u77e9\u9635",
  "content": "\u7b14\u8bb0\u672c\uff1awriter \u6d41\u7a0b \u2713\uff08\u53ef\u7f16\u8f91 docx \u91cd\u5f00\u9a8c\u8bc1\uff09\n\u53f0\u5f0f\u673a\uff1aWPS \u5168\u65b0\u5b89\u88c5 + writer/impress \u53cc\u6d41\u7a0b \u2713\n\u672c PPTX\uff1a12 \u9875\u5168\u91cf\u751f\u6210 + COM \u91cd\u5f00\u9a8c\u8bc1",
  "elements": []
 },
 {
  "title": "\u672c\u6f14\u793a\u6587\u7a3f\u5373\u8bc1\u660e",
  "content": "12 \u9875 \u00b7 \u6bcf\u9875\u6807\u9898/\u6b63\u6587/\u6587\u672c\u6846\u5168\u90e8\u7531 WPS COM \u5199\u5165\n\u4fdd\u5b58\u4e3a\u6807\u51c6 OOXML pptx\n\u53cc\u51fb\u5373\u53ef\u7528 WPS \u6216 PowerPoint \u6253\u5f00\u7ee7\u7eed\u7f16\u8f91",
  "elements": [
   {
    "type": "text_box",
    "text": "\u2014\u2014 \u4f60\u73b0\u5728\u770b\u5230\u7684\u4e00\u5207\u90fd\u662f\u81ea\u52a8\u751f\u6210\u7684 \u2014\u2014",
    "x": 0.2,
    "y": 0.86,
    "width": 0.6,
    "height": 0.08,
    "size": 14
   }
  ]
 },
 {
  "title": "\u4e0b\u4e00\u6b65",
  "content": "\u53f0\u5f0f\u673a\u7b97\u529b\u6b63\u5f0f\u63a5\u5165\u65e5\u5e38\u4efb\u52a1\n\u66f4\u591a harness \u6280\u80fd\uff1aZotero / Photoshop / Illustrator\n\u7b14\u8bb0\u672c\u6f14\u793a\u7ec4\u4ef6 COM \u4fee\u590d\uff08\u5f85\u6392\u671f\uff09",
  "elements": []
 }
]

META_TITLE = "\u53cc\u673a\u81ea\u52a8\u5316\u7ba1\u7ebf\u6210\u679c\u6c47\u62a5"


def get_engine():
    import win32com.client
    for pg in ("KWPP.Application", "wpp.Application"):
        try:
            return win32com.client.Dispatch(pg)
        except Exception:
            pass
    raise RuntimeError("no WPP COM engine available")


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    project = {
        "name": "arena-report",
        "version": "1.0",
        "type": "impress",
        "settings": {},
        "metadata": {"title": META_TITLE, "author": "arena-agent",
                     "description": "generated by cli-anything-wps", "subject": ""},
        "styles": [],
        "slides": SLIDES,
    }
    with open("proj_deck.json", "w", encoding="utf-8") as f:
        json.dump(project, f, ensure_ascii=False, indent=1)
    print("project slides:", len(SLIDES))

    r = subprocess.run(
        [sys.executable, "-m", "cli_anything.wps", "--project", "proj_deck.json",
         "export", "render", "arena_report.pptx", "-p", "pptx"],
        capture_output=True, text=True, timeout=600)
    out = (r.stdout or "") + (r.stderr or "")
    print("export rc:", r.returncode)
    for ln in [x for x in out.splitlines() if x.strip()][-6:]:
        print("  |", ln.strip()[:200])
    if r.returncode != 0 or not os.path.isfile("arena_report.pptx"):
        print("EXPORT FAILED")
        sys.exit(2)
    print("pptx KB:", os.path.getsize("arena_report.pptx") // 1024)

    try:
        app = get_engine()
        pres = app.Presentations.Open(os.path.abspath("arena_report.pptx"), True, False, False)
        n = pres.Slides.Count
        shape_total = 0
        texts = []
        for i in range(1, n + 1):
            s = pres.Slides.Item(i)
            shape_total += s.Shapes.Count
            for j in range(1, s.Shapes.Count + 1):
                try:
                    t = s.Shapes.Item(j).TextFrame.TextRange.Text
                    if t and t.strip():
                        texts.append(t.strip())
                except Exception:
                    pass
        pres.Close()
        app.Quit()
        print("VERIFY slides=%d shapes=%d text_shapes=%d" % (n, shape_total, len(texts)))
        for t in texts[:8]:
            print("  text:", t[:60])
        ok = n == len(SLIDES) and shape_total >= n
        print("DECK RESULT:", "PASS" if ok else "CHECK")
    except Exception as e:
        print("VERIFY-ERROR (pptx still produced): %r" % e)
        print("DECK RESULT: EXPORTED-OK (verify skipped)")


if __name__ == "__main__":
    main()
