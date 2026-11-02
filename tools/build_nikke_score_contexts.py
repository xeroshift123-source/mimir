"""Freeze popular parties and advantageous elements; never import raid boss stats/patterns.

Run with --snapshots DIR (season-N.json from enikk) and --rapi-snapshot FILE.
The common enemy uses the pinned engine defaults, identically for every target.
"""
import argparse
from datetime import datetime, timezone
import copy
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from services.nikke_score.adapter import TARGETS
from services.nikke_score.evaluator import verify_engine
from tools.build_rapi_score_context import select_team

NAMES = {
    "Brid: Silent Track": "브리드 : 사일런트 트랙", "Rapi: Red Hood": "라피 : 레드 후드",
    "Anis: Star": "아니스 : 스타", "Mihara: Bonding Chain": "미하라 : 본딩 체인", "Privaty": "프리바티",
    "Miranda": "미란다", "Crown": "크라운", "Snow White: Heavy Arms": "스노우 화이트 : 헤비암즈",
    "Little Mermaid": "리틀 머메이드", "Liberalio": "리버렐리오", "Anchor: Innocent Maid": "앵커 : 이노센트 메이드",
    "Scarlet: Black Shadow": "홍련 : 흑영", "Mast: Romantic Maid": "마스트 : 로망틱 메이드",
    "Isabel": "이사벨", "Arcana": "아르카나", "Cinderella": "신데렐라",
    "Cinderella: Crystal Wave": "신데렐라 : 크리스탈 웨이브", "EVE": "이브", "Tove": "토브",
    "Arcana: Fortune Mate": "아르카나 : 포츈 메이트", "Dorothy: Serendipity": "도로시 : 세렌디피티",
    "Sugar": "슈가", "Soline: Frost Ticket": "솔린 : 프로스트 티켓",
    "Diesel: Winter Sweets": "디젤 : 윈터 스위츠", "Nayuta": "나유타",
    "Neon: Vision Eye": "네온 : 비전 아이", "Marciana: Marine Study": "마르차나 : 마린 스터디",
    "Moran": "목단", "Mint": "민트", "Prika": "프리카", "Velvet": "벨벳",
    "Helm": "헬름", "Helm: Aquamarine": "헬름 : 아쿠아마린",
}
ENEMY_CODES = {"Fire": "풍압", "Water": "작열", "Wind": "철갑", "Iron": "전격", "Electric": "수냉"}
ENEMY_NAMES = {"Wind": "풍압", "Fire": "작열", "Iron": "철갑", "Electronic": "전격", "Water": "수냉"}
ENDS = {36: "2026-05-07", 38: "2026-07-08", 39: "2026-07-23", 40: "2026-08-27", 41: "2026-10-01"}


def score_controls(baseline, target_name, burst_stage):
    """Keep slot order, select ready B2s and prioritize the target's burst stage.

    The engine otherwise restricts B2 to the first slot, even during cooldown.
    An explicit empty pattern makes a character a cooldown fallback on every
    cycle. The target has no pattern (rank 1), ahead of same-stage peers (rank 2).
    Cooldowns still apply. Preserve B1 specialists when scoring a B2/B3 target,
    and preserve all non-burst controls.
    This is our fixed evaluation policy, not raid players' observed operation.
    """
    chars = {c["name"]: {"control": copy.deepcopy(c.get("control", {}))} for c in baseline}
    target_stage = burst_stage(target_name)
    for name, settings in chars.items():
        stage = burst_stage(name)
        if stage == target_stage:
            settings["control"].setdefault("burst", {})["pattern"] = (
                False if name == target_name else [])
        elif stage in ("2", "3"):
            # Keep party-specific setup such as Prika's first-cycle-only burst.
            settings["control"].setdefault("burst", {}).setdefault("pattern", [])
    return chars


