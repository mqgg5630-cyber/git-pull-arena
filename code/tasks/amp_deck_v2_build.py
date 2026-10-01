"""amp_deck_v2_build.py - runs ON THE DESKTOP. DESIGNED edition of the
"ML prediction of antimicrobial peptides" deck: every slide gets a color
system (left accent bar, footer strip, page badge) plus REAL graphic
elements built from native WPS COM shapes - stat cards, a membrane
mechanism diagram, tables, a model pipeline, a confusion matrix, a
design-build-test loop, chevron roadmap. All elements remain editable.
Single-process first-client pattern (WPS 12 KWPP quirk). ASCII-only."""

import json
import os
import sys
import time

import win32com.client

RESULTS = os.path.dirname(os.path.abspath(__file__))
os.chdir(RESULTS)

SLIDES_V2 = [
 {
  "title": "\u673a\u5668\u5b66\u4e60\u9884\u6d4b\u6297\u83cc\u80bd",
  "content": "\u4ece\u5e8f\u5217\u7279\u5f81\u5de5\u7a0b\u5230\u86cb\u767d\u8d28\u8bed\u8a00\u6a21\u578b",
  "ops": [
   {
    "t": "sh",
    "s": 9,
    "x": 0.7,
    "y": 0.05,
    "w": 0.42,
    "h": 0.42,
    "f": [
     222,
     235,
     247
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 9,
    "x": 0.8,
    "y": 0.18,
    "w": 0.3,
    "h": 0.3,
    "f": [
     222,
     235,
     247
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 9,
    "x": 0.63,
    "y": 0.24,
    "w": 0.22,
    "h": 0.22,
    "f": [
     222,
     235,
     247
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.06,
    "y": 0.62,
    "w": 0.5,
    "h": 0.13,
    "f": [
     31,
     78,
     121
    ],
    "tx": "\u65b9\u6cd5\u7efc\u8ff0 \u00b7 \u6311\u6218 \u00b7 \u5e94\u7528",
    "sz": 16,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.06,
    "y": 0.8,
    "w": 0.88,
    "h": 0.1,
    "f": [
     242,
     246,
     250
    ],
    "tx": "Arena Agent \u5168\u81ea\u52a8\u751f\u6210 \u00b7 WPS COM \u539f\u751f\u56fe\u5f62 \u00b7 \u6bcf\u4e2a\u5143\u7d20\u5747\u53ef\u7f16\u8f91",
    "sz": 12,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   }
  ]
 },
 {
  "title": "\u80cc\u666f\uff1a\u4e3a\u4ec0\u4e48\u9700\u8981\u65b0\u7684\u6297\u83cc\u6b66\u5668",
  "content": "\u6297\u751f\u7d20\u8010\u836f\uff08AMR\uff09\u5a01\u80c1\u6301\u7eed\u5347\u7ea7\n\u4f20\u7edf\u6297\u751f\u7d20\u53d1\u73b0\u7ba1\u7ebf\u8d8b\u4e8e\u67af\u7aed",
  "ops": [
   {
    "t": "sh",
    "s": 5,
    "x": 0.06,
    "y": 0.52,
    "w": 0.27,
    "h": 0.36,
    "f": [
     192,
     57,
     43
    ],
    "tx": "127 \u4e07\n\u6bcf\u5e74 AMR \u76f4\u63a5\u6b7b\u4ea1\n\uff08Lancet 2019\uff09",
    "sz": 16,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.355,
    "y": 0.52,
    "w": 0.27,
    "h": 0.36,
    "f": [
     237,
     125,
     49
    ],
    "tx": "\u7ba1\u7ebf\u67af\u7aed\n\u65b0\u6297\u751f\u7d20\u53d1\u73b0\n\u8d8a\u6765\u8d8a\u5c11",
    "sz": 16,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.65,
    "y": 0.52,
    "w": 0.29,
    "h": 0.36,
    "f": [
     0,
     140,
     140
    ],
    "tx": "AMP \u673a\u4f1a\n\u5148\u5929\u514d\u75ab\u591a\u80bd\n\u7834\u819c\u6740\u83cc \u00b7 \u4e0d\u6613\u8010\u836f",
    "sz": 16,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   }
  ]
 },
 {
  "title": "\u6297\u83cc\u80bd\u662f\u4ec0\u4e48",
  "content": "\u901a\u5e38 10\u201350 aa \u00b7 \u5e26\u6b63\u7535\u8377 \u00b7 \u4e24\u4eb2\u6027\n\u9759\u7535\u5438\u9644\u7ec6\u83cc\u8d1f\u7535\u819c \u2192 \u63d2\u819c \u2192 \u7834\u819c",
  "ops": [
   {
    "t": "sh",
    "s": 1,
    "x": 0.06,
    "y": 0.66,
    "w": 0.3,
    "h": 0.05,
    "f": [
     200,
     208,
     216
    ],
    "tx": "\u7ec6\u83cc\u7ec6\u80de\u819c\uff08\u5e26\u8d1f\u7535\uff09",
    "sz": 11,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 9,
    "x": 0.1,
    "y": 0.55,
    "w": 0.05,
    "h": 0.05,
    "f": [
     0,
     140,
     140
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 9,
    "x": 0.16,
    "y": 0.55,
    "w": 0.05,
    "h": 0.05,
    "f": [
     0,
     140,
     140
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 9,
    "x": 0.22,
    "y": 0.55,
    "w": 0.05,
    "h": 0.05,
    "f": [
     0,
     140,
     140
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 34,
    "x": 0.11,
    "y": 0.6,
    "w": 0.03,
    "h": 0.06,
    "f": [
     0,
     140,
     140
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 34,
    "x": 0.17,
    "y": 0.6,
    "w": 0.03,
    "h": 0.06,
    "f": [
     0,
     140,
     140
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 34,
    "x": 0.23,
    "y": 0.6,
    "w": 0.03,
    "h": 0.06,
    "f": [
     0,
     140,
     140
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.42,
    "y": 0.55,
    "w": 0.24,
    "h": 0.1,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u6876\u677f\u6a21\u578b Barrel-stave",
    "sz": 12,
    "fc": [
     31,
     78,
     121
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.42,
    "y": 0.67,
    "w": 0.24,
    "h": 0.1,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u73af\u5b54\u6a21\u578b Toroidal",
    "sz": 12,
    "fc": [
     31,
     78,
     121
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.42,
    "y": 0.79,
    "w": 0.24,
    "h": 0.1,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u5730\u6bef\u6a21\u578b Carpet",
    "sz": 12,
    "fc": [
     31,
     78,
     121
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.7,
    "y": 0.55,
    "w": 0.24,
    "h": 0.34,
    "f": [
     242,
     246,
     250
    ],
    "tx": "\u9644\u52a0\u6d3b\u6027\n\u514d\u75ab\u8c03\u8282\n\u6297\u75c5\u6bd2\n\u6297\u80bf\u7624",
    "sz": 13,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   }
  ]
 },
 {
  "title": "\u6570\u636e\u5e93\u4e0e\u6570\u636e\u96c6",
  "content": "\u6b63\u6837\u672c\uff1a\u5b9e\u9a8c\u9a8c\u8bc1 AMP\uff1b\u8d1f\u6837\u672c\uff1a\u975e\u6297\u83cc\u80bd\u7247\u6bb5 / \u6253\u4e71\u5e8f\u5217",
  "ops": [
   {
    "t": "tb",
    "x": 0.06,
    "y": 0.42,
    "w": 0.88,
    "h": 0.48,
    "rows": [
     [
      "\u6570\u636e\u5e93",
      "\u5b9a\u4f4d",
      "\u7279\u8272"
     ],
     [
      "APD3",
      "\u5929\u7136 AMP \u767e\u79d1\u5f0f\u6536\u5f55",
      "\u6ce8\u91ca\u8be6\u5c3d \u00b7 \u957f\u5ea6/\u6d3b\u6027\u6807\u6ce8"
     ],
     [
      "DBAASP",
      "\u7ed3\u6784\u4e0e\u6d3b\u6027\u6570\u636e",
      "MIC/\u76d0\u7a33\u5b9a\u6027\u7b49\u5b9e\u9a8c\u53c2\u6570\u6700\u5168"
     ],
     [
      "CAMP3",
      "\u591a\u5bb6\u65cf\u591a\u7269\u79cd",
      "\u5bb6\u65cf\u5206\u7c7b + \u9884\u6d4b\u5de5\u5177\u94fe\u63a5"
     ],
     [
      "LAMP",
      "\u7efc\u5408\u6570\u636e\u5e93",
      "\u8986\u76d6\u9762\u5e7f \u00b7 \u5b9a\u671f\u66f4\u65b0"
     ],
     [
      "ADAPT",
      "\u529f\u80fd\u6807\u6ce8\u5e93",
      "\u6d3b\u6027/\u6bd2\u6027\u6807\u7b7e\u4e30\u5bcc"
     ]
    ],
    "colw": [
     0.18,
     0.34,
     0.48
    ],
    "sz": 12,
    "header": True
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.06,
    "y": 0.3,
    "w": 0.88,
    "h": 0.09,
    "f": [
     237,
     125,
     49
    ],
    "tx": "\u53bb\u5197\u4f59\uff1aCD-HIT\uff0840% \u4e00\u81f4\u6027\uff09\u9632\u6b62\u540c\u6e90\u5e8f\u5217\u6cc4\u6f0f\u5230\u6d4b\u8bd5\u96c6",
    "sz": 12,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   }
  ]
 },
 {
  "title": "\u7279\u5f81\u5de5\u7a0b\uff1a\u5e8f\u5217\u63cf\u8ff0\u7b26",
  "content": "\u6570\u5341\u7ef4\u624b\u5de5\u7279\u5f81 \u2192 \u91cd\u8981\u6027\u7b5b\u9009\uff08mRMR / RF importance\uff09",
  "ops": [
   {
    "t": "sh",
    "s": 5,
    "x": 0.06,
    "y": 0.42,
    "w": 0.42,
    "h": 0.22,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u7ec4\u6210\u7279\u5f81\nAAC \u00b7 DPC \u00b7 g-gap \u4e8c\u80bd \u00b7 CKSAAP",
    "sz": 13,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.51,
    "y": 0.42,
    "w": 0.43,
    "h": 0.22,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u4f2a\u6c28\u57fa\u9178\u7ec4\u6210 PseAAC\n\u878d\u5165\u6b8b\u57fa\u76f8\u5173\u6027\u4e0e\u7406\u5316\u79bb\u6563\u5ea6",
    "sz": 13,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.06,
    "y": 0.68,
    "w": 0.42,
    "h": 0.22,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u7406\u5316\u6027\u8d28\n\u51c0\u7535\u8377 \u00b7 \u758f\u6c34\u6027 \u00b7 \u758f\u6c34\u77e9 \u00b7 Boman \u6307\u6570",
    "sz": 13,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.51,
    "y": 0.68,
    "w": 0.43,
    "h": 0.22,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u672b\u7aef\u7f16\u7801\uff08iAMPpred\uff09\nN/C \u7aef\u7247\u6bb5\u7279\u5f81\u6355\u6349\u5c40\u90e8 motif",
    "sz": 13,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   }
  ]
 },
 {
  "title": "\u7ecf\u5178\u673a\u5668\u5b66\u4e60\u6a21\u578b",
  "content": "\u5c0f\u6837\u672c\u53cb\u597d \u00b7 \u53ef\u89e3\u91ca \u00b7 \u4e0a\u9650\u53d6\u51b3\u4e8e\u4eba\u5de5\u7279\u5f81",
  "ops": [
   {
    "t": "tb",
    "x": 0.06,
    "y": 0.4,
    "w": 0.88,
    "h": 0.5,
    "rows": [
     [
      "\u6a21\u578b",
      "\u4ee3\u8868\u5de5\u4f5c",
      "\u7279\u5f81",
      "\u7279\u70b9"
     ],
     [
      "SVM",
      "iAMPpred",
      "\u672b\u7aef + \u7406\u5316",
      "\u5c0f\u6837\u672c\u5f3a\u57fa\u7ebf"
     ],
     [
      "\u968f\u673a\u68ee\u6797",
      "AmPEP",
      "8 \u7c7b\u7279\u5f81\u878d\u5408",
      "\u6297\u8fc7\u62df\u5408"
     ],
     [
      "XGBoost",
      "\u591a\u7528\u4e8e MIC \u56de\u5f52",
      "\u68af\u5ea6\u63d0\u5347",
      "\u7279\u5f81\u91cd\u8981\u6027\u53ef\u8bfb"
     ],
     [
      "\u903b\u8f91\u56de\u5f52",
      "\u901a\u7528\u57fa\u7ebf",
      "\u4efb\u610f\u63cf\u8ff0\u7b26",
      "\u6700\u53ef\u89e3\u91ca"
     ]
    ],
    "colw": [
     0.16,
     0.24,
     0.28,
     0.32
    ],
    "sz": 12,
    "header": True
   }
  ]
 },
 {
  "title": "\u6df1\u5ea6\u5b66\u4e60\u65b9\u6cd5",
  "content": "\u7aef\u5230\u7aef\u5b66\u4e60\uff0c\u65e0\u9700\u624b\u5de5\u7279\u5f81\uff08Deep-AmPEP30\uff1a\u77ed\u80bd CNN \u6807\u6746\uff09",
  "ops": [
   {
    "t": "sh",
    "s": 5,
    "x": 0.06,
    "y": 0.52,
    "w": 0.15,
    "h": 0.22,
    "f": [
     31,
     78,
     121
    ],
    "tx": "\u5e8f\u5217\n\u8f93\u5165",
    "sz": 14,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 33,
    "x": 0.215,
    "y": 0.6,
    "w": 0.035,
    "h": 0.06,
    "f": [
     31,
     78,
     121
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.255,
    "y": 0.52,
    "w": 0.15,
    "h": 0.22,
    "f": [
     0,
     140,
     140
    ],
    "tx": "\u7f16\u7801\nOne-hot/DPC",
    "sz": 13,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 33,
    "x": 0.41,
    "y": 0.6,
    "w": 0.035,
    "h": 0.06,
    "f": [
     31,
     78,
     121
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.45,
    "y": 0.52,
    "w": 0.15,
    "h": 0.22,
    "f": [
     0,
     140,
     140
    ],
    "tx": "CNN /\nBiLSTM",
    "sz": 14,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 33,
    "x": 0.605,
    "y": 0.6,
    "w": 0.035,
    "h": 0.06,
    "f": [
     31,
     78,
     121
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.645,
    "y": 0.52,
    "w": 0.15,
    "h": 0.22,
    "f": [
     108,
     78,
     158
    ],
    "tx": "\u6ce8\u610f\u529b\n\u5b9a\u4f4d\u5173\u952e\u6b8b\u57fa",
    "sz": 12,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 33,
    "x": 0.8,
    "y": 0.6,
    "w": 0.035,
    "h": 0.06,
    "f": [
     31,
     78,
     121
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.84,
    "y": 0.52,
    "w": 0.1,
    "h": 0.22,
    "f": [
     39,
     144,
     86
    ],
    "tx": "AMP\n\u5224\u5b9a",
    "sz": 14,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.06,
    "y": 0.8,
    "w": 0.88,
    "h": 0.1,
    "f": [
     242,
     246,
     250
    ],
    "tx": "\u4ee3\u8868\uff1aAMPscanner\uff08CNN\uff09 \u00b7 Deep-AmPEP30\uff08\u226430 aa \u77ed\u80bd\uff09 \u00b7 \u53cc\u5411 LSTM \u53d8\u4f53",
    "sz": 12,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   }
  ]
 },
 {
  "title": "\u86cb\u767d\u8d28\u8bed\u8a00\u6a21\u578b\u65f6\u4ee3",
  "content": "\u9884\u8bad\u7ec3\u8868\u5f81\u6b63\u5728\u53d6\u4ee3\u4eba\u5de5\u7279\u5f81",
  "ops": [
   {
    "t": "sh",
    "s": 1,
    "x": 0.1,
    "y": 0.5,
    "w": 0.36,
    "h": 0.13,
    "f": [
     31,
     78,
     121
    ],
    "tx": "ESM-2 / ProtT5 / ProtBERT\n\uff08\u6d77\u91cf\u5e8f\u5217\u81ea\u76d1\u7763\u9884\u8bad\u7ec3\uff09",
    "sz": 13,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 1,
    "x": 0.1,
    "y": 0.65,
    "w": 0.36,
    "h": 0.13,
    "f": [
     0,
     140,
     140
    ],
    "tx": "AMP \u6807\u6ce8\u5fae\u8c03\uff08AMP-BERT \u7b49\uff09",
    "sz": 13,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 1,
    "x": 0.1,
    "y": 0.8,
    "w": 0.36,
    "h": 0.13,
    "f": [
     39,
     144,
     86
    ],
    "tx": "\u5206\u7c7b\u5934 \u2192 AMP \u6982\u7387 / \u6d3b\u6027\u6253\u5206",
    "sz": 13,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.52,
    "y": 0.5,
    "w": 0.42,
    "h": 0.14,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u5c11\u6837\u672c / \u96f6\u6837\u672c\n\u51bb\u7ed3 PLM \u53ea\u8bad\u7ec3\u8f7b\u91cf\u5934",
    "sz": 13,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.52,
    "y": 0.66,
    "w": 0.42,
    "h": 0.14,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u8fc1\u79fb\u5b66\u4e60\n\u7f13\u89e3 AMP \u6570\u636e\u7a00\u7f3a",
    "sz": 13,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.52,
    "y": 0.82,
    "w": 0.42,
    "h": 0.11,
    "f": [
     242,
     246,
     250
    ],
    "tx": "\u5d4c\u5165\u53ef\u590d\u7528\uff1a\u805a\u7c7b \u00b7 \u53ef\u89c6\u5316 \u00b7 \u751f\u6210",
    "sz": 12,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   }
  ]
 },
 {
  "title": "\u8bc4\u4f30\u4f53\u7cfb\uff1a\u600e\u4e48\u624d\u7b97\u597d\u6a21\u578b",
  "content": "\u4ea4\u53c9\u9a8c\u8bc1\uff085/10 \u6298\uff09+ \u72ec\u7acb\u6d4b\u8bd5\u96c6 + \u8de8\u5e93\u6cdb\u5316",
  "ops": [
   {
    "t": "tb",
    "x": 0.06,
    "y": 0.4,
    "w": 0.38,
    "h": 0.42,
    "rows": [
     [
      "",
      "\u9884\u6d4b AMP",
      "\u9884\u6d4b\u975e AMP"
     ],
     [
      "\u5b9e\u9645 AMP",
      "TP",
      "FN"
     ],
     [
      "\u5b9e\u9645\u975e AMP",
      "FP",
      "TN"
     ]
    ],
    "colw": [
     0.34,
     0.33,
     0.33
    ],
    "sz": 12,
    "header": True
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.5,
    "y": 0.4,
    "w": 0.2,
    "h": 0.12,
    "f": [
     0,
     140,
     140
    ],
    "tx": "Sn \u7075\u654f\u5ea6",
    "sz": 13,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.72,
    "y": 0.4,
    "w": 0.22,
    "h": 0.12,
    "f": [
     0,
     140,
     140
    ],
    "tx": "Sp \u7279\u5f02\u5ea6",
    "sz": 13,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.5,
    "y": 0.55,
    "w": 0.2,
    "h": 0.12,
    "f": [
     31,
     78,
     121
    ],
    "tx": "MCC\uff08\u9996\u9009\uff09",
    "sz": 13,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.72,
    "y": 0.55,
    "w": 0.22,
    "h": 0.12,
    "f": [
     31,
     78,
     121
    ],
    "tx": "AUC",
    "sz": 13,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.5,
    "y": 0.7,
    "w": 0.44,
    "h": 0.2,
    "f": [
     237,
     125,
     49
    ],
    "tx": "\u5e38\u89c1\u5751\uff1a\u4e0d\u5e73\u8861\u6570\u636e Accuracy \u865a\u9ad8 \u00b7\n\u53bb\u5197\u4f59\u4e0d\u8db3 \u2192 \u540c\u6e90\u6cc4\u6f0f \u2192 \u9ad8\u4f30\u6027\u80fd",
    "sz": 12,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   }
  ]
 },
 {
  "title": "\u6311\u6218\u4e0e\u9677\u9631",
  "content": "\u4ece\u9884\u6d4b\u5230\u6210\u836f\u8fd8\u6709\u5f88\u957f\u7684\u8def",
  "ops": [
   {
    "t": "sh",
    "s": 7,
    "x": 0.08,
    "y": 0.47,
    "w": 0.06,
    "h": 0.08,
    "f": [
     237,
     125,
     49
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.16,
    "y": 0.44,
    "w": 0.3,
    "h": 0.14,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u8d1f\u6837\u672c\u5b9a\u4e49\u6a21\u7cca\n\u672a\u9a8c\u8bc1 \u2260 \u65e0\u6d3b\u6027",
    "sz": 12,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 7,
    "x": 0.52,
    "y": 0.47,
    "w": 0.06,
    "h": 0.08,
    "f": [
     237,
     125,
     49
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.6,
    "y": 0.44,
    "w": 0.34,
    "h": 0.14,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u6570\u636e\u96c6\u504f\u5dee\n\u957f\u5ea6/\u7269\u79cd/\u6d4b\u5b9a\u65b9\u6cd5\u4e0d\u7edf\u4e00",
    "sz": 12,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 7,
    "x": 0.08,
    "y": 0.7,
    "w": 0.06,
    "h": 0.08,
    "f": [
     192,
     57,
     43
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.16,
    "y": 0.67,
    "w": 0.3,
    "h": 0.14,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u4f53\u5916 \u2260 \u4f53\u5185\n\u6bd2\u6027 \u00b7 \u7a33\u5b9a\u6027 \u00b7 \u534a\u8870\u671f",
    "sz": 12,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 7,
    "x": 0.52,
    "y": 0.7,
    "w": 0.06,
    "h": 0.08,
    "f": [
     192,
     57,
     43
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.6,
    "y": 0.67,
    "w": 0.34,
    "h": 0.14,
    "f": [
     222,
     235,
     247
    ],
    "tx": "MIC \u56de\u5f52\u6570\u636e\u7a00\u7f3a\n\u8fdc\u5c11\u4e8e\u4e8c\u5206\u7c7b\u6807\u6ce8",
    "sz": 12,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   }
  ]
 },
 {
  "title": "\u4ece\u9884\u6d4b\u5230\u4ece\u5934\u8bbe\u8ba1",
  "content": "HYDRA\uff08Nat. Biomed. Eng. 2023\uff09\uff1a\u751f\u6210\u5f0f\u8bbe\u8ba1 + ML \u8fc7\u6ee4\u6279\u91cf\u83b7\u5f97\u6709\u6548 AMP",
  "ops": [
   {
    "t": "sh",
    "s": 5,
    "x": 0.08,
    "y": 0.48,
    "w": 0.2,
    "h": 0.14,
    "f": [
     108,
     78,
     158
    ],
    "tx": "\u751f\u6210\u6a21\u578b\u8bbe\u8ba1\nVAE \u00b7 GAN \u00b7 \u6269\u6563",
    "sz": 12,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.38,
    "y": 0.48,
    "w": 0.2,
    "h": 0.14,
    "f": [
     31,
     78,
     121
    ],
    "tx": "ML \u9884\u6d4b\u8fc7\u6ee4\n\u6d3b\u6027 \u00b7 \u6bd2\u6027\u53cc\u76ee\u6807",
    "sz": 12,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.68,
    "y": 0.48,
    "w": 0.24,
    "h": 0.14,
    "f": [
     0,
     140,
     140
    ],
    "tx": "\u56fa\u76f8\u5408\u6210",
    "sz": 12,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.38,
    "y": 0.78,
    "w": 0.54,
    "h": 0.14,
    "f": [
     39,
     144,
     86
    ],
    "tx": "MIC \u5b9e\u9a8c\u9a8c\u8bc1 \u2192 \u53cd\u9988\u8fed\u4ee3",
    "sz": 12,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 34,
    "x": 0.285,
    "y": 0.53,
    "w": 0.09,
    "h": 0.04,
    "f": [
     51,
     51,
     51
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 33,
    "x": 0.585,
    "y": 0.53,
    "w": 0.09,
    "h": 0.04,
    "f": [
     51,
     51,
     51
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 34,
    "x": 0.78,
    "y": 0.62,
    "w": 0.04,
    "h": 0.16,
    "f": [
     51,
     51,
     51
    ],
    "tx": "",
    "sz": 10,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 9,
    "x": 0.16,
    "y": 0.66,
    "w": 0.1,
    "h": 0.1,
    "f": [
     237,
     125,
     49
    ],
    "tx": "\u95ed\u73af",
    "sz": 11,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   }
  ]
 },
 {
  "title": "\u5e94\u7528\u573a\u666f",
  "content": "\u4e00\u4e2a\u6a21\u578b \u2192 \u591a\u4e2a\u843d\u5730\u51fa\u53e3",
  "ops": [
   {
    "t": "sh",
    "s": 1,
    "x": 0.06,
    "y": 0.46,
    "w": 0.42,
    "h": 0.045,
    "f": [
     31,
     78,
     121
    ],
    "tx": "",
    "sz": 8,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.06,
    "y": 0.505,
    "w": 0.42,
    "h": 0.17,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u6297\u611f\u67d3\u5148\u5bfc\u836f\u7269\n\u5e94\u5bf9\u8d85\u7ea7\u7ec6\u83cc",
    "sz": 13,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 1,
    "x": 0.51,
    "y": 0.46,
    "w": 0.42,
    "h": 0.045,
    "f": [
     0,
     140,
     140
    ],
    "tx": "",
    "sz": 8,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.51,
    "y": 0.505,
    "w": 0.43,
    "h": 0.17,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u533b\u7597\u5668\u68b0\u6297\u83cc\u6d82\u5c42\n\u5bfc\u7ba1 \u00b7 \u690d\u5165\u7269",
    "sz": 13,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 1,
    "x": 0.06,
    "y": 0.72,
    "w": 0.42,
    "h": 0.045,
    "f": [
     39,
     144,
     86
    ],
    "tx": "",
    "sz": 8,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.06,
    "y": 0.765,
    "w": 0.42,
    "h": 0.17,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u98df\u54c1\u5de5\u4e1a\n\u5929\u7136\u9632\u8150\u5242\u66ff\u4ee3\u5316\u5b66\u54c1",
    "sz": 13,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 1,
    "x": 0.51,
    "y": 0.72,
    "w": 0.43,
    "h": 0.045,
    "f": [
     237,
     125,
     49
    ],
    "tx": "",
    "sz": 8,
    "fc": [
     255,
     255,
     255
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.51,
    "y": 0.765,
    "w": 0.43,
    "h": 0.17,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u519c\u4e1a\u755c\u7267\n\u6297\u751f\u7d20\u66ff\u4ee3 \u00b7 \u7eff\u8272\u517b\u6b96",
    "sz": 13,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   }
  ]
 },
 {
  "title": "\u5de5\u7a0b\u5316\u590d\u73b0\u8def\u7ebf\u56fe",
  "content": "\u53ef\u843d\u5730\u7684\u4e94\u6b65\u95ed\u73af",
  "ops": [
   {
    "t": "sh",
    "s": 52,
    "x": 0.05,
    "y": 0.5,
    "w": 0.19,
    "h": 0.2,
    "f": [
     31,
     78,
     121
    ],
    "tx": "\u2460 \u6570\u636e\nAPD3+DBAASP\nCD-HIT \u53bb\u5197\u4f59",
    "sz": 11,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 52,
    "x": 0.23,
    "y": 0.5,
    "w": 0.19,
    "h": 0.2,
    "f": [
     0,
     140,
     140
    ],
    "tx": "\u2461 \u7279\u5f81\nPseAAC \u6216\nESM-2 \u5d4c\u5165",
    "sz": 11,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 52,
    "x": 0.41,
    "y": 0.5,
    "w": 0.19,
    "h": 0.2,
    "f": [
     108,
     78,
     158
    ],
    "tx": "\u2462 \u6a21\u578b\nSVM \u57fa\u7ebf \u2192\nCNN / PLM \u5fae\u8c03",
    "sz": 11,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 52,
    "x": 0.59,
    "y": 0.5,
    "w": 0.19,
    "h": 0.2,
    "f": [
     39,
     144,
     86
    ],
    "tx": "\u2463 \u8bc4\u4f30\n10 \u6298 CV +\n\u72ec\u7acb\u96c6 + \u8de8\u5e93",
    "sz": 11,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 52,
    "x": 0.77,
    "y": 0.5,
    "w": 0.18,
    "h": 0.2,
    "f": [
     237,
     125,
     49
    ],
    "tx": "\u2464 \u90e8\u7f72\nWeb \u670d\u52a1 /\n\u6279\u91cf\u6253\u5206",
    "sz": 11,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.05,
    "y": 0.78,
    "w": 0.9,
    "h": 0.1,
    "f": [
     242,
     246,
     250
    ],
    "tx": "\u672c\u5e7b\u706f\u7247\u7531\u5168\u81ea\u52a8\u7ba1\u7ebf\u751f\u6210\uff1aWPS COM \u539f\u751f\u56fe\u5f62\uff08\u5f62\u72b6/\u8868\u683c/\u7bad\u5934\uff09\uff0c\u5168\u90e8\u53ef\u7f16\u8f91",
    "sz": 12,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   }
  ]
 },
 {
  "title": "\u603b\u7ed3\u4e0e\u5c55\u671b",
  "content": "",
  "ops": [
   {
    "t": "sh",
    "s": 5,
    "x": 0.06,
    "y": 0.16,
    "w": 0.27,
    "h": 0.3,
    "f": [
     31,
     78,
     121
    ],
    "tx": "\u4e09\u4ee3\u65b9\u6cd5\n\u5404\u6709\u4f4d\u7f6e\n\u7279\u5f81\u2192\u6df1\u5ea6\u2192PLM",
    "sz": 15,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.355,
    "y": 0.16,
    "w": 0.27,
    "h": 0.3,
    "f": [
     0,
     140,
     140
    ],
    "tx": "\u6570\u636e\u6cbb\u7406\n\u4e0e\u4e25\u683c\u8bc4\u4f30\n\u6bd4\u6a21\u578b\u82b1\u6837\u91cd\u8981",
    "sz": 15,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.65,
    "y": 0.16,
    "w": 0.29,
    "h": 0.3,
    "f": [
     237,
     125,
     49
    ],
    "tx": "\u751f\u6210\u5f0f\u8bbe\u8ba1\n+ \u5b9e\u9a8c\u95ed\u73af\n\u4e0b\u4e00\u4e2a\u7206\u53d1\u70b9",
    "sz": 15,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.06,
    "y": 0.55,
    "w": 0.88,
    "h": 0.13,
    "f": [
     222,
     235,
     247
    ],
    "tx": "\u5f00\u6e90\u751f\u6001\u6301\u7eed\u5b8c\u5584\uff1a\u6570\u636e\u5e93 \u00b7 \u9884\u8bad\u7ec3\u6743\u91cd \u00b7 \u57fa\u51c6\u6d4b\u8bd5",
    "sz": 14,
    "fc": [
     51,
     51,
     51
    ],
    "b": 0
   },
   {
    "t": "sh",
    "s": 5,
    "x": 0.2,
    "y": 0.75,
    "w": 0.6,
    "h": 0.14,
    "f": [
     31,
     78,
     121
    ],
    "tx": "\u8c22\u8c22\u89c2\u770b \u00b7 \u53ef\u7f16\u8f91 PPTX",
    "sz": 18,
    "fc": [
     255,
     255,
     255
    ],
    "b": 1
   }
  ]
 }
]

META_TITLE = "\u673a\u5668\u5b66\u4e60\u9884\u6d4b\u6297\u83cc\u80bd"

PRIMARY = (31, 78, 121)
LIGHT = (242, 246, 250)
WHITE = (255, 255, 255)
DARK = (51, 51, 51)


def rgb(t):
    return int(t[0]) + int(t[1]) * 256 + int(t[2]) * 65536


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


def px(v, total, default):
    try:
        if v is None:
            return default
        f = float(v)
        if 0 <= f <= 1:
            return int(total * f)
        return int(f)
    except Exception:
        return default


def style_text(rng, size, color, bold, align):
    try:
        rng.Font.Size = size
    except Exception:
        pass
    try:
        rng.Font.Color.RGB = rgb(color)
    except Exception:
        pass
    try:
        rng.Font.Bold = bold
    except Exception:
        pass
    try:
        rng.Font.Name = "Microsoft YaHei"
    except Exception:
        pass
    try:
        rng.ParagraphFormat.Alignment = align
    except Exception:
        pass


def add_shape(slide, sw, sh_, op):
    try:
        x = px(op.get("x"), sw, 40)
        y = px(op.get("y"), sh_, 40)
        w = px(op.get("w"), sw, 100)
        h = px(op.get("h"), sh_, 40)
        sp = slide.Shapes.AddShape(int(op["s"]), x, y, w, h)
        try:
            sp.Fill.Solid()
            sp.Fill.ForeColor.RGB = rgb(op.get("f") or PRIMARY)
        except Exception:
            pass
        try:
            sp.Line.Visible = 0
        except Exception:
            pass
        tx = op.get("tx", "")
        if tx:
            try:
                tf = sp.TextFrame
                tf.TextRange.Text = tx
                style_text(tf.TextRange, op.get("sz", 13), op.get("fc") or WHITE,
                           bool(op.get("b")), 2)
                try:
                    tf.WordWrap = True
                except Exception:
                    pass
            except Exception:
                pass
        return sp
    except Exception:
        return None


def add_table(slide, sw, sh_, op):
    try:
        x = px(op.get("x"), sw, 40)
        y = px(op.get("y"), sh_, 40)
        w = px(op.get("w"), sw, 400)
        h = px(op.get("h"), sh_, 200)
        rows = op["rows"]
        shape = slide.Shapes.AddTable(len(rows), len(rows[0]), x, y, w, h)
        tbl = shape.Table
        colw = op.get("colw")
        if colw:
            for ci, cw in enumerate(colw):
                try:
                    tbl.Columns.Item(ci + 1).Width = int(w * float(cw))
                except Exception:
                    pass
        for ri, row in enumerate(rows):
            for ci, val in enumerate(row):
                try:
                    cell = tbl.Cell(ri + 1, ci + 1)
                    cell.Shape.TextFrame.TextRange.Text = str(val)
                    style_text(cell.Shape.TextFrame.TextRange, op.get("sz", 12),
                               WHITE if ri == 0 else DARK, ri == 0, 1)
                    if ri == 0 and op.get("header", True):
                        cell.Shape.Fill.Solid()
                        cell.Shape.Fill.ForeColor.RGB = rgb(PRIMARY)
                except Exception:
                    pass
        return shape
    except Exception:
        return None


def render_design(slide, sw, sh_, ops):
    for op in ops:
        if op.get("t") == "tb":
            add_table(slide, sw, sh_, op)
        else:
            add_shape(slide, sw, sh_, op)


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
            if head == b"PK" and os.path.getsize(p) > 20000:
                return p
        except Exception:
            continue
    raise RuntimeError("SaveAs failed for %s" % path)


def main():
    from cli_anything.wps.core import impress as impress_mod
    project = {
        "name": "amp-ml-prediction-v2",
        "version": "2.0",
        "type": "impress",
        "settings": {},
        "metadata": {"title": META_TITLE, "author": "arena-agent",
                     "description": "ML prediction of AMPs - designed edition",
                     "subject": ""},
        "styles": [],
        "slides": [],
    }
    for sd in SLIDES_V2:
        impress_mod.add_slide(project, sd.get("title", ""), sd.get("content", ""))
    print("AUTHORED slides=%d" % len(project["slides"]))
    with open("proj_amp_v2.json", "w", encoding="utf-8") as f:
        json.dump(project, f, ensure_ascii=False, indent=1)

    app = get_app()
    print("ENGINE attached")
    try:
        app.Visible = False
    except Exception:
        pass

    pres = app.Presentations.Add()
    print("PRESENTATION added")
    shape_count = 0
    for si, sd in enumerate(SLIDES_V2):
        if si == 0:
            try:
                slide = pres.Slides(1)
            except Exception:
                slide = pres.Slides.Add(1, 2)
        else:
            slide = pres.Slides.Add(si + 1, 2)
        try:
            sw, sh_ = slide.Width, slide.Height
        except Exception:
            sw, sh_ = 960, 540
        # ---- design system ----
        add_shape(slide, sw, sh_, {"s": 1, "x": 0, "y": 0, "w": 0.02, "h": 1,
                                   "f": PRIMARY})
        add_shape(slide, sw, sh_, {"s": 1, "x": 0, "y": 0.955, "w": 1, "h": 0.045,
                                   "f": (222, 235, 247)})
        badge = add_shape(slide, sw, sh_, {"s": 9, "x": 0.925, "y": 0.94, "w": 0.05,
                                           "h": 0.09, "f": PRIMARY,
                                           "tx": str(si + 1), "sz": 11,
                                           "fc": WHITE, "b": 1})
        if badge is not None:
            shape_count += 1
        # ---- title/body placeholders ----
        title = sd.get("title", "")
        content = sd.get("content", "")
        title_done = False
        body_done = False
        for shape in slide.Shapes:
            try:
                if shape.Type == 14 and title and not title_done:
                    pt = str(shape.PlaceholderFormat.Type)
                    if "Title" in pt or pt.strip() in ("1", "13", "14"):
                        shape.TextFrame.TextRange.Text = title
                        style_text(shape.TextFrame.TextRange, 28, PRIMARY, True, 1)
                        title_done = True
                        continue
            except Exception:
                pass
            try:
                if content and not body_done and shape.HasTextFrame:
                    shape.TextFrame.TextRange.Text = content
                    style_text(shape.TextFrame.TextRange, 16, DARK, False, 1)
                    body_done = True
            except Exception:
                pass
        # ---- per-slide graphics ----
        before = shape_count
        render_design(slide, sw, sh_, sd.get("ops", []))
        try:
            shape_count = 0
            j = 1
            while True:
                try:
                    pres.Slides.Item(si + 1).Shapes.Item(j)
                except Exception:
                    break
                shape_count += 1
                j += 1
        except Exception:
            pass
        print("SLIDE %d shapes=%d" % (si + 1, shape_count))
    print("RENDERED slides=%d" % len(SLIDES_V2))
    out = save_pptx(pres, "amp_ml_prediction_v2.pptx")
    print("SAVED %s %dKB" % (out, os.path.getsize(out) // 1024))
    pres.Close()
    try:
        app.Quit()
    except Exception:
        pass
    print("AMP-DECK-RESULT: PASS")
    print("AMP-DECK-DONE")


if __name__ == "__main__":
    main()
