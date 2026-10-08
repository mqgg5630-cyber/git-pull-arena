import sys
import csv

seed_tsv, out_fa = sys.argv[1:3]
n = 0
with open(seed_tsv) as f, open(out_fa, "w") as out:
    reader = csv.DictReader(f, delimiter="\t")
    for row in reader:
        out.write(row["header"] + "\n")
        out.write(row["sequence"] + "\n")
        n += 1
print("seed_fasta_records", n)
