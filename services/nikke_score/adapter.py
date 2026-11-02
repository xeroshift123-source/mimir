"""Translate a verified Mimir snapshot; never inherit missing user growth."""
import json
from pathlib import Path

TARGET_ID = "rapi_red_hood"
TARGET_NAME = "라피 : 레드 후드"
TARGET_CODE = 5129
ADAPTER_VERSION = 3
TARGETS = {t["id"]: t for t in json.loads(
    (Path(__file__).parent / "targets.json").read_text(encoding="utf-8"))}
VERSION = TARGETS[TARGET_ID]["version"]
TARGETS_BY_CODE = {t["nameCode"]: t for t in TARGETS.values()}
PARTS = {"head": "머리", "torso": "몸통", "arm": "팔", "leg": "다리"}
OPTION_GROUPS = {
    70005: "element_bonus", 70006: "accuracy_pct", 70007: "max_ammo_pct",
    70008: "atk_pct", 70009: "charge_dmg_pct", 70010: "charge_speed_pct",
    70011: "crit_rate", 70012: "crit_dmg", 70013: "def_pct",
}
CORPS = {1: "엘리시온", 2: "미실리스", 3: "테트라", 4: "필그림", 7: "어브노말"}


class EvaluationError(ValueError):
    def __init__(self, code, message, fields=None):
        super().__init__(message)
        self.code, self.fields = code, fields or []

    def as_result(self):
        return {"status": "unavailable", "code": self.code,
                "message": str(self), "missingFields": self.fields}


def integer(value, path, low, high):
    if type(value) is not int or not low <= value <= high:
        raise EvaluationError("invalid_growth", "육성 정보의 값이나 범위를 확인해 주세요.", [path])
    return value


def mapping(value, path):
    if not isinstance(value, dict):
        raise EvaluationError("missing_growth", "필요한 육성 정보가 없습니다. 다시 동기화해 주세요.", [path])
    return value


