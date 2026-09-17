#!/usr/bin/env python3
# make_deck_umami.py - a 12-page deck: machine learning screening of umami peptides.
#
# Task: "主题换位机器学习筛选鲜味肽，用我电脑的安装好的venv环境生成" - the same
# loop, a different subject: the pages below are authored here, then checked and
# exported by the PPT Master install + venv on the user's Windows machine
# (E:\0github\git-sync\ppt-master\.venv), which also opens the finished pptx in
# the real PowerPoint.
#
# What the deck claims and what it does not:
#   * the METHOD is the deck's subject - databases, features, models, metrics,
#     screening funnel, wet-lab readout;
#   * every count, ratio and score on the pages is marked 示例 (illustrative
#     placeholder), because this repo has no peptide dataset and inventing
#     "measured" numbers would be worse than useless. Replace the marked values
#     with your own dataset and rebuild - the geometry is safe for any of them
#     (code/deck_layout_selftest.py stress-tests exactly that).
#
# Same authoring contract as every deck here: one bounded group per module
# (data-pptx-bounds), no overlapping zones, strict XML, raw Unicode typography.
#
# Usage: python3 code/make_deck_umami.py --out <project>/svg_output

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from deck_kit import (  # noqa: E402  (the shared deck framework)
    AMBER, BG, BLUE, CYAN, DIM, H, INK, LIME, LINE, LINE_SOFT, MONO, MONO_INK, MUTED,
    PANEL, PANEL_DEEP, Page, SANS, W, card, divider_page, run,
)

SESSION = '01a0aa00'
SKILL_VER = '2.8.1'
HOST = 'LAPTOP-R77M5D6M'
BRANCH = 'arena/%s-git-pull-arena' % SESSION
FOOTER = 'umami peptides  ·  ppt-master deck  ·  session %s' % SESSION
DECK_V = 'v1'

TOTAL_PAGES = 12
# the deck's identity is read off the Page class by the shared framework
Page.total_pages = TOTAL_PAGES
Page.footer = FOOTER
Page.host = HOST


def chip(p, x, y, w, value, label, accent):
    """One small metric chip - the deck's unit for 示例 numbers."""
    p.rect(x, y, w, 92, fill=PANEL, stroke=LINE, rx=12, width=1)
    p.text(x + 24, y + 42, value, 26, accent, weight='700', limit=w - 40)
    p.text(x + 24, y + 72, label, 15, MUTED, limit=w - 40)


def demo(p, x, y, text):
    """Mark illustrative content so nothing on the page reads as a measurement.

    It is content, not page furniture, so it gets its own bounded group - the
    checker flags any ungrouped top-level <text> as a Slide-local element.
    """
    p.group('demo-note', 70, y - 26, 1140, 40)
    p.text(x, y, '示例：' + text, 15, AMBER, limit=1090)
    p.end()


# ------------------------------------------------------------------- pages
def page_cover():
    p = Page('cover')
    p.background()
    p.path('M0 452L1280 262', fill='none', stroke='#16324D', width=2,
           role='decoration', rid='cover-trace')
    p.circle(1032, 226, 5, LIME, glow=True, role='decoration', rid='cover-node-a')
    p.circle(902, 296, 4, CYAN, glow=True, role='decoration', rid='cover-node-b')
    p.rect(0, 0, 6, H, fill=LIME, opacity='0.9', role='decoration', rid='cover-edge')

    p.group('cover-kicker', 90, 92, 900, 40)
    p.text(96, 124, '//  UMAMI PEPTIDE SCREENING   ·   本机 venv 生成', 18, CYAN,
           family=MONO, spacing='4', limit=880)
    p.end()

    p.group('cover-title', 70, 180, 1150, 250)
    p.text(94, 292, '机器学习', 92, INK, weight='700', limit=1120)
    p.text(94, 392, '筛选鲜味肽', 92, LIME, weight='700', limit=1120)
    p.end()

    p.group('cover-subtitle', 92, 430, 1010, 58)
    p.text(98, 466, '序列 → 特征 → 模型打分 → 合成 → 味觉验证', 26, MONO_INK, limit=990)
    p.end()

    p.group('cover-rule', 96, 494, 300, 12)
    p.rect(98, 498, 300, 2, fill=LIME, opacity='0.7')
    p.end()

    p.group('cover-kpis', 94, 516, 1006, 118)
    chips = [('12 页', '方法 · 流程 · 复现', LIME),
             ('5 步', '候选 → 湿实验闭环', CYAN),
             ('全示例', '数字是占位，可替换', AMBER)]
    for i, (value, label, accent) in enumerate(chips):
        chip(p, 98 + i * 274, 528, 250, value, label, accent)
    p.end()

    p.group('cover-meta', 94, 638, 1010, 36)
    p.text(98, 664, '本机生成 ·  ppt-master  ·  venv python 3.11   ·  %s' % HOST, 16, DIM,
           family=MONO, limit=980)
    p.end()
    return p


