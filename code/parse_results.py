import csv
import os
import re
import sys

if len(sys.argv) != 2:
    print("Usage: python3 parse_results.py <results_dir>")
    sys.exit(1)

results_dir = sys.argv[1]
summary_path = os.path.join(results_dir, "summary.csv")

patterns = {
    "tps": re.compile(r"transactions:\s+\d+\s+\(([\d.]+) per sec\.\)"),
    "qps": re.compile(r"queries:\s+\d+\s+\(([\d.]+) per sec\.\)"),
    "ignored_errors": re.compile(r"ignored errors:\s+\d+\s+\(([\d.]+) per sec\.\)"),
    "reconnects": re.compile(r"reconnects:\s+\d+\s+\(([\d.]+) per sec\.\)"),
    "avg_latency": re.compile(r"avg:\s+([\d.]+)"),
    "p95_latency": re.compile(r"95th percentile:\s+([\d.]+)")
}

rows = []

for entry in sorted(os.listdir(results_dir)):
    run_dir = os.path.join(results_dir, entry)
    if not os.path.isdir(run_dir):
        continue

    log_path = os.path.join(run_dir, "sysbench.log")
    if not os.path.exists(log_path):
        continue

    workload = None
    threads = None

    m = re.match(r"(oltp_[a-z_]+)_t(\d+)", entry)
    if m:
        workload = m.group(1)
        threads = int(m.group(2))

    with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
        text = f.read()

    result = {
        "workload": workload,
        "threads": threads,
        "transactions_per_sec": "",
        "queries_per_sec": "",
        "avg_latency_ms": "",
        "p95_latency_ms": "",
        "ignored_errors_per_sec": "",
        "reconnects_per_sec": "",
    }

    mt = patterns["tps"].search(text)
    mq = patterns["qps"].search(text)
    me = patterns["ignored_errors"].search(text)
    mr = patterns["reconnects"].search(text)
    avg_matches = patterns["avg_latency"].findall(text)
    p95_matches = patterns["p95_latency"].findall(text)

    if mt:
        result["transactions_per_sec"] = mt.group(1)
    if mq:
        result["queries_per_sec"] = mq.group(1)
    if me:
        result["ignored_errors_per_sec"] = me.group(1)
    if mr:
        result["reconnects_per_sec"] = mr.group(1)
    if avg_matches:
        result["avg_latency_ms"] = avg_matches[-1]
    if p95_matches:
        result["p95_latency_ms"] = p95_matches[-1]

    rows.append(result)

with open(summary_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(
        f,
        fieldnames=[
            "workload",
            "threads",
            "transactions_per_sec",
            "queries_per_sec",
            "avg_latency_ms",
            "p95_latency_ms",
            "ignored_errors_per_sec",
            "reconnects_per_sec",
        ],
    )
    writer.writeheader()
    writer.writerows(rows)

print(f"Wrote summary CSV to: {summary_path}")
