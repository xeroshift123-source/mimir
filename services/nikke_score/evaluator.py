import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

from .adapter import ADAPTER_VERSION, EvaluationError, TARGET_ID, TARGET_NAME, VERSION, normalize

ROOT = Path(__file__).resolve().parent


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False,
                                     separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def verify_engine(engine_dir):
    lock = json.loads((ROOT / "engine_lock.json").read_text(encoding="utf-8"))
    def git(*args):
        return subprocess.check_output(["git", "--no-optional-locks", "-C", str(engine_dir), *args],
                                       text=True, encoding="utf-8", timeout=15).strip()
    if git("rev-parse", "HEAD") != lock["commit"] or git("status", "--porcelain", "--untracked-files=no"):
        raise RuntimeError("nikke-calc must be clean and at the pinned commit")
    return lock


class Evaluator:
    def __init__(self, engine_dir):
        self.engine_dir = Path(engine_dir).resolve()
        self.lock = verify_engine(self.engine_dir)
        self.context = json.loads((ROOT / "contexts" / (VERSION + ".json")).read_text(encoding="utf-8"))
        if self.context["engineCommit"] != self.lock["commit"]:
            raise RuntimeError("Context/engine version mismatch")
        self.context_hash = digest(self.context)

    def prepare(self, body):
        if body.get("nikkeId") != TARGET_ID:
            raise EvaluationError("unsupported_nikke", "이 개발용 CLI는 라피 전용입니다. 웹 계산 함수를 사용해 주세요.")
        growth = normalize(body, self.engine_dir)
        request = copy.deepcopy(self.context["request"])
        request["profile"]["chars"][TARGET_NAME] = growth
        key = digest({"growth": growth, "context": self.context_hash, "engine": self.lock["commit"],
                      "adapter": ADAPTER_VERSION, "nikkeId": TARGET_ID})
        return growth, request, key

    def evaluate(self, body):
        growth, request, key = self.prepare(body)
        started = time.perf_counter()
        env = {**os.environ, "NIKKE_CALC_DIR": str(self.engine_dir), "PYTHONIOENCODING": "utf-8"}
        try:
            proc = subprocess.run([sys.executable, str(ROOT / "worker.py")],
                                  input=json.dumps(request, ensure_ascii=False), capture_output=True,
                                  text=True, encoding="utf-8", env=env, timeout=90)
        except subprocess.TimeoutExpired:
            raise EvaluationError("calculation_timeout", "딜량 계산 시간이 초과되었습니다. 다시 시도해 주세요.") from None
        if proc.returncode:
            # Log diagnostic stderr locally; never expose server paths/tracebacks to the client.
            print(proc.stderr[-4000:], file=sys.stderr)
            raise EvaluationError("engine_failure", "해당 육성 정보로 전투 계산을 완료하지 못했습니다.")
        raw = json.loads(proc.stdout)
        if raw["evaluator"]["commit"] != self.lock["commit"] or raw["evaluator"]["dirty"]:
            raise RuntimeError("Unpinned result")
        if raw["spec"]["preview"]:
            raise EvaluationError("unverified_character", "미검증 캐릭터가 포함되어 평가할 수 없습니다.")
        target = next(m for m in raw["members"] if m["name"] == TARGET_NAME)
        return {
            "status": "ok", "nikkeId": TARGET_ID, "evaluationVersion": VERSION,
            "evaluationLevel": 400, "engineRevision": self.lock["commit"],
            "adapterVersion": ADAPTER_VERSION, "contextHash": self.context_hash,
            "inputHash": digest(growth), "cacheKey": key, "personalDamage": target["damage"],
            "personalDps": target["damage"] / raw["duration"], "durationSeconds": raw["duration"],
            "partyDamage": raw["total_damage"], "score": target["damage"] * 5 / 100_000_000,
            "source": self.context["source"], "party": request["squad"],
            "bossName": self.context["bossName"], "weakness": "Fire",
            "assumptions": self.context["assumptions"], "warnings": raw["warnings"],
            "appliedGrowth": raw["appliedGrowth"], "engineSpec": raw["spec"],
            "control": raw["control_detail"], "computeSeconds": round(time.perf_counter() - started, 3),
        }
