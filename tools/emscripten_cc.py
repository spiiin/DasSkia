"""Native Python compiler launcher for Skia GN on Windows.

Invoking em++.bat through cmd interprets FreeType's -DNAME=<header> as shell
redirection. Ninja launches Python directly, preserving these compiler arguments.
"""
from pathlib import Path
import subprocess
import sys

entry = Path(sys.argv[1])
if entry.suffix.lower() == '.bat':
    entry = entry.with_suffix('.py')
raise SystemExit(subprocess.call([sys.executable, str(entry), *sys.argv[2:]]))
