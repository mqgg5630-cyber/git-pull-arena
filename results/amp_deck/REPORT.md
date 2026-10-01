# 机器学习预测抗菌肽 — 可编辑 PPTX 交付

日期：2026-10-02　生成方式：harness-anything（WPS COM，KWPP v12.0）单进程全自动构建　轮次：r161

## 结果路径

| 位置 | 路径 |
|---|---|
| **台式机** | `F:\fig1_rebuild\harness_results\amp_ml_prediction.pptx`（79KB，14 页） |
| **仓库（双机同步）** | `results/amp_deck/amp_ml_prediction.pptx` |
| 项目 JSON | `results/amp_deck/proj_amp.json`（harness 授权文件，可复用再生成） |
| 台式机仓库 | `E:\0github\git-sync\git-pull-arena-01a0a9f0\results\amp_deck\amp_ml_prediction.pptx` |

## 14 页目录

1. 封面：机器学习预测抗菌肽
2. 背景：AMR 危机（Lancet 2019 ~127 万直接死亡）与 AMP 机会
3. 抗菌肽是什么（阳离子两亲性 / 破膜机制）
4. 数据库与数据集（APD3/DBAASP/CAMP3/LAMP/ADAPT + CD-HIT 去冗余）
5. 特征工程（AAC/DPC/CKSAAP/PseAAC/理化性质/末端编码）
6. 经典机器学习（SVM/iAMPpred、随机森林/AmPEP、XGBoost）
7. 深度学习（CNN/AMPscanner/Deep-AmPEP30、BiLSTM、注意力）
8. 蛋白质语言模型（ESM-2/ProtT5/AMP-BERT、少样本迁移）
9. 评估体系（CV/独立集、MCC/AUC/Sn/Sp、同源泄漏）
10. 挑战与陷阱（负样本定义、数据偏差、体外≠体内、MIC 数据稀缺）
11. 从预测到从头设计（VAE/GAN/扩散、HYDRA、设计-合成-实验闭环）
12. 应用场景（药物/涂层/食品保鲜/农业）
13. 工程化复现路线图（数据→特征→模型→评估→部署）
14. 总结与展望

## 终验（沙箱结构级）

- 14/14 页；OOXML 完整（[Content_Types] + presentation.xml + 26 布局 + 4 母版）
- 0 个 XML 解析错误；292 个文本段
- 内容标记 11/11 命中（含 AMR/127 万、CD-HIT、PseAAC、iAMPpred、Deep-AmPEP30、ESM-2、HYDRA）
- 每页含标题占位符 + 正文要点 + 底部注释文本框，全部为真实可编辑元素（非图片）

## 备注

- 沿用 r160 验证的单进程首客户端构建模式（WPS 12 KWPP 热实例只认第一个 COM 客户端）
- 生成轮回执：`results/status/check_r161_20261002-011523.txt`

---

# v2 设计版（r163，回应"全是文字"的反馈）

## 新结果路径

| 位置 | 路径 |
|---|---|
| **台式机** | `F:\fig1_rebuild\harness_results\amp_ml_prediction_v2.pptx`（100KB，14 页） |
| **仓库** | `results/amp_deck/amp_ml_prediction_v2.pptx` |
| 项目 JSON | `results/amp_deck/proj_amp_v2.json` |

## 图形元素清单（终验实测）

- **150 个原生可编辑形状**（v1 仅 42 个）+ **3 张原生表格**（数据库对比 / 经典模型对比 / 混淆矩阵）
- 几何类型：圆角卡片 ×46、矩形色带 ×36、圆形徽章/圆点 ×21、箭头 ×10、chevron 路线图 ×5、三角警示 ×4
- 配色系统：主蓝 #1F4E79（89 处）、青 #008C8C、橙 #ED7D31、绿 #279056、浅底 #DEEBF7/#F2F6FA
- 每页设计系统：左侧主色竖条 + 底部浅色页脚条 + 右下页码圆徽
- 版面亮点：AMR 三统计卡 / 破膜机理图（膜+肽圆点+箭头+三模型）/ 深度学习五级管道图 / PLM 三层栈 / 混淆矩阵+指标徽章 / 挑战四警示卡 / 设计-预测-合成-实验闭环图 / 应用四象限卡 / 五步 chevron 路线图
- 14 页、0 个 XML 错误、内容标记 7/7 命中；全部元素为 WPS 原生对象（非图片），双击即编辑

生成轮：r162（字面量 true bug 失败）→ r163 一轮成功；回执 `results/status/check_r163_20261002-014039.txt`