def page_toc():
    p = Page('toc', 2, '//  INDEX', '这份 deck 讲什么', '六步：把肽库变成可验证的候选')
    p.background(grid=False)
    p.page_title()
    rows = [
        ('01', '问题与瓶颈', '序列空间巨大 · 感官评价贵 · 已知规律有限'),
        ('02', '数据与标签', '公开肽库 · 正负样本 · 去冗余'),
        ('03', '特征工程', '组成 / 理化 / 嵌入，怎么选'),
        ('04', '模型与评估', '模型家族、指标、泄漏陷阱'),
        ('05', '筛选漏斗', '百万级候选压到可合成数量'),
        ('06', '湿实验与复现', '传感器 · 受体 · 阈值 · 一条命令重建'),
    ]
    for i, (num, name, note) in enumerate(rows):
        ry = 206 + 62 * i
        p.group('toc-row-%d' % (i + 1), 70, ry, 1140, 54)
        p.text(74, ry + 40, num, 22, CYAN, family=MONO, spacing='2')
        p.text(154, ry + 40, name, 26, INK, weight='700', limit=250)
        p.text(430, ry + 40, note, 19, MUTED, limit=760)
        p.line(72, ry + 50, 1208, ry + 50, LINE_SOFT, 1)
        p.end()
    return p


def page_problem():
    p = Page('content', 3, '//  PROBLEM', '为什么要用计算筛选', '湿实验只能验证极少数候选，先让模型把搜索空间砍掉')
    p.background(grid=False)
    p.page_title()
    card(p, 70, 216, 350, 300, AMBER, '空间巨大', [
        ('20 种天然氨基酸，长度 2-8 的组合', MONO, 16),
        ('穷举酶解产物是天文数字', None, 17),
        ('只能挑一小批去合成', None, 17),
    ], 'problem-space')
    card(p, 448, 216, 350, 300, CYAN, '实验瓶颈', [
        ('感官评价：周期长、成本高', None, 17),
        ('人工品评有主观差异', None, 17),
        ('电子舌 / 受体实验通量有限', None, 17),
    ], 'problem-lab')
    card(p, 826, 216, 382, 300, LIME, '已知规律', [
        ('鲜味肽多为短肽（常见 2-8 aa）', None, 17),
        ('酸性残基 + 疏水残基富集', None, 17),
        ('作用于 T1R1-T1R3 异源二聚体', None, 17),
    ], 'problem-known')
    p.group('problem-takeaway', 70, 540, 1138, 74)
    p.rect(70, 540, 1138, 74, fill=PANEL_DEEP, stroke=LINE, rx=12, width=1)
    p.text(96, 576, '结论：用模型先排序，再用少量湿实验验证排序的头部——这是本 deck 的主线。',
           21, INK, weight='700', limit=1090)
    p.text(96, 602, '示例：本页不引用任何具体文献数值，只描述常见方法学做法。', 14, AMBER,
           family=MONO, limit=1090)
    p.end()
    return p


def page_data():
    p = Page('content', 4, '//  DATA', '数据与标签从哪来', '正负样本怎么定义，比模型选什么更影响结果')
    p.background(grid=False)
    p.page_title()
    rows = [
        ('BIOPEP-UWM', '呈味肽与生物活性肽记录，可导出序列', CYAN),
        ('TastePeptides-DB', '味觉肽分类（苦 / 鲜 / 甜等）', CYAN),
        ('Umami-MRNN 数据集', '公开的鲜味肽训练集与标注', CYAN),
        ('APD3 / UniProt', '补负样本与背景序列', BLUE),
    ]
    for i, (name, note, accent) in enumerate(rows):
        ry = 212 + 56 * i
        p.group('data-row-%d' % (i + 1), 70, ry, 1140, 50)
        p.rect(70, ry, 1140, 50, fill=PANEL if i % 2 == 0 else PANEL_DEEP, stroke=LINE,
               rx=10, width=1)
        p.text(96, ry + 32, name, 20, accent, weight='700', limit=300)
        p.text(410, ry + 32, note, 18, MUTED, limit=770)
        p.end()
    card(p, 70, 448, 552, 118, AMBER, '标签从哪来', [
        ('感官阈值 / 电子舌响应 / 受体激活', None, 16),
    ], 'data-labels', title_size=22, line_size=16)
    card(p, 656, 448, 554, 118, CYAN, '负样本要难一点', [
        ('随机肽太容易，模型会虚高', None, 16),
    ], 'data-negatives', title_size=22, line_size=16)
    demo(p, 96, 606, '样本量、比例、去冗余阈值（如相似度 90%）都要按自己的库重算。')
    return p


