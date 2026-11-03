"""Fetch pinned dependencies into this project. Requires Python 3 and Git."""
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
lock = json.loads((root / "dependencies.json").read_text())
temp = root / "build/tmp"
temp.mkdir(parents=True, exist_ok=True)
os.environ["TEMP"] = os.environ["TMP"] = str(temp)

for name in ("skia", "daScript"):
    item = lock[name]
    dest = root / "third_party" / name
    if dest.exists() and any(dest.iterdir()) and not (dest / ".git").exists():
        raise SystemExit(f"Refusing to overwrite non-Git directory: {dest}")
    dest.mkdir(parents=True, exist_ok=True)
    def git(*args):
        return subprocess.check_output(["git", *args], cwd=dest, text=True).strip()
    if not (dest / ".git").exists():
        git("init")
    if git("status", "--porcelain", "--untracked-files=no"):
        raise SystemExit(f"Dependency has local changes: {dest}")
    try:
        head = git("rev-parse", "HEAD")
    except subprocess.CalledProcessError:
        head = ""
    if head != item["revision"]:
        git("fetch", "--depth", "1", item["url"], item["revision"])
        git("checkout", "--detach", "FETCH_HEAD")
subprocess.run([sys.executable, str(root / "tools/bootstrap_skia_deps.py")], check=True)
subprocess.run([sys.executable, str(root / "tools/bootstrap_fonts.py")], check=True)
