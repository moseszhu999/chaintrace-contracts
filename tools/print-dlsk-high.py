import json
from pathlib import Path

report = json.loads(Path("reports/dlsk/report.json").read_text(encoding="utf-8"))
counts = report.get("counts", {})
high = int(counts.get("HIGH", 0))
critical = int(counts.get("CRITICAL", 0))
print(f"DLSK findings: HIGH={high}, CRITICAL={critical}")

seen = set()


def walk(value):
    if isinstance(value, dict):
        severity = str(value.get("severity", "")).upper()
        if severity in {"HIGH", "CRITICAL"}:
            rendered = json.dumps(value, indent=2, sort_keys=True)
            if rendered not in seen:
                seen.add(rendered)
                print(rendered)
        for child in value.values():
            walk(child)
    elif isinstance(value, list):
        for child in value:
            walk(child)


walk(report)
if (high or critical) and not seen:
    print(json.dumps(report, indent=2, sort_keys=True))
if high or critical:
    raise SystemExit("DLSK high-risk gate failed")
