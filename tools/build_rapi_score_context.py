"""Build the immutable S40/Fire context from an acquired enikk snapshot.

Only aggregated team counts are written; player identifiers stay outside this repo.
Usage: python tools/build_rapi_score_context.py --snapshot FILE --engine DIR
"""
import argparse
from collections import Counter, defaultdict
import copy
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from services.nikke_score.evaluator import verify_engine

NAMES = {
    "Brid: Silent Track": "브리드 : 사일런트 트랙", "Rapi: Red Hood": "라피 : 레드 후드",
    "Anis: Star": "아니스 : 스타", "Mihara: Bonding Chain": "미하라 : 본딩 체인", "Privaty": "프리바티",
}


def select_team(rows, target="Rapi: Red Hood"):
    counts, orders, servers, identities = Counter(), defaultdict(Counter), Counter(), set()
    for row in rows:
        identity = (row["server"], row["playerid"])
        if identity in identities:
            raise ValueError("Duplicate player in source snapshot")
        identities.add(identity)
        servers[row["server"]] += 1
        for team in row["teams"]:
            members = team["characters"]
            if len(members) != 5 or len(set(members)) != 5:
                raise ValueError("Invalid five-member team")
            key = tuple(sorted(members))
            counts[key] += 1
            orders[key][tuple(members)] += 1
    candidates = [(k, n) for k, n in counts.items() if target in k]
    if not candidates:
        raise ValueError("No team containing target")
    best, count = sorted(candidates, key=lambda x: (-x[1], x[0]))[0]
    order, order_count = sorted(orders[best].items(), key=lambda x: (-x[1], x[0]))[0]
    return list(order), count, order_count, dict(servers), counts


def build(snapshot, engine):
    lock = verify_engine(engine)
    source_bytes = snapshot.read_bytes()
    rows = json.loads(source_bytes)["data"]["SRRankings"]
    order, count, order_count, servers, counts = select_team(rows)
    if set(order) != set(NAMES):
        raise ValueError("Winning team changed; review ID mapping and create a NEW evaluation version")
    sys.path.insert(0, str(engine))
    from runner import spec
    squad = [NAMES[n] for n in order]
    baseline = spec.build_squad(squad)
    growth_keys = ("level", "breakthrough", "core_enhancement", "affinity", "skill_levels",
                   "equipment", "equip_skills", "cube", "console", "collection_stage", "favorite_stage")
    profiles = {c["name"]: {k: copy.deepcopy(c[k]) for k in growth_keys} for c in baseline}
    # Completely freeze all growth and controls, including the engine's character-specific defaults.
    request = {
        "schema_version": 2, "squad": squad,
        "sim": {"duration": 180, "expected": True, "seed": 0, "first_burst": 3.0,
                "burst_gauge_mode": "fixed", "allow_unparsed": False},
        "boss": "data/boss_scripts/솔로 레이드 S40 사치스러운 거미.json",
        "operation": {"auto": squad, "control_mode": "solo", "camera_mode": "single"},
        "chars": {c["name"]: {"control": copy.deepcopy(c.get("control", {}))} for c in baseline},
        "profile": {"base": "default", "chars": profiles}, "profile_level": "fixed",
    }
    boss = engine / request["boss"]
    source = {
        "provider": "enikk", "url": "https://enikk.app/soloraid", "seasonId": 40,
        "endpoint": "https://enikk.app/api/graphql", "query": "SRRankings(raid: 40)",
        "scope": "6개 서버별 상위 50명", "samplePlayers": len(rows),
        "sampleTeams": sum(counts.values()), "servers": servers, "selectedTeamCount": count,
        "selectedOrderCount": order_count,
        "capturedAt": datetime.fromtimestamp(snapshot.stat().st_mtime, timezone.utc).isoformat(),
        "rawSnapshotSha256": hashlib.sha256(source_bytes).hexdigest(),
        "aggregationVersion": 1, "grouping": "unordered_members", "orderPolicy": "most_frequent_slot_order",
        "tieBreak": "lexicographic_names", "weakness": "Fire",
        "selection": "2026-10-19 기준 작열 약점의 최근 종료 솔로레이드 S40",
    }
    context = {
        "version": "s40-fire-rapi-v1", "engineCommit": lock["commit"],
        "targetId": "rapi_red_hood", "targetNameCode": 5129, "targetElement": "Fire",
        "bossName": "사치스러운 거미", "bossScriptSha256": hashlib.sha256(boss.read_bytes()).hexdigest(),
        "source": source, "request": request,
        "assumptions": [
            "대상 니케는 레벨 400, 동기화한 실제 육성 스펙을 적용합니다.",
            "동료 4명은 계산기 기준 육성을 고정한 프로필입니다. 사용자의 다른 니케 육성은 반영하지 않습니다.",
            "180초 기대값 시뮬레이션이며 버스트 게이지는 fixed 모드를 사용합니다.",
            "개인 딜은 보스와 파츠 대상 피해입니다. 쫄몹과 저지원 피해는 제외됩니다.",
            "S40 패턴 모델에는 영상 기반 좌표·시점 및 일부 추정값이 포함됩니다.",
        ],
    }
    folder = ROOT / "services/nikke_score/contexts"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "s40-fire-rapi-v1.json").write_text(json.dumps(context, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    aggregate = {"source": source, "teams": [{"members": list(k), "count": n}
                 for k, n in sorted(counts.items())]}
    (folder / "s40-team-counts.json").write_text(json.dumps(aggregate, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"party": squad, "teamCount": count, "orderCount": order_count}, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--snapshot", type=Path, required=True)
    parser.add_argument("--engine", type=Path, required=True)
    args = parser.parse_args()
    build(args.snapshot.resolve(), args.engine.resolve())
