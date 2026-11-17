#!/usr/bin/env python3
"""Merge this run's build/scan results into status.json and render the README status table.

Usage: report.py <artifacts-dir>
  <artifacts-dir>/scan-<v>/scan.json           written by the scan job
  <artifacts-dir>/digest-<v>-<arch>/<arch>.seconds   build duration from the build job
Versions not built in this run keep their previous row.
"""
import json
import os
import re
import sys
import urllib.request
from datetime import date, datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATUS = os.path.join(ROOT, "status.json")
README = os.path.join(ROOT, "README.md")
IMAGE = os.environ.get("IMAGE", "openpanel/php-fpm")
START, END = "<!-- status:start -->", "<!-- status:end -->"


def get_json(url):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "php-fpm-status"})
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r)
    except Exception as e:  # network hiccups must not break the report
        print(f"warning: {url}: {e}", file=sys.stderr)
        return None


def versions():
    with open(os.path.join(ROOT, "versions.txt")) as f:
        return [l.split()[0] for l in f if l.strip() and not l.startswith("#")]


def mb(n):
    return f"{n / 1024 / 1024:.0f} MB" if n else "-"


def main(art):
    status = {}
    if os.path.exists(STATUS):
        with open(STATUS) as f:
            status = json.load(f)

    eol = {c["cycle"]: c for c in (get_json("https://endoflife.date/api/php.json") or [])}
    vs = versions()

    for v in vs:
        row = status.get(v, {})

        scan = os.path.join(art, f"scan-{v}", "scan.json")
        if os.path.exists(scan):
            with open(scan) as f:
                row.update(json.load(f))

        for arch in ("amd64", "arm64"):
            sec = os.path.join(art, f"digest-{v}-{arch}", f"{arch}.seconds")
            if os.path.exists(sec):
                with open(sec) as f:
                    row.setdefault("build_seconds", {})[arch] = int(f.read().strip() or 0)

        tag = get_json(f"https://hub.docker.com/v2/repositories/{IMAGE}/tags/{v}")
        if tag:
            row["pushed"] = tag.get("last_pushed") or tag.get("last_updated")
            row["size"] = {i["architecture"]: i["size"] for i in tag.get("images", [])
                           if i.get("architecture") in ("amd64", "arm64")}

        c = eol.get(v)
        if c:
            row["php_support"] = c.get("support")
            row["php_eol"] = c.get("eol")
        status[v] = row

    status = {v: status[v] for v in vs if v in status}
    with open(STATUS, "w") as f:
        json.dump(status, f, indent=2, sort_keys=True)
        f.write("\n")

    today = date.today().isoformat()

    def php_state(r):
        e, s = r.get("php_eol"), r.get("php_support")
        if not isinstance(e, str):
            return "🧪 pre-release" if re.search(r"(RC|alpha|beta)", r.get("php", "")) or r.get("size") else "-"
        if e < today:
            return f"⛔ EOL {e[:7]}"
        if isinstance(s, str) and s < today:
            return f"🟡 security until {e[:7]}"
        return f"🟢 active until {s[:7] if isinstance(s, str) else e[:7]}"

    def vulns(r):
        t = r.get("vulns")
        if not t:
            return "-", "-"
        total = f"{t['CRITICAL']} / {t['HIGH']} / {t['MEDIUM']} / {t['LOW']}"
        fc, fh = r["fixable"]["CRITICAL"], r["fixable"]["HIGH"]
        fix = "✅ none" if fc + fh == 0 else f"⚠️ {fc} critical, {fh} high"
        return total, fix

    lines = [
        "| Tag | PHP | Debian | PHP support | Download amd64 / arm64 | Built (UTC) | Build time | Vulns C / H / M / L | Fixable C/H | Extensions |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for v, r in status.items():
        size = r.get("size", {})
        pushed = (r.get("pushed") or "-")[:16].replace("T", " ")
        bs = r.get("build_seconds", {})
        btime = " / ".join(f"{bs[a] // 60}m{bs[a] % 60:02d}s" for a in ("amd64", "arm64") if a in bs) or "-"
        total, fix = vulns(r)
        missing = r.get("missing_extensions") or []
        ext = "✅ all" if not missing and "php" in r else ("⚠️ missing " + ", ".join(missing) if missing else "-")
        lines.append(
            f"| `{IMAGE}:{v}` | {r.get('php', '-')} | {r.get('debian', '-')} | {php_state(r)} | "
            f"{mb(size.get('amd64'))} / {mb(size.get('arm64'))} | {pushed} | {btime} | {total} | {fix} | {ext} |"
        )
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    table = "\n".join(lines) + f"\n\n_Updated automatically by the build workflow, last run {stamp}._"

    with open(README) as f:
        readme = f.read()
    readme = re.sub(re.escape(START) + r".*?" + re.escape(END), START + "\n" + table + "\n" + END, readme, flags=re.S)
    with open(README, "w") as f:
        f.write(readme)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "artifacts")
