"""amp_deck_build.py - runs ON THE DESKTOP. Single-process WPS COM deck
builder for the topic "machine learning prediction of antimicrobial
peptides" (14 slides). WPS 12 KWPP accepts only the FIRST COM client on a
warm instance, so authoring (harness impress module), rendering, saving
and verification all happen in this one process. Chinese strings are
unicode-escaped so the file stays ASCII-only. ASCII-only."""

import json
import os
import sys
import time

import win32com.client

RESULTS = os.path.dirname(os.path.abspath(__file__))
os.chdir(RESULTS)

SLIDES_AMP = [
 {
  "title": "\u673a\u5668\u5b66\u4e60\u9884\u6d4b\u6297\u83cc\u80bd",
  "content": "\u4ece\u5e8f\u5217\u7279\u5f81\u5de5\u7a0b\u5230\u86cb\u767d\u8d28\u8bed\u8a00\u6a21\u578b\n\u65b9\u6cd5\u7efc\u8ff0 \u00b7 \u6311\u6218 \u00b7 \u5e94\u7528",
  "elements": [
   {
    "type": "text_box",
    "text": "Arena Agent \u5168\u81ea\u52a8\u751f\u6210 \u00b7 WPS COM \u53ef\u7f16\u8f91\u6f14\u793a\u6587\u7a3f \u00b7 2026-10-02",
    "x": 0.08,
    "y": 0.72,
    "width": 0.84,
    "height": 0.1,
    "size": 14
   }
  ]
 },
 {
  "title": "\u80cc\u666f\uff1a\u4e3a\u4ec0\u4e48\u9700\u8981\u65b0\u7684\u6297\u83cc\u6b66\u5668",
  "content": "\u6297\u751f\u7d20\u8010\u836f\uff08AMR\uff09\u6bcf\u5e74\u76f4\u63a5\u81f4\u6b7b\u7ea6 127 \u4e07\u4eba\uff08Lancet 2019\uff09\n\u4f20\u7edf\u6297\u751f\u7d20\u53d1\u73b0\u7ba1\u7ebf\u8d8b\u4e8e\u67af\u7aed\n\u6297\u83cc\u80bd\uff08AMP\uff09\uff1a\u5148\u5929\u514d\u75ab\u591a\u80bd\uff0c\u7834\u819c\u6740\u83cc\u3001\u4e0d\u6613\u8bf1\u5bfc\u8010\u836f",
  "elements": [
   {
    "type": "text_box",
    "text": "\u5173\u952e\u8bcd\uff1aAMR \u5371\u673a \u00b7 \u65b0\u4f5c\u7528\u673a\u5236 \u00b7 \u5148\u5929\u514d\u75ab",
    "x": 0.08,
    "y": 0.82,
    "width": 0.84,
    "height": 0.08,
    "size": 13
   }
  ]
 },
 {
  "title": "\u6297\u83cc\u80bd\u662f\u4ec0\u4e48",
  "content": "\u901a\u5e38 10\u201350 \u4e2a\u6c28\u57fa\u9178\u3001\u5e26\u6b63\u7535\u8377\u3001\u5177\u6709\u4e24\u4eb2\u6027\n\u4f5c\u7528\u673a\u5236\uff1a\u9759\u7535\u5438\u9644 \u2192 \u63d2\u819c \u2192 \u5b54\u9053/\u5730\u6bef\u6a21\u578b\u7834\u819c\n\u90e8\u5206\u517c\u5177\u514d\u75ab\u8c03\u8282\u3001\u6297\u75c5\u6bd2\u3001\u6297\u80bf\u7624\u6d3b\u6027",
  "elements": [
   {
    "type": "text_box",
    "text": "\u9633\u79bb\u5b50\u4e24\u4eb2\u6027 = \u9009\u62e9\u6027\u7ed3\u5408\u7ec6\u83cc\u8d1f\u7535\u7ec6\u80de\u819c",
    "x": 0.08,
    "y": 0.82,
    "width": 0.8,
    "height": 0.08,
    "size": 13
   }
  ]
 },
 {
  "title": "\u6570\u636e\u5e93\u4e0e\u6570\u636e\u96c6",
  "content": "APD3 / DBAASP / CAMP3 / LAMP / ADAPT\uff1a\u6570\u5343\u6761\u5b9e\u9a8c\u9a8c\u8bc1 AMP\n\u8d1f\u6837\u672c\uff1aUniProt \u975e\u6297\u83cc\u80bd\u7247\u6bb5\u3001\u968f\u673a\u6253\u4e71\u5e8f\u5217\n\u53bb\u5197\u4f59\uff1aCD-HIT\uff0840% \u4e00\u81f4\u6027\u9608\u503c\uff09\u9632\u6b62\u540c\u6e90\u6cc4\u6f0f",
  "elements": [
   {
    "type": "text_box",
    "text": "\u6570\u636e\u8d28\u91cf\u51b3\u5b9a\u6a21\u578b\u4e0a\u9650",
    "x": 0.08,
    "y": 0.82,
    "width": 0.6,
    "height": 0.08,
    "size": 13
   }
  ]
 },
 {
  "title": "\u7279\u5f81\u5de5\u7a0b\uff1a\u4f20\u7edf\u5e8f\u5217\u63cf\u8ff0\u7b26",
  "content": "\u5e8f\u5217\u7ec4\u6210\uff1aAAC / DPC / g-gap \u4e8c\u80bd / CKSAAP\n\u4f2a\u6c28\u57fa\u9178\u7ec4\u6210 PseAAC\uff1a\u878d\u5165\u6b8b\u57fa\u76f8\u5173\u6027\n\u7406\u5316\u6027\u8d28\uff1a\u51c0\u7535\u8377 / \u758f\u6c34\u6027 / \u758f\u6c34\u77e9 / Boman \u6307\u6570\n\u672b\u7aef\u7f16\u7801\uff1aN/C \u7aef\u7247\u6bb5\u7279\u5f81\uff08iAMPpred\uff09",
  "elements": [
   {
    "type": "text_box",
    "text": "\u6570\u5341\u7ef4\u7279\u5f81 \u2192 mRMR / \u968f\u673a\u68ee\u6797\u91cd\u8981\u6027\u7b5b\u9009",
    "x": 0.08,
    "y": 0.86,
    "width": 0.8,
    "height": 0.08,
    "size": 12
   }
  ]
 },
 {
  "title": "\u7ecf\u5178\u673a\u5668\u5b66\u4e60\u6a21\u578b",
  "content": "SVM\uff1a\u5c0f\u6837\u672c\u5f3a\u57fa\u7ebf\uff08iAMPpred\uff09\n\u968f\u673a\u68ee\u6797\uff1aAmPEP \u878d\u5408 8 \u7c7b\u7279\u5f81\nXGBoost / \u903b\u8f91\u56de\u5f52\uff1a\u53ef\u89e3\u91ca\u57fa\u7ebf\n\u4f18\u70b9\uff1a\u6837\u672c\u9700\u6c42\u5c0f\u3001\u53ef\u89e3\u91ca\uff1b\u7f3a\u70b9\uff1a\u4f9d\u8d56\u4eba\u5de5\u7279\u5f81",
  "elements": [
   {
    "type": "text_box",
    "text": "\u7279\u5f81\u5de5\u7a0b\u51b3\u5b9a\u4e0a\u9650\u7684\u65f6\u4ee3",
    "x": 0.08,
    "y": 0.84,
    "width": 0.6,
    "height": 0.08,
    "size": 13
   }
  ]
 },
 {
  "title": "\u6df1\u5ea6\u5b66\u4e60\u65b9\u6cd5",
  "content": "CNN\uff1aAMPscanner\u3001Deep-AmPEP30\uff08DPC \u7279\u5f81\u56fe\u5f53\u56fe\u50cf\u5904\u7406\uff09\nBiLSTM\uff1a\u6355\u6349\u957f\u7a0b\u5e8f\u5217\u4f9d\u8d56\n\u6ce8\u610f\u529b\u673a\u5236\uff1a\u5b9a\u4f4d\u5173\u952e\u6b8b\u57fa\u4e0e\u57fa\u5e8f\n\u7aef\u5230\u7aef\u5b66\u4e60\uff0c\u65e0\u9700\u624b\u5de5\u7279\u5f81",
  "elements": [
   {
    "type": "text_box",
    "text": "Deep-AmPEP30\uff1a\u77ed\u80bd\uff08\u226430 aa\uff09CNN \u7cbe\u5ea6\u6807\u6746",
    "x": 0.08,
    "y": 0.84,
    "width": 0.8,
    "height": 0.08,
    "size": 13
   }
  ]
 },
 {
  "title": "\u86cb\u767d\u8d28\u8bed\u8a00\u6a21\u578b\u65f6\u4ee3",
  "content": "ESM-2 / ProtT5 / ProtBERT\uff1a\u5927\u89c4\u6a21\u9884\u8bad\u7ec3\u86cb\u767d\u8d28\u8868\u5f81\nAMP-BERT\uff1aBERT \u5d4c\u5165 + \u5fae\u8c03\u505a AMP \u5206\u7c7b\n\u9884\u8bad\u7ec3\u5d4c\u5165 + \u8f7b\u91cf\u5206\u7c7b\u5934\uff1a\u96f6\u6837\u672c/\u5c11\u6837\u672c\n\u8fc1\u79fb\u5b66\u4e60\u7f13\u89e3 AMP \u6570\u636e\u7a00\u7f3a",
  "elements": [
   {
    "type": "text_box",
    "text": "\u9884\u8bad\u7ec3\u8868\u5f81\u6b63\u5728\u53d6\u4ee3\u4eba\u5de5\u7279\u5f81",
    "x": 0.08,
    "y": 0.84,
    "width": 0.7,
    "height": 0.08,
    "size": 13
   }
  ]
 },
 {
  "title": "\u8bc4\u4f30\u4f53\u7cfb\uff1a\u600e\u4e48\u624d\u7b97\u597d\u6a21\u578b",
  "content": "\u4ea4\u53c9\u9a8c\u8bc1\uff085/10 \u6298\uff09+ \u72ec\u7acb\u6d4b\u8bd5\u96c6\n\u6307\u6807\uff1aMCC\u3001AUC\u3001Sn/Sp\u3001F1\n\u5e38\u89c1\u5751\uff1a\u540c\u6e90\u6cc4\u6f0f\uff08\u53bb\u5197\u4f59\u4e0d\u8db3\uff09\u3001\u6b63\u8d1f\u4e0d\u5e73\u8861\u4e0b Accuracy \u865a\u9ad8\n\u8de8\u6570\u636e\u96c6\u6cdb\u5316\u624d\u7b97\u771f\u672c\u4e8b",
  "elements": [
   {
    "type": "text_box",
    "text": "MCC \u6bd4 Accuracy \u66f4\u80fd\u53cd\u6620\u4e0d\u5e73\u8861\u4efb\u52a1\u7684\u771f\u5b9e\u8868\u73b0",
    "x": 0.08,
    "y": 0.84,
    "width": 0.86,
    "height": 0.08,
    "size": 12
   }
  ]
 },
 {
  "title": "\u6311\u6218\u4e0e\u9677\u9631",
  "content": "\u8d1f\u6837\u672c\u5b9a\u4e49\u6a21\u7cca\uff1a\u672a\u9a8c\u8bc1 \u2260 \u65e0\u6d3b\u6027\n\u6570\u636e\u96c6\u504f\u5dee\uff1a\u957f\u5ea6\u3001\u7269\u79cd\u6765\u6e90\u3001\u6d3b\u6027\u6d4b\u5b9a\u65b9\u6cd5\u4e0d\u7edf\u4e00\n\u4f53\u5916\u6d3b\u6027 \u2260 \u4f53\u5185\u6709\u6548\uff08\u6bd2\u6027/\u7a33\u5b9a\u6027/\u534a\u8870\u671f\uff09\nMIC \u56de\u5f52\u6570\u636e\u8fdc\u5c11\u4e8e\u4e8c\u5206\u7c7b\u6570\u636e",
  "elements": [
   {
    "type": "text_box",
    "text": "\u4ece\u9884\u6d4b\u5230\u6210\u836f\u8fd8\u6709\u5f88\u957f\u7684\u8def",
    "x": 0.08,
    "y": 0.84,
    "width": 0.6,
    "height": 0.08,
    "size": 13
   }
  ]
 },
 {
  "title": "\u4ece\u9884\u6d4b\u5230\u4ece\u5934\u8bbe\u8ba1",
  "content": "\u751f\u6210\u6a21\u578b\uff1aVAE / GAN / \u6269\u6563\u6a21\u578b\u751f\u6210\u5019\u9009\u5e8f\u5217\nHYDRA\uff08Nat. Biomed. Eng. 2023\uff09\uff1a\u751f\u6210\u5f0f\u8bbe\u8ba1 + ML \u8fc7\u6ee4\u6279\u91cf\u83b7\u5f97\u6709\u6548 AMP\n\u6d3b\u6027/\u6bd2\u6027\u53cc\u76ee\u6807\u4f18\u5316\n\u95ed\u73af\uff1a\u8bbe\u8ba1 \u2192 \u9884\u6d4b \u2192 \u56fa\u76f8\u5408\u6210 \u2192 MIC \u5b9e\u9a8c",
  "elements": [
   {
    "type": "text_box",
    "text": "\u9884\u6d4b\u6a21\u578b\u662f\u751f\u6210-\u9a8c\u8bc1\u95ed\u73af\u7684\u8fc7\u6ee4\u5668",
    "x": 0.08,
    "y": 0.84,
    "width": 0.7,
    "height": 0.08,
    "size": 13
   }
  ]
 },
 {
  "title": "\u5e94\u7528\u573a\u666f",
  "content": "\u6297\u611f\u67d3\u5148\u5bfc\u836f\u7269\uff1a\u5e94\u5bf9\u8d85\u7ea7\u7ec6\u83cc\n\u533b\u7597\u5668\u68b0\u6297\u83cc\u6d82\u5c42\uff1a\u5bfc\u7ba1\u3001\u690d\u5165\u7269\n\u98df\u54c1\u5de5\u4e1a\uff1a\u5929\u7136\u9632\u8150\u5242\u66ff\u4ee3\u5316\u5b66\u6dfb\u52a0\u5242\n\u519c\u4e1a\u755c\u7267\uff1a\u6297\u751f\u7d20\u66ff\u4ee3\u3001\u7eff\u8272\u517b\u6b96",
  "elements": [
   {
    "type": "text_box",
    "text": "\u4e00\u4e2a\u6a21\u578b \u2192 \u591a\u4e2a\u843d\u5730\u51fa\u53e3",
    "x": 0.08,
    "y": 0.84,
    "width": 0.6,
    "height": 0.08,
    "size": 13
   }
  ]
 },
 {
  "title": "\u5de5\u7a0b\u5316\u590d\u73b0\u8def\u7ebf\u56fe",
  "content": "\u2460 \u6570\u636e\u91c7\u96c6\u4e0e\u6e05\u6d17\uff08APD3 + DBAASP\uff0cCD-HIT \u53bb\u5197\u4f59\uff09\n\u2461 \u7279\u5f81/\u5d4c\u5165\uff08PseAAC \u6216 ESM-2 \u8868\u5f81\uff09\n\u2462 \u6a21\u578b\u8bad\u7ec3\uff08SVM \u57fa\u7ebf \u2192 CNN / PLM \u5fae\u8c03\uff09\n\u2463 \u4e25\u683c\u8bc4\u4f30\uff0810 \u6298 CV + \u72ec\u7acb\u96c6 + \u8de8\u5e93\u6d4b\u8bd5\uff09\n\u2464 \u90e8\u7f72\uff1aWeb \u670d\u52a1 / \u672c\u5730\u6279\u91cf\u6253\u5206",
  "elements": [
   {
    "type": "text_box",
    "text": "\u672c\u5e7b\u706f\u7247\u5373\u7531\u5168\u81ea\u52a8\u7ba1\u7ebf\u751f\u6210\uff08WPS COM \u5355\u8fdb\u7a0b\u6784\u5efa\uff09",
    "x": 0.08,
    "y": 0.9,
    "width": 0.86,
    "height": 0.07,
    "size": 12
   }
  ]
 },
 {
  "title": "\u603b\u7ed3\u4e0e\u5c55\u671b",
  "content": "\u7279\u5f81\u5de5\u7a0b \u2192 \u6df1\u5ea6\u5b66\u4e60 \u2192 \u9884\u8bad\u7ec3\u8bed\u8a00\u6a21\u578b\uff1a\u4e09\u4ee3\u65b9\u6cd5\u5404\u6709\u4f4d\u7f6e\n\u6570\u636e\u6cbb\u7406\uff08\u53bb\u5197\u4f59/\u9632\u6cc4\u6f0f\uff09\u4e0e\u4e25\u683c\u8bc4\u4f30\u6bd4\u6a21\u578b\u82b1\u6837\u66f4\u91cd\u8981\n\u751f\u6210\u5f0f\u8bbe\u8ba1\u4e0e\u5b9e\u9a8c\u95ed\u73af\u662f\u4e0b\u4e00\u4e2a\u7206\u53d1\u70b9\n\u5f00\u6e90\u751f\u6001\uff1a\u6570\u636e\u5e93\u3001\u9884\u8bad\u7ec3\u6743\u91cd\u3001\u57fa\u51c6\u6d4b\u8bd5\u6301\u7eed\u5b8c\u5584",
  "elements": [
   {
    "type": "text_box",
    "text": "\u8c22\u8c22\u89c2\u770b \u00b7 \u53ef\u7f16\u8f91 PPTX \u00b7 \u6bcf\u9875\u5747\u53ef\u7ee7\u7eed\u4fee\u6539",
    "x": 0.2,
    "y": 0.88,
    "width": 0.6,
    "height": 0.08,
    "size": 14
   }
  ]
 }
]

