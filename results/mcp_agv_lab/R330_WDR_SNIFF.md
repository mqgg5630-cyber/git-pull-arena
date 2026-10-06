# R330 WDR content magic-sniff
time=2026-10-06 23:35:52
files now: 561 (was 561 at 23:32 - growth means the tool is still writing)
-- content classes --
  ALL-ZERO: 524 files, 1015MB
     2220KB | 1-s2.0-S0010482525010194-mmc6.docx
     1789KB | 1-s2.0-S0308814622017381-mmc1.docx
     2682KB | 1-s2.0-S0308814625006636-mmc1.docx
     30KB | 1-s2.0-S1476927125001616-mmc2.docx
     23KB | 1-s2.0-S1476927125001616-mmc3.docx
     2126KB | 1-s2.0-S2212429225005826-mmc1.docx
     162KB | 1-s2.0-S2590157524000452-mmc2.docx
     13KB | 1.docx
     12KB | 10.30.docx
     5215KB | 11.14.docx
     11KB | 11.16.docx
     501KB | 11.18.docx
  unknown: 37 files, 0MB
     0KB | 11.5.docx
     0KB | 1_~$teraction study of Components of Black Pepper wi.docx
     0KB | 1_\u5b9e\u9a8c.docx
     0KB | 2. \u6750\u6599\u4e0e\u65b9\u6cd5 (Materials and Methods).docx
     0KB | 2.7 \u4f53\u5916\u751f\u7269\u6d3b\u6027\u5b9e\u9a8c\u9a8c\u8bc1 (In Vitro Bioactivity Validation).docx
     0KB | 2_1.docx
     0KB | 3_1.docx
     0KB | periodontitis_peptide_AD_SCI_manuscript.docx
     0KB | supplement.docx
     323KB | timings.docx
     0KB | ~$1.docx
     0KB | ~$REVIEW.docx
entirely-zero-sampled files: 524
-- first-bytes hex of 5 largest non-PK/OLE2 files --
   1_Interaction study of Components of Black Pepper  | 000000000000000000000000000000000000000000000000
   Interaction study of Components of Black Pepper wi | 000000000000000000000000000000000000000000000000
   \u6587\u5b57\u6587\u7a3f2.docx | 000000000000000000000000000000000000000000000000
   MYOSIN-\u8ba8\u8bba\u7ed3\u679c\u5206.docx | 000000000000000000000000000000000000000000000000
   Myosin \u86cb\u767dSCI\u8bba\u6587\u64b0\u5199\u6307\u5bfc.docx | 000000000000000000000000000000000000000000000000
FATAL: Traceback (most recent call last):
  File "E:\0github\git-sync\git-pull-arena-01a10bf3\code\tasks\t281_wdr_sniff_r330.py", line 72, in <module>
    c,o=subprocess.run(['powershell','-NoProfile','-Command','Get-Process | Where-Object {$_.MainWindowTitle} | Select-Object ProcessName,MainWindowTitle | Format-Table -HideTableHeaders | Out-String -Width 200'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=40,text=True)
    ^^^
TypeError: cannot unpack non-iterable CompletedProcess object

