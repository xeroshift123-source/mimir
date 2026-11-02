"""Per-character fixed Solo Raid functions. No API or account lookup."""
import copy
import json
from pathlib import Path

from .adapter import TARGETS, TARGETS_BY_CODE, EvaluationError, normalize

ROOT = Path(__file__).resolve().parent


def _calculate(target_id, spec, engine_dir):
    """Only target growth varies; each target's party and battle are fixed."""
    from runner.sim import prepare, execute
    from runner.spec import is_preview

    target = TARGETS[target_id]
    context_path = ROOT / "contexts" / (target["version"] + ".json")
    if not context_path.exists():
        raise EvaluationError("context_unavailable", "해당 시즌의 계산 조건을 준비 중입니다.")
    context = json.loads(context_path.read_text(encoding="utf-8"))
    body = {"nikkeId": target_id, "evaluationVersion": target["version"],
            "character": spec.get("character"), "recycleRoom": spec.get("recycleRoom"),
            "recycleRoomComplete": isinstance(spec.get("recycleRoom"), list)}
    request = copy.deepcopy(context["request"])
    request["profile"]["chars"][target["name"]] = normalize(
        body, engine_dir, require_verified_source=False)
    if isinstance(request.get("boss"), str):
        request["boss"] = str(Path(engine_dir) / request["boss"])
    run = prepare(request)
    if any(c["level"] != 400 or is_preview(c["name"]) for c in run.squad):
        raise ValueError("Invalid fixed evaluation profile")
    result = execute(run)
    damage = int(result.char_total[target["name"]])
    return damage * 5 / 100_000_000


def calculate_rapi_score(spec, engine_dir):
    return _calculate("rapi_red_hood", spec, engine_dir)


def calculate_snow_white_heavy_arms_score(spec, engine_dir):
    return _calculate("snow_white_heavy_arms", spec, engine_dir)


def calculate_scarlet_black_shadow_score(spec, engine_dir):
    return _calculate("scarlet_black_shadow", spec, engine_dir)


def calculate_cinderella_score(spec, engine_dir):
    return _calculate("cinderella", spec, engine_dir)


def calculate_cinderella_crystal_wave_score(spec, engine_dir):
    return _calculate("cinderella_crystal_wave", spec, engine_dir)


def calculate_dorothy_serendipity_score(spec, engine_dir):
    return _calculate("dorothy_serendipity", spec, engine_dir)


def calculate_mihara_bonding_chain_score(spec, engine_dir):
    return _calculate("mihara_bonding_chain", spec, engine_dir)


def calculate_diesel_winter_sweets_score(spec, engine_dir):
    return _calculate("diesel_winter_sweets", spec, engine_dir)


def calculate_liberalio_score(spec, engine_dir):
    return _calculate("liberalio", spec, engine_dir)


def calculate_nayuta_score(spec, engine_dir):
    return _calculate("nayuta", spec, engine_dir)


def calculate_little_mermaid_score(spec, engine_dir):
    return _calculate("little_mermaid", spec, engine_dir)


def calculate_neon_vision_eye_score(spec, engine_dir):
    return _calculate("neon_vision_eye", spec, engine_dir)


def calculate_anis_star_score(spec, engine_dir):
    return _calculate("anis_star", spec, engine_dir)


def calculate_marciana_marine_study_score(spec, engine_dir):
    return _calculate("marciana_marine_study", spec, engine_dir)


def calculate_nikke_score(spec, engine_dir):
    target = TARGETS_BY_CODE.get(spec.get("character", {}).get("name_code"))
    if target is None:
        raise EvaluationError("unsupported_nikke", "아직 지원하지 않는 니케입니다.")
    return _calculate(target["id"], spec, engine_dir)