def page_features():
    p = Page('content', 5, '//  FEATURES', '特征工程：先简单，后嵌入', '样本少的时候，可解释特征往往赢过复杂模型')
    p.background(grid=False)
    p.page_title()
    rows = [
        ('AAC', '氨基酸组成', '20', CYAN, '长度归一，最稳的基线'),
        ('DPC', '二肽组成', '400', CYAN, '捕捉相邻残基偏好'),
        ('CTD', '组成 / 转换 / 分布', '21', BLUE, '理化性质的分组统计'),
        ('理化', '疏水性 · 电荷 · pI · 体积', '8', BLUE, 'GRAVY 等经典描述符'),
        ('嵌入', '蛋白语言模型向量', '320+', LIME, '长肽 / 数据多时才划算'),
    ]
    for i, (short, name, dim, accent, note) in enumerate(rows):
        ry = 210 + 62 * i
        p.group('feature-row-%d' % (i + 1), 70, ry, 1140, 56)
        p.rect(70, ry, 1140, 56, fill=PANEL if i % 2 == 0 else PANEL_DEEP, stroke=LINE,
               rx=10, width=1)
        p.text(96, ry + 36, short, 20, accent, weight='700', limit=140)
        p.text(238, ry + 36, name, 19, INK, limit=330)
        p.text(584, ry + 36, dim + ' 维', 18, MONO_INK, family=MONO, limit=140)
        p.text(752, ry + 36, note, 17, MUTED, limit=430)
        p.end()
    p.group('feature-takeaway', 70, 548, 1138, 66)
    p.rect(70, 548, 1138, 66, fill=PANEL_DEEP, stroke=LINE, rx=12, width=1)
    p.text(96, 580, '顺序：先 AAC + 理化做基线 → 再看 DPC / CTD 的增益 → 最后才上嵌入。',
           20, INK, weight='700', limit=1090)
    p.text(96, 604, '示例：维度数字是常见设置，按自己的实现替换。', 14, AMBER, family=MONO,
           limit=1090)
    p.end()
    return p


def page_models():
    p = Page('content', 6, '//  MODELS', '模型家族与取舍', '四类做法，从可解释到端到端')
    p.background(grid=False)
    p.page_title()
    card(p, 70, 216, 272, 300, CYAN, 'SVM / RF', [
        ('样本几百条就够用', None, 16),
        ('可看特征重要度', None, 16),
        ('调参成本低', None, 16),
    ], 'model-classic', title_size=22, line_size=16)
    card(p, 358, 216, 272, 300, LIME, 'XGBoost', [
        ('表格特征上的强基线', None, 16),
        ('处理缺失值方便', None, 16),
        ('需要防过拟合', None, 16),
    ], 'model-boost', title_size=22, line_size=16)
    card(p, 646, 216, 272, 300, BLUE, 'CNN / LSTM', [
        ('直接吃序列', None, 16),
        ('数据少容易过拟合', None, 16),
        ('要配增强与正则', None, 16),
    ], 'model-deep', title_size=22, line_size=16)
    card(p, 934, 216, 274, 300, AMBER, '预训练微调', [
        ('蛋白语言模型 + 头部', None, 16),
        ('算力 / 显存要求高', None, 16),
        ('小数据上未必更好', None, 16),
    ], 'model-embed', title_size=22, line_size=16)
    p.group('models-imbalance', 70, 540, 1138, 74)
    p.rect(70, 540, 1138, 74, fill=PANEL_DEEP, stroke=LINE, rx=12, width=1)
    p.text(96, 574, '类别不平衡：正样本通常远少于负样本 → 类别权重 / 重采样 / 阈值调优，'
                    '不要只盯准确率。', 20, INK, weight='700', limit=1090)
    p.text(96, 602, '示例：常见做法，不构成某篇论文的复现结论。', 14, AMBER, family=MONO,
           limit=1090)
    p.end()
    return p


