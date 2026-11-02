"""One engine process per evaluation: isolated RNG/state and a parent timeout."""
import contextlib
import copy
import json
import os
import sys


def main():
    engine = os.environ["NIKKE_CALC_DIR"]
    sys.path.insert(0, engine)
    os.chdir(engine)
    from runner.sim import prepare, execute, payload
    request = json.load(sys.stdin)
    with contextlib.redirect_stdout(sys.stderr):
        run = prepare(request)
        # Return the actually assembled growth as evidence, including fixed teammates.
        keys = ("level", "breakthrough", "core_enhancement", "affinity", "skill_levels",
                "equipment", "equip_skills", "cube", "console", "collection_stage", "favorite_stage", "control")
        applied = {c["name"]: {k: copy.deepcopy(c.get(k)) for k in keys} for c in run.squad}
        if any(c["level"] != 400 for c in run.squad):
            raise ValueError("Evaluation level is not 400")
        result = payload(run, execute(run))
    result["appliedGrowth"] = applied
    json.dump(result, sys.stdout, ensure_ascii=False, allow_nan=False)


if __name__ == "__main__":
    main()
