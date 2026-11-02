"""Install exactly the locked calculator into ignored scratch/nikke-calc."""
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from services.nikke_score.evaluator import verify_engine

lock = json.loads((root / "services/nikke_score/engine_lock.json").read_text(encoding="utf-8"))
destination = root / "scratch/nikke-calc"
if not destination.exists():
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "clone", "--no-checkout", lock["repository"], str(destination)], check=True)
    subprocess.run(["git", "-C", str(destination), "checkout", "--detach", lock["commit"]], check=True)
verify_engine(destination)
print(destination)