def page_eval():
    p = Page('content', 7, '//  EVAL', '评估：指标与陷阱', '模型的分数只有在划分干净时才算证据')
    p.background(grid=False)
    p.page_title()
    rows = [
        ('AUC', '整体排序能力', '对不平衡不敏感，但掩盖阈值问题', CYAN),
        ('PR-AUC', '正类识别能力', '正样本稀少时更该看它', LIME),
        ('MCC', '综合混淆矩阵', '比准确率稳，适合不平衡', BLUE),
        ('F1 / 召回@前 N', '筛选用', '决定进湿实验的数量', AMBER),
    ]
    for i, (name, what, note, accent) in enumerate(rows):
        ry = 210 + 58 * i
        p.group('eval-row-%d' % (i + 1), 70, ry, 1140, 52)
        p.rect(70, ry, 1140, 52, fill=PANEL if i % 2 == 0 else PANEL_DEEP, stroke=LINE,
               rx=10, width=1)
        p.text(96, ry + 34, name, 20, accent, weight='700', limit=200)
        p.text(320, ry + 34, what, 18, INK, limit=230)
        p.text(576, ry + 34, note, 17, MUTED, limit=600)
        p.end()
    card(p, 70, 458, 552, 110, AMBER, '三个常见陷阱', [
        ('相似序列跨训练/测试 → 泄漏', None, 16),
    ], 'eval-traps', title_size=22, line_size=16)
    card(p, 656, 458, 554, 110, LIME, '划分与复现', [
        ('5-fold + 独立物种留出，固定随机种子', None, 16),
    ], 'eval-split', title_size=22, line_size=16)
    demo(p, 96, 606, '阈值、指标和划分都要写进结果表，别只贴一个最好看的分数。')
    return p


def page_funnel():
    p = Page('content', 8, '//  FUNNEL', '筛选漏斗：从库里到可合成', '每一级都要能说清砍掉了什么')
    p.background(grid=False)
    p.page_title()
    steps = [
        ('候选库（酶解 / 计算生成）', 1030, CYAN, '10^6'),
        ('去冗余 + 长度 / 组成过滤', 880, BLUE, '10^4'),
        ('模型打分，取头部', 700, LIME, '10^2'),
        ('理化 · 毒性 · 溶解性过滤', 540, LIME, '30 条'),
        ('合成 + 感官 / 电子舌验证', 360, AMBER, '12 条命中'),
    ]
    for i, (name, w, accent, count) in enumerate(steps):
        ry = 206 + 78 * i
        p.group('funnel-step-%d' % (i + 1), 70, ry, 1140, 62)
        p.rect(70, ry, w, 62, fill=PANEL, stroke=LINE, rx=12, width=1)
        p.rect(70, ry, 4, 62, fill=accent, rx=2)
        p.text(96, ry + 40, name, 21, INK, weight='700', limit=w - 60)
        p.text(1178, ry + 40, count, 20, accent, family=MONO, anchor='end', weight='700',
               limit=200)
        p.end()
    demo(p, 96, 606, '数量级是示例；替换成自己库的统计，几何形状会自动跟着变。')
    return p


def page_wetlab():
    p = Page('content', 9, '//  WET LAB', '湿实验验证协议', '模型给出排序，实验给出结论')
    p.background(grid=False)
    p.page_title()
    rows = [
        ('感官评价', '阈值测定（mg/L）', '评审小组 + 空白对照', CYAN),
        ('电子舌', '传感器响应 / 与已知鲜味肽比对', '无创、通量高', LIME),
        ('受体功能', 'T1R1-T1R3 钙成像，拟合 EC50', '机制证据', BLUE),
        ('分子对接', '结合位点与相互作用预测', '解释性补充，不作为唯一证据', AMBER),
    ]
    for i, (name, what, note, accent) in enumerate(rows):
        ry = 212 + 62 * i
        p.group('wetlab-row-%d' % (i + 1), 70, ry, 1140, 56)
        p.rect(70, ry, 1140, 56, fill=PANEL if i % 2 == 0 else PANEL_DEEP, stroke=LINE,
               rx=10, width=1)
        p.text(96, ry + 36, name, 20, accent, weight='700', limit=200)
        p.text(320, ry + 36, what, 18, INK, limit=460)
        p.text(816, ry + 36, note, 17, MUTED, limit=380)
        p.end()
    p.group('wetlab-rule', 70, 486, 1138, 60)
    p.rect(70, 486, 1138, 60, fill=PANEL_DEEP, stroke=LINE, rx=12, width=1)
    p.text(96, 522, '判定顺序：先电子舌筛响应，再用阈值 + 受体实验确认——避免把假阳性带进结论。',
           20, INK, weight='700', limit=1090)
    p.end()
    demo(p, 96, 606, '协议字段按自己实验室的能力增减；这里只是流程骨架。')
    return p