def normalize(body, engine_dir, *, require_verified_source=True):
    mapping(body, "request")
    target = TARGETS.get(body.get("nikkeId"))
    if target is None:
        raise EvaluationError("unsupported_nikke", "아직 지원하지 않는 니케입니다.")
    if body.get("evaluationVersion", target["version"]) != target["version"]:
        raise EvaluationError("unsupported_version", "지원하지 않는 평가 버전입니다.")
    char = mapping(body.get("character"), "character")
    quality = char.get("growthDataQuality")
    if not isinstance(quality, dict):
        quality = {}
    # The embedded calculator accepts the displayed stored spec directly, including
    # legacy snapshots. Known collection failures still fail; missing values below
    # are never replaced with the calculator's default growth.
    if (require_verified_source or "growthDataQuality" in char) and (
            quality.get("schemaVersion") != 1 or quality.get("complete") is not True):
        raise EvaluationError("resync_required", "육성 정보의 수집 상태를 확인할 수 없습니다. 계정을 다시 동기화해 주세요.",
                              quality.get("missingFields") or ["growthDataQuality"])
    if char.get("name_code") != target["nameCode"]:
        raise EvaluationError("identity_mismatch", "평가 대상과 육성 정보가 일치하지 않습니다.")
    skills = mapping(char.get("skills"), "skills")
    growth = {
        "level": 400,
        "breakthrough": integer(char.get("grade"), "grade", 0, 3),
        "core_enhancement": integer(char.get("core"), "core", 0, 7),
        "affinity": max(1, integer(char.get("bondLevel"), "bondLevel", 0, 40)),
        "skill_levels": [integer(skills.get(k), "skills." + k, 1, 10) for k in ("skill1", "skill2", "burst")],
        "equipment": {p: {"tier": "없음", "level": 0, "skills": []} for p in PARTS.values()},
        "overload": {k: [] for k in OPTION_GROUPS.values()},
        "favorite_stage": 0,
    }
    if growth["core_enhancement"] and growth["breakthrough"] != 3:
        raise EvaluationError("invalid_growth", "코어 강화와 한계돌파 정보가 일치하지 않습니다.", ["core", "grade"])
    equipment = char.get("equipment")
    if not isinstance(equipment, list) or len(equipment) > 4:
        raise EvaluationError("invalid_growth", "장비 정보를 확인해 주세요.", ["equipment"])
    seen = set()
    for eq in equipment:
        mapping(eq, "equipment")
        slot = eq.get("slot")
        if slot not in PARTS or slot in seen:
            raise EvaluationError("invalid_growth", "장비 부위가 중복되거나 올바르지 않습니다.", ["equipment.slot"])
        seen.add(slot)
        tier = integer(eq.get("tier"), slot + ".tier", 1, 10)
        tid = integer(eq.get("tid"), slot + ".tid", 1, 99999999)
        if (tid // 100) % 100 != tier:
            raise EvaluationError("invalid_growth", "장비 ID와 등급이 일치하지 않습니다.", [slot + ".tid"])
        # Exact class/slot equipment IDs registered in Mimir's BlablaMap.
        prefix = {"head": 310, "torso": 320, "arm": 330, "leg": 340}[slot] + target["classIndex"]
        if tid != prefix * 10000 + tier * 100 + 1:
            raise EvaluationError("unsupported_equipment", "니케의 장비 ID와 부위를 확인할 수 없습니다.", [slot + ".tid"])
        lv = integer(eq.get("level"), slot + ".level", 0, 5)
        entry = {"level": lv, "skills": []}
        if tier < 10:
            entry["tier"] = f"T{tier}"
            corp = integer(eq.get("corporationType"), slot + ".corporationType", 0, 7)
            if corp:
                if corp not in CORPS or tier != 9:
                    raise EvaluationError("unsupported_equipment", "지원하지 않는 기업 장비입니다.", [slot])
                entry["corp"] = CORPS[corp]
            elif lv:
                # This engine ignores enhancement on ordinary gear. Do not silently lose it.
                raise EvaluationError("unsupported_equipment", "일반 장비 강화 효과는 아직 검증되지 않았습니다.", [slot])
        options = eq.get("overloadOptions")
        if not isinstance(options, list) or len(options) != 3:
            raise EvaluationError("invalid_growth", "오버로드 옵션의 수집 상태를 확인해 주세요.", [slot + ".overloadOptions"])
        used_options = set()
        for option in options:
            integer(option, slot + ".option", 0, 99999999)
            if option == 0:
                continue
            group, level = divmod(option, 100)
            if tier != 10 or group not in OPTION_GROUPS or not 1 <= level <= 15 or group in used_options:
                raise EvaluationError("unsupported_option", "알 수 없거나 중복된 오버로드 옵션입니다.", [slot + ".overloadOptions"])
            used_options.add(group)
            growth["overload"][OPTION_GROUPS[group]].append(level)
        growth["equipment"][PARTS[slot]] = entry
    for levels in growth["overload"].values():
        levels.sort(reverse=True)

    if "favoriteItem" not in char:
        raise EvaluationError("missing_growth", "소장품 수집 정보가 없습니다.", ["favoriteItem"])
    item = char["favoriteItem"]
    if item is None:
        growth["collection_stage"] = "없음"
    else:
        mapping(item, "favoriteItem")
        # IDs verified against BLABLALINK favorite_rare_map + each weapon record.
        grade = target["collectionIds"].get(str(item.get("tid")))
        if grade is None:
            raise EvaluationError("unsupported_collection", "해당 무기의 소장품 ID를 확인할 수 없습니다.", ["favoriteItem.tid"])
        growth["collection_stage"] = grade + str(integer(item.get("level"), "favoriteItem.level", 0, 15))

    cube = char.get("harmonyCube")
    if cube is None:
        raise EvaluationError("unsupported_cube", "큐브 미장착 상태의 딜량 계산은 아직 지원하지 않습니다.", ["harmonyCube"])
    mapping(cube, "harmonyCube")
    table = json.loads((Path(engine_dir) / "data/base_stat_tables/cube.json").read_text(encoding="utf-8"))
    match = next(((n, d) for n, d in table.items() if isinstance(d, dict) and d.get("id") == cube.get("tid")), None)
    if match is None or match[1].get("unsupported"):
        raise EvaluationError("unsupported_cube", "장착한 큐브의 효과를 계산기가 지원하지 않습니다.", ["harmonyCube.tid"])
    growth["cube"] = {"name": match[0], "level": integer(cube.get("level"), "harmonyCube.level", 1, 15)}

    researches = body.get("recycleRoom")
    if body.get("recycleRoomComplete") is not True or not isinstance(researches, list):
        raise EvaluationError("resync_required", "재활용 연구실 정보를 다시 동기화해 주세요.", ["recycleRoom"])
    console = {}
    for tid, key in ((1001, "common_level"), (target["classResearch"], "class_level"),
                     (target["companyResearch"], "company_level")):
        hits = [r for r in researches if isinstance(r, dict) and r.get("tid") == tid]
        if len(hits) != 1:
            raise EvaluationError("missing_growth", "해당 니케에게 적용되는 연구실 정보가 없습니다.", [f"recycleRoom.{tid}"])
        console[key] = integer(hits[0].get("lv"), f"recycleRoom.{tid}.lv", 0, 1000)
    growth["console"] = console
    return growth
