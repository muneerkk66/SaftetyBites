#!/usr/bin/env bash

set -euo pipefail

build_dir="${1:-build/web}"
catalog_dir="$build_dir/catalog"
local_catalog_dir="${OFFLINE_CATALOG_SOURCE_DIR:-dist/catalog}"
manifest_url="${OFFLINE_CATALOG_MANIFEST_URL:-https://safebites-4a21a.web.app/catalog/manifest.json}"

if [[ -f "assets/catalog/manifest.json" ]] &&
  { [[ ! -f "$local_catalog_dir/manifest.json" ]] ||
    ! grep -q '"attributionUrl"' "$local_catalog_dir/manifest.json"; }; then
  local_catalog_dir="assets/catalog"
fi

mkdir -p "$catalog_dir"

if [[ -f "$local_catalog_dir/manifest.json" ]]; then
  python3 - "$local_catalog_dir/manifest.json" "$local_catalog_dir" "$catalog_dir" <<'PY'
import hashlib
import json
import pathlib
import shutil
import sys
import urllib.parse

ATTRIBUTION = """SafeBiteAI UK offline food catalogue

Contains information from Open Food Facts, made available under ODbL 1.0.
Individual contents are available under DbCL 1.0. Product images are available
under CC BY-SA 3.0. SafeBiteAI filters and reformats the source export.
Full notices: https://safebiteai.co.uk/data-licences
"""

manifest_path = pathlib.Path(sys.argv[1])
source_dir = pathlib.Path(sys.argv[2])
target_dir = pathlib.Path(sys.argv[3])
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
filename = pathlib.Path(urllib.parse.urlparse(manifest["downloadUrl"]).path).name
source = source_dir / filename
if not source.is_file():
    raise SystemExit(f"Offline catalogue pack is missing: {source}")
digest = hashlib.sha256(source.read_bytes()).hexdigest()
if digest != manifest["sha256"]:
    raise SystemExit("Offline catalogue pack checksum does not match its manifest.")
for item in target_dir.iterdir():
    shutil.rmtree(item) if item.is_dir() else item.unlink()
shutil.copy2(manifest_path, target_dir / "manifest.json")
shutil.copy2(source, target_dir / filename)
notice = pathlib.Path("assets/catalog/ATTRIBUTION.txt")
if notice.is_file():
    shutil.copy2(notice, target_dir / "ATTRIBUTION.txt")
else:
    (target_dir / "ATTRIBUTION.txt").write_text(ATTRIBUTION, encoding="utf-8")
print(f"Staged offline catalogue: {manifest['productCount']:,} products")
PY
  exit 0
fi

temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

if ! curl --fail --silent --show-error --location \
  "$manifest_url" --output "$temporary_dir/manifest.json"; then
  echo "Offline catalogue manifest is unavailable. Hosting deployment stopped to protect offline scanning." >&2
  exit 1
fi

python3 - "$temporary_dir/manifest.json" "$manifest_url" "$temporary_dir" "$catalog_dir" <<'PY'
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import urllib.parse

ATTRIBUTION = """SafeBiteAI UK offline food catalogue

Contains information from Open Food Facts, made available under ODbL 1.0.
Individual contents are available under DbCL 1.0. Product images are available
under CC BY-SA 3.0. SafeBiteAI filters and reformats the source export.
Full notices: https://safebiteai.co.uk/data-licences
"""

manifest_path = pathlib.Path(sys.argv[1])
manifest_url = sys.argv[2]
temporary_dir = pathlib.Path(sys.argv[3])
target_dir = pathlib.Path(sys.argv[4])

try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    download_url = urllib.parse.urljoin(manifest_url, manifest["downloadUrl"])
    filename = pathlib.Path(urllib.parse.urlparse(download_url).path).name
    expected_sha = manifest["sha256"]
    product_count = int(manifest["productCount"])
except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
    raise SystemExit(
        "Live offline catalogue manifest is invalid. Hosting deployment stopped."
    ) from error

pack_path = temporary_dir / filename
subprocess.run(
    [
        "curl",
        "--fail",
        "--silent",
        "--show-error",
        "--location",
        download_url,
        "--output",
        str(pack_path),
    ],
    check=True,
)

digest = hashlib.sha256(pack_path.read_bytes()).hexdigest()
if digest != expected_sha:
    raise SystemExit("Downloaded offline catalogue checksum is invalid.")

for item in target_dir.iterdir():
    shutil.rmtree(item) if item.is_dir() else item.unlink()
shutil.copy2(manifest_path, target_dir / "manifest.json")
shutil.copy2(pack_path, target_dir / filename)
notice = pathlib.Path("assets/catalog/ATTRIBUTION.txt")
if notice.is_file():
    shutil.copy2(notice, target_dir / "ATTRIBUTION.txt")
else:
    (target_dir / "ATTRIBUTION.txt").write_text(ATTRIBUTION, encoding="utf-8")
print(f"Preserved offline catalogue: {product_count:,} products")
PY