def page_reproduce():
    p = Page('content', 10, '//  REBUILD', '怎么在这台机器上重建', '同一套 venv + PPT Master，换主题只改页源文件')
    p.background(grid=False)
    p.page_title()
    card(p, 70, 212, 552, 208, LIME, '一条命令', [
        ('双击 make-deck.cmd', MONO, 16),
        ('或 venv\\python 跑 svg_to_pptx', MONO, 16),
        ('改页：code/make_deck_umami.py', MONO, 16),
    ], 'repro-cmd', title_size=22, line_size=16)
    card(p, 656, 212, 554, 208, CYAN, '文件在哪', [
        ('ppt-master\\out\\DECK_umami_*.pptx', MONO, 16),
        ('证据：results/umami/', MONO, 16),
        ('页面源：results/umami/svg/', MONO, 16),
    ], 'repro-paths', title_size=22, line_size=16)
    card(p, 70, 448, 552, 110, AMBER, '换数据前', [
        ('把示例数字换成自己的统计', None, 16),
    ], 'repro-data', title_size=22, line_size=16)
    card(p, 656, 448, 554, 110, BLUE, '换模型时', [
        ('保留同一划分与指标表，才可比较', None, 16),
    ], 'repro-model', title_size=22, line_size=16)
    demo(p, 96, 606, '这句是给下一位读者的：每个数字都能追溯到库或实验记录。')
    return p


def page_ending():
    p = Page('ending')
    p.background()
    p.path('M0 250L1280 470', fill='none', stroke='#16324D', width=2,
           role='decoration', rid='ending-trace')
    p.group('ending-kicker', 90, 216, 900, 44)
    p.text(94, 246, '//  STATUS', 18, CYAN, family=MONO, spacing='4', limit=880)
    p.end()
    p.group('ending-headline', 70, 280, 1140, 150)
    p.text(92, 380, '本机已生成', 88, LIME, weight='700', limit=1100)
    p.end()
    p.group('ending-status', 70, 436, 1150, 44)
    p.text(96, 466, 'environment=windows · ppt-master venv python · 12 页 · 真 PowerPoint 已开档',
           19, MONO_INK, family=MONO, limit=1120)
    p.end()
    p.group('ending-rule', 94, 488, 300, 14)
    p.rect(96, 492, 300, 2, fill=LIME, opacity='0.7')
    p.end()
    p.group('ending-note', 70, 508, 1120, 56)
    p.text(96, 544, '下一步：把示例数字换成自己的肽库统计（页源 code/make_deck_umami.py），'
                    '再双击 make-deck.cmd。', 18, MUTED, limit=1080)
    p.end()
    p.group('ending-paths', 70, 584, 1150, 36)
    p.text(96, 610, 'deck：ppt-master\\out\\DECK_umami_%s_%s.pptx   ·   证据：results/umami/'
           % (SESSION, DECK_V), 16, DIM, family=MONO, limit=1120)
    p.end()
    p.text(96, 672, 'umami peptides  ·  ppt-master deck  ·  %s' % HOST, 16, DIM,
           family=MONO, role='footer', tid='footer-left')
    return p


BUILDERS = [
    ('01_cover.svg', page_cover),
    ('02_toc.svg', page_toc),
    ('03_section_a.svg', lambda: divider_page(
        '01', 'PART 01', '从序列到候选', '为什么要用机器学习做第一轮筛选',
        '湿实验资源有限，先让模型把搜索空间砍到能做的规模。')),
    ('04_problem.svg', page_problem),
    ('05_data.svg', page_data),
    ('06_features.svg', page_features),
    ('07_models.svg', page_models),
    ('08_eval.svg', page_eval),
    ('09_funnel.svg', page_funnel),
    ('10_wetlab.svg', page_wetlab),
    ('11_reproduce.svg', page_reproduce),
    ('12_ending.svg', page_ending),
]


def main():
    """Author the pages, validating what the machine's checker will validate."""
    return run(BUILDERS, session=SESSION, apply_facts=None, title='umami')


if __name__ == '__main__':
    sys.exit(main())
