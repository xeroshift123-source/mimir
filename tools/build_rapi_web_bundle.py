"""Bundle the pinned engine + fixed Nikke functions and self-hosted WASM runtime.

Prerequisites: python tools/setup_nikke_calc.py
  npm install --prefix scratch/score-runtime --ignore-scripts pyodide@0.29.3
No profiles, credentials, tests or images are shipped.
"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from services.nikke_score.evaluator import verify_engine

engine = ROOT / "scratch/nikke-calc"
lock = verify_engine(engine)
targets = json.loads((ROOT / "services/nikke_score/targets.json").read_text(encoding="utf-8"))
# The app's current party metadata belongs to build_partner_score_targets.py.
# This historical engine-bundle tool must not overwrite the API UI's Dart types.
runtime = ROOT / "scratch/score-runtime/node_modules/pyodide"
if json.loads((runtime / "package.json").read_text())["version"] != "0.29.3":
    raise ValueError("Expected Pyodide 0.29.3")
destination = ROOT / "web/score"
destination.mkdir(parents=True, exist_ok=True)
files = subprocess.check_output(["git", "-C", str(engine), "ls-files", "-z"]).decode().split("\0")
archive = destination / "rapi-engine.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
    def put(path, name):
        entry = zipfile.ZipInfo(name, (2026, 10, 19, 0, 0, 0))
        entry.compress_type = zipfile.ZIP_DEFLATED
        bundle.writestr(entry, path.read_bytes())

    for name in sorted(files):
        p = Path(name)
        if name == "LICENSE" or (p.parts and p.parts[0] in {"calculator", "runner", "data", "scraper"}
                                 and p.suffix in {".py", ".json"}):
            put(engine / name, "engine/" + name)
    included = ["__init__.py", "adapter.py", "embedded.py", "targets.json"]
    included += ["contexts/" + t["version"] + ".json" for t in targets]
    for name in included:
        put(ROOT / "services/nikke_score" / name, "services/nikke_score/" + name)

runtime_out = destination / "pyodide-0.29.3"
runtime_out.mkdir(exist_ok=True)
for name in ("pyodide.js", "pyodide.asm.js", "pyodide.asm.wasm", "pyodide-lock.json",
             "python_stdlib.zip"):
    shutil.copyfile(runtime / name, runtime_out / name)
if not all((runtime_out / name).exists() for name in ("LICENSE", "LICENSE-PYTHON")):
    raise ValueError("Keep the Pyodide and CPython licenses in the runtime directory")
shutil.copyfile(ROOT / "services/nikke_score/THIRD_PARTY_NOTICES.md", destination / "THIRD_PARTY_NOTICES.md")
manifest = {"engineCommit": lock["commit"], "pyodide": "0.29.3", "files": {}}
for path in [archive, *sorted(runtime_out.iterdir())]:
    manifest["files"][path.relative_to(destination).as_posix()] = {
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size}
(destination / "bundle-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"archiveBytes": archive.stat().st_size,
                  "totalBytes": sum(v["bytes"] for v in manifest["files"].values())}))
