"""Actual engine checks for every registered target, growth, element and bursts."""
import copy
import json
from pathlib import Path
import sys
import time
from collections import Counter
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "scratch/nikke-calc"
sys.path[:0] = [str(ROOT), str(ENGINE)]
from services.nikke_score.evaluator import verify_engine
from services.nikke_score.embedded import calculate_nikke_score
from services.nikke_score.adapter import TARGETS
from runner.sim import execute
from runner.spec import burst_stage

nikke_data = json.loads((ENGINE / "data/parsed_nikke.json").read_text(encoding="utf-8"))


def audited_execute(run):
    result = execute(run)
    counts = Counter(e.caster for e in result.log.burst_log if e.event.startswith("stage:"))
    full_bursts = sum(e.event == "full_burst 시작" for e in result.log.burst_log)
    target = TARGETS[name]["name"]
    # These fixtures previously passed growth checks while the dealer never burst.
    assert counts[target] >= 4, (name, "target burst starvation", counts)
    assert full_bursts >= 12, (name, "burst cycle stalled", full_bursts)
    b2s = [char for char in run.squad if burst_stage(char["name"]) == "2"]
    # A 40s primary B2 must rotate; a 20s primary can leave a passive B2 unused.
    require_rotation = b2s and nikke_data[b2s[0]["name"]]["burst_cooldown"] > 20
    for char in b2s:
        pattern = char.get("control", {}).get("burst", {}).get("pattern")
        if pattern == "첫 사이클만":
            assert counts[char["name"]] == 1, (name, "missing first-cycle setup", counts)
        elif len(b2s) == 1 or require_rotation:
            assert counts[char["name"]] >= 2, (name, "B2 never rotates", counts)
    audits.append({"targetBursts": counts[target], "fullBursts": full_bursts,
                   "memberBursts": dict(counts)})
    return result

verify_engine(ENGINE)
fixtures = json.loads((ROOT / "services/nikke_score/examples/score-reference.inputs.json").read_text(encoding="utf-8"))
results = {}
for name, fixture in fixtures.items():
    started = time.perf_counter()
    audits = []
    with patch("runner.sim.execute", side_effect=audited_execute):
        score = calculate_nikke_score(fixture, ENGINE)
    core = copy.deepcopy(fixture)
    core["character"]["core"] = 2
    with patch("runner.sim.execute", side_effect=audited_execute):
        core_score = calculate_nikke_score(core, ENGINE)
    no_element = copy.deepcopy(fixture)
    for eq in no_element["character"]["equipment"]:
        eq["overloadOptions"] = [0 if option // 100 == 70005 else option for option in eq["overloadOptions"]]
    with patch("runner.sim.execute", side_effect=audited_execute):
        no_element_score = calculate_nikke_score(no_element, ENGINE)
    assert score > 0 and core_score > score and no_element_score < score, (name, score, core_score, no_element_score)
    results[name] = {"score": score, "core2Score": core_score, "withoutElementOverloadScore": no_element_score,
                     "burstAudit": audits[0],
                     "evaluationVersion": fixture["evaluationVersion"], "seconds": round(time.perf_counter() - started, 3)}
    print(json.dumps({"target": name, **results[name]}), flush=True)
(ROOT / "services/nikke_score/examples/score-reference.results.json").write_text(
    json.dumps(results, indent=2) + "\n", encoding="utf-8")
