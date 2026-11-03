"""Fetch the pinned, redistributable example font and its license if missing."""
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile

root = Path(__file__).resolve().parents[1]
lock = json.loads((root / 'dependencies.json').read_text())['example_font']
folder = root / 'assets/fonts'
items = [('DejaVuSans.ttf', 'ttf/DejaVuSans.ttf', lock['font_sha256']),
         ('LICENSE', 'LICENSE', lock['license_sha256'])]
missing = []
for name, member, digest in items:
    path = folder / name
    if path.exists():
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise SystemExit(f'Refusing to overwrite changed font asset: {path}')
    else:
        missing.append((path, member, digest))
if missing:
    data = urllib.request.urlopen(lock['url'], timeout=60).read()
    if hashlib.sha256(data).hexdigest() != lock['archive_sha256']:
        raise SystemExit('Example font archive hash mismatch')
    archive = zipfile.ZipFile(io.BytesIO(data))
    folder.mkdir(parents=True, exist_ok=True)
    for path, member, digest in missing:
        entry = next(n for n in archive.namelist() if n.endswith('/' + member))
        content = archive.read(entry)
        if hashlib.sha256(content).hexdigest() != digest:
            raise SystemExit(f'Example font member hash mismatch: {member}')
        path.write_bytes(content)
print('Example font and license verified')

# Additional checked-in text demo fixtures, all independent of OS fonts.
fixtures=json.loads((root/'dependencies.json').read_text()).get('text_font_assets',{})
for name,entry in fixtures.items():
    if isinstance(entry,dict) and 'sha256' in entry:
        path=folder/name
        if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest()!=entry['sha256']:
            raise SystemExit(f'Text font asset missing or changed: {path}')
print('Variable/TTC fixtures verified')
