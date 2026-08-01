import json
from pathlib import Path

report = json.loads(Path("reports/dlsk/report.json").read_text(encoding="utf-8"))
counts = report.get("counts", {})
high = int(counts.get("HIGH", 0))
critical = int(counts.get("CRITICAL", 0))
print(f"DLSK findings: HIGH={high}, CRITICAL={critical}")
for finding in report.get("findings", []):
    severity = str(finding.get("severity", "")).upper()
    if severity in {"HIGH", "CRITICAL"}:
        print(json.dumps(finding, indent=2, sort_keys=True))
if high or critical:
    raise SystemExit("DLSK high-risk gate failed")