def build(snapshots, rapi_snapshot, engine):
    lock = verify_engine(engine)
    sys.path.insert(0, str(engine))
    from runner import spec
    from calculator.timeline import DEFAULT_ENEMY
    growth_keys = ("level", "breakthrough", "core_enhancement", "affinity", "skill_levels",
                   "equipment", "equip_skills", "cube", "console", "collection_stage", "favorite_stage")
    folder = ROOT / "services/nikke_score/contexts"
    reference = json.loads((ROOT / "services/nikke_score/examples/rapi-reference.input.json").read_text(encoding="utf-8"))
    fixtures = {}
    for target in TARGETS.values():
        season = target["season"]
        snapshot = rapi_snapshot if season == 40 else snapshots / f"season-{season}.json"
        raw = snapshot.read_bytes()
        data = json.loads(raw)["data"]
        english = next(n for n, ko in NAMES.items() if ko == target["name"])
        order, count, order_count, servers, counts = select_team(data["SRRankings"], english)
        squad = [NAMES[n] for n in order]
        enemy = {k: copy.deepcopy(DEFAULT_ENEMY[k]) for k in
                 ("def", "core_px", "has_parts", "part_break_interval", "optimal_range_weapons")}
        enemy["code"] = ENEMY_CODES[target["element"]]
        if season != 40:
            # Read only the element, deliberately ignoring all boss-specific stats.
            source_element = data["soloRaid"]["monster_obj"]["element_id"]["element"]
            if ENEMY_NAMES[source_element] != enemy["code"]:
                raise ValueError("Wrong advantageous raid element")
        baseline = spec.build_squad(squad)
        profiles = {c["name"]: {k: copy.deepcopy(c[k]) for k in growth_keys} for c in baseline}
        request = {
            "schema_version": 2, "squad": squad,
            "sim": {"duration": 180, "expected": True, "seed": 0, "first_burst": 3.0,
                    "burst_gauge_mode": "fixed", "allow_unparsed": False},
            "enemy": enemy,
            "operation": {"auto": squad, "control_mode": "solo", "camera_mode": "single"},
            "chars": score_controls(baseline, target["name"], spec.burst_stage),
            "profile": {"base": "default", "chars": profiles}, "profile_level": "fixed",
        }
        source = {"provider": "enikk", "url": f"https://enikk.app/soloraid/{season}",
                  "seasonId": season, "seasonEndedAtKst": ENDS[season] + "T04:59:59+09:00",
                  "selectionDateKst": target.get("selectionDateKst", "2026-10-19"), "scope": "서버별 상위 50명 공개 표본",
                  "samplePlayers": len(data["SRRankings"]), "sampleTeams": sum(counts.values()),
                  "selectedTeamCount": count, "selectedOrderCount": order_count, "servers": servers,
                  "rawSnapshotSha256": hashlib.sha256(raw).hexdigest(),
                  "capturedAt": datetime.fromtimestamp(snapshot.stat().st_mtime, timezone.utc).isoformat(),
                  "grouping": "unordered_members", "orderPolicy": "most_frequent_slot_order",
                  "tieBreak": "lexicographic_names", "importedFields": ["team_members", "enemy_element"]}
        context = {"version": target["version"], "engineCommit": lock["commit"],
                   "targetId": target["id"], "targetNameCode": target["nameCode"],
                   "targetElement": target["element"], "enemyModel": "common-engine-defaults-v1",
                   "burstPolicy": ("target-b3-first-ready-b2-slot-order-v1" if spec.burst_stage(target["name"]) == "3"
                                   else "target-stage-first-ready-b2-slot-order-v2"),
                   "bossName": "공통 평가 대상", "source": source, "request": request,
                   "assumptions": ["솔로레이드는 최다 조합과 우월 코드 적용 속성만 선정합니다.",
                     "모든 니케는 공통 적 스탯을 사용하며 시즌 보스 스탯·이동·무적·파츠 패턴을 적용하지 않습니다.",
                     "400레벨·180초·기대값·고정 버스트 게이지 조건입니다.",
                     "대상은 실제 육성, 동료 4명은 고정 육성을 적용합니다.",
                     "버스트는 평가 대상의 단계에서 본인 우선, 쿨타임 중에는 동료를 사용합니다. 그 외 2단계는 사용 가능한 동료를 배치 순으로 선택합니다.",
                     "버스트 운용은 평가용 고정 정책이며 랭킹 표본에서 수집한 실전 운용이 아닙니다."]}
        (folder / (target["version"] + ".json")).write_text(
            json.dumps(context, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        aggregate = {"seasonId": season, "snapshotSha256": source["rawSnapshotSha256"],
                     "teams": [{"members": list(k), "count": n} for k, n in sorted(counts.items())]}
        (folder / f"s{season}-team-counts.json").write_text(json.dumps(aggregate, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        fixture = copy.deepcopy(reference)
        fixture.update(nikkeId=target["id"], evaluationVersion=target["version"])
        char = fixture["character"]
        char["name_code"] = target["nameCode"]
        for i, eq in enumerate(char["equipment"]):
            eq["tid"] = (310 + i * 10 + target["classIndex"]) * 10000 + 1001
        char["favoriteItem"]["tid"] = int(next(k for k,v in target["collectionIds"].items() if v == "SR"))
        fixture["recycleRoom"] = [{"tid":1001,"lv":180}, {"tid":target["classResearch"],"lv":100},
                                  {"tid":target["companyResearch"],"lv":100}]
        fixtures[target["id"]] = fixture
        print(json.dumps({"target": target["name"], "party": squad, "count": count}, ensure_ascii=False))
    (ROOT / "services/nikke_score/examples/score-reference.inputs.json").write_text(
        json.dumps(fixtures, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--snapshots", type=Path, required=True)
    parser.add_argument("--rapi-snapshot", type=Path, required=True)
    parser.add_argument("--engine", type=Path, default=ROOT / "scratch/nikke-calc")
    args = parser.parse_args()
    build(args.snapshots, args.rapi_snapshot, args.engine.resolve())
