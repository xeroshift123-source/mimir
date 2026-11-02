import copy
import json
import os
from pathlib import Path
import sys
import unittest

from services.nikke_score.adapter import EvaluationError, TARGET_NAME, normalize
from services.nikke_score.evaluator import Evaluator, ROOT
from tools.build_rapi_score_context import select_team


class SelectionTests(unittest.TestCase):
    def test_target_filter_order_aggregation_and_count_not_weights(self):
        rows = [{"server": "KR", "playerid": i, "teams": [
            {"characters": order, "count": 9999}]} for i, order in enumerate([
                ["T", "A", "B", "C", "D"], ["D", "C", "B", "A", "T"],
                ["T", "A", "B", "C", "D"], ["Q", "A", "B", "C", "D"]])]
        order, count, order_count, _, _ = select_team(rows, "T")
        self.assertEqual(order, ["T", "A", "B", "C", "D"])
        self.assertEqual((count, order_count), (3, 2))
        with self.assertRaises(ValueError):
            select_team(rows + [rows[0]], "T")


@unittest.skipUnless(os.environ.get("NIKKE_CALC_DIR"), "Set NIKKE_CALC_DIR to the pinned engine")
class AdapterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.evaluator = Evaluator(os.environ["NIKKE_CALC_DIR"])
        sys.path.insert(0, str(cls.evaluator.engine_dir))
        from runner.sim import prepare
        cls.engine_prepare = staticmethod(prepare)

    def setUp(self):
        self.body = json.loads((ROOT / "examples/rapi-reference.input.json").read_text(encoding="utf-8"))

    def assemble(self, body):
        _, request, _ = self.evaluator.prepare(body)
        # Engine boss paths are relative to its checkout.
        if "boss" in request:
            request["boss"] = str(self.evaluator.engine_dir / request["boss"])
        return self.engine_prepare(request)

    def test_actual_account_level_does_not_change_input_hash_or_400_level(self):
        a = self.evaluator.prepare(self.body)
        self.body["character"]["level"] = 999
        self.body["character"]["combat"] = 1
        b = self.evaluator.prepare(self.body)
        self.assertEqual(a, b)
        self.assertTrue(all(c["level"] == 400 for c in self.assemble(self.body).squad))

    def test_empty_options_and_unequipped_collection_leave_no_defaults(self):
        for eq in self.body["character"]["equipment"]:
            eq["overloadOptions"] = [0, 0, 0]
        self.body["character"]["favoriteItem"] = None
        target = next(c for c in self.assemble(self.body).squad if c["name"] == TARGET_NAME)
        self.assertTrue(all(v == 0 or v == [] for v in target["equip_skills"].values()))
        self.assertEqual(target["collection_stage"], "없음")

    def test_user_research_only_applies_to_target(self):
        before = self.assemble(self.body).squad
        self.body["recycleRoom"][0]["lv"] = 1
        after = self.assemble(self.body).squad
        for a, b in zip(before, after):
            if a["name"] == TARGET_NAME:
                self.assertNotEqual(a["console"], b["console"])
            else:
                self.assertEqual(a, b)

    def test_rapi_uses_elysion_research_not_pilgrim(self):
        self.body["recycleRoom"].append({"tid": 1204, "lv": 999})
        growth = normalize(self.body, self.evaluator.engine_dir)
        self.assertEqual(growth["console"]["company_level"], 100)
        next(r for r in self.body["recycleRoom"] if r["tid"] == 1201)["lv"] = 123
        growth = normalize(self.body, self.evaluator.engine_dir)
        self.assertEqual(growth["console"]["company_level"], 123)

    def test_missing_quality_unknown_ids_and_null_cube_are_not_estimated(self):
        for key, value, code in [("growthDataQuality", {}, "resync_required"),
                                 ("harmonyCube", None, "unsupported_cube"),
                                 ("favoriteItem", {"tid": 99, "level": 1}, "unsupported_collection")]:
            with self.subTest(key=key):
                body = copy.deepcopy(self.body)
                body["character"][key] = value
                with self.assertRaises(EvaluationError) as caught:
                    normalize(body, self.evaluator.engine_dir)
                self.assertEqual(caught.exception.code, code)

    def test_known_empty_equipment_stays_empty_and_cube_level_is_real(self):
        self.body["character"]["equipment"] = []
        self.body["character"]["harmonyCube"]["level"] = 7
        target = next(c for c in self.assemble(self.body).squad if c["name"] == TARGET_NAME)
        self.assertTrue(all(e["tier"] == "없음" for e in target["equipment"].values()))
        self.assertEqual(target["cube"]["level"], 7)

    def test_equipment_id_must_match_target_class_slot_and_known_variant(self):
        for tid in (3211001, 3121001, 3111002):
            with self.subTest(tid=tid):
                self.body["character"]["equipment"][0]["tid"] = tid
                with self.assertRaises(EvaluationError) as caught:
                    normalize(self.body, self.evaluator.engine_dir)
                self.assertEqual(caught.exception.code, "unsupported_equipment")

    def test_serialized_context_contains_the_target_and_correct_weakness(self):
        context = self.evaluator.context
        self.assertEqual(context["targetElement"], "Fire")
        self.assertEqual(context["source"]["seasonId"], 40)
        self.assertEqual(context["source"]["selectedTeamCount"], 270)
        self.assertIn(TARGET_NAME, context["request"]["squad"])
        run = self.assemble(self.body)
        self.assertEqual(run.enemy["code"], "풍압")


if __name__ == "__main__":
    unittest.main()