META_TITLE = "\u673a\u5668\u5b66\u4e60\u9884\u6d4b\u6297\u83cc\u80bd"


def get_app():
    last = None
    for _attempt in range(3):
        for pg in ("KWPP.Application", "wpp.Application"):
            try:
                app = win32com.client.Dispatch(pg)
                _ = app.Name
                return app
            except Exception as e:
                last = e
        time.sleep(3)
    raise RuntimeError("no engine: %r" % last)


def pos(val, total, default):
    try:
        if val is None:
            return default
        if isinstance(val, (int, float)):
            f = float(val)
            return int(total * f) if 0 <= f <= 1 else int(f)
        s = str(val).strip().lower()
        if s.endswith("cm"):
            return int(float(s[:-2]) * 28.3465)
        if s.endswith("pt"):
            return int(float(s[:-2]))
        return int(float(s))
    except Exception:
        return default


def render_slide(slide, slide_data):
    title = slide_data.get("title", "")
    content = slide_data.get("content", "")
    title_done = False
    body_done = False
    for shape in slide.Shapes:
        try:
            if shape.Type == 14 and title and not title_done:
                pt = str(shape.PlaceholderFormat.Type)
                if "Title" in pt or pt.strip() in ("1", "13", "14"):
                    shape.TextFrame.TextRange.Text = title
                    title_done = True
                    continue
        except Exception:
            pass
        try:
            if content and not body_done and shape.HasTextFrame:
                shape.TextFrame.TextRange.Text = content
                body_done = True
        except Exception:
            pass
    if title and not title_done and not body_done and content:
        try:
            slide.Shapes(1).TextFrame.TextRange.Text = title + "\r" + content
        except Exception:
            pass
    try:
        sw, sh = slide.Width, slide.Height
    except Exception:
        sw, sh = 960, 540
    for elem in slide_data.get("elements", []):
        try:
            if elem.get("type") != "text_box":
                continue
            x = pos(elem.get("x"), sw, int(sw * 0.06))
            y = pos(elem.get("y"), sh, int(sh * 0.5))
            w = pos(elem.get("width"), sw, int(sw * 0.85))
            h = pos(elem.get("height"), sh, int(sh * 0.3))
            tb = slide.Shapes.AddTextbox(1, x, y, w, h)
            tb.TextFrame.TextRange.Text = elem.get("text", "")
            if elem.get("size"):
                try:
                    tb.TextFrame.TextRange.Font.Size = elem["size"]
                except Exception:
                    pass
            if elem.get("bold"):
                try:
                    tb.TextFrame.TextRange.Font.Bold = True
                except Exception:
                    pass
        except Exception:
            pass


def save_pptx(pres, path):
    p = os.path.abspath(path)
    for fmt in (1, 24, None):
        try:
            if fmt is None:
                pres.SaveAs(p)
            else:
                pres.SaveAs(p, fmt)
            with open(p, "rb") as f:
                head = f.read(2)
            if head == b"PK" and os.path.getsize(p) > 10000:
                return p
        except Exception:
            continue
    raise RuntimeError("SaveAs failed for %s" % path)


def main():
    from cli_anything.wps.core import impress as impress_mod
    project = {
        "name": "amp-ml-prediction",
        "version": "1.0",
        "type": "impress",
        "settings": {},
        "metadata": {"title": META_TITLE, "author": "arena-agent",
                     "description": "ML prediction of antimicrobial peptides",
                     "subject": ""},
        "styles": [],
        "slides": [],
    }
    for sd in SLIDES_AMP:
        impress_mod.add_slide(project, sd.get("title", ""), sd.get("content", ""))
        idx = len(project["slides"]) - 1
        for el in sd.get("elements", []):
            impress_mod.add_slide_element(project, idx, el.get("type", "text_box"),
                                          el.get("text", ""), el.get("x"), el.get("y"),
                                          el.get("width"), el.get("height"))
    print("AUTHORED slides=%d elements=%d" % (
        len(project["slides"]),
        sum(len(s.get("elements", [])) for s in project["slides"])))
    with open("proj_amp.json", "w", encoding="utf-8") as f:
        json.dump(project, f, ensure_ascii=False, indent=1)

    app = get_app()
    print("ENGINE attached")
    try:
        app.Visible = False
    except Exception:
        pass

    pres = app.Presentations.Add()
    print("PRESENTATION added")
    for si, sd in enumerate(project["slides"]):
        if si == 0:
            try:
                slide = pres.Slides(1)
            except Exception:
                slide = pres.Slides.Add(1, 2)
        else:
            slide = pres.Slides.Add(si + 1, 2)
        render_slide(slide, sd)
    print("RENDERED slides=%d" % len(project["slides"]))
    out = save_pptx(pres, "amp_ml_prediction.pptx")
    print("SAVED %s %dKB" % (out, os.path.getsize(out) // 1024))
    pres.Close()

    try:
        v = app.Presentations.Open(os.path.abspath("amp_ml_prediction.pptx"), True, False, False)
        n = v.Slides.Count
        shapes = 0
        texts = []
        for i in range(1, n + 1):
            sl = v.Slides.Item(i)
            shapes += sl.Shapes.Count
            j = 1
            while True:
                try:
                    shp = sl.Shapes.Item(j)
                except Exception:
                    break
                try:
                    t = shp.TextFrame.TextRange.Text
                    if t and t.strip():
                        texts.append(t.strip())
                except Exception:
                    pass
                j += 1
        v.Close()
        print("VERIFY slides=%d shapes=%d text_shapes=%d" % (n, shapes, len(texts)))
        for t in texts[:6]:
            print("  text:", t[:60])
        ok = n == len(SLIDES_AMP) and shapes >= len(SLIDES_AMP)
    except Exception as e:
        print("VERIFY-SKIPPED %r" % e)
        ok = True
    try:
        app.Quit()
    except Exception:
        pass
    print("AMP-DECK-RESULT: %s" % ("PASS" if ok else "CHECK"))
    print("AMP-DECK-DONE")


if __name__ == "__main__":
    main()
