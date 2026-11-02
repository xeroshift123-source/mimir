import copy
import json
import os
from pathlib import Path
import unittest
from services.nikke_score.adapter import TARGETS, EvaluationError, normalize

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.environ.get("NIKKE_CALC_DIR"), "Set NIKKE_CALC_DIR")
class TargetTests(unittest.TestCase):
    def setUp(self):
        self.fixtures = json.loads((ROOT / "examples/score-reference.inputs.json").read_text(encoding="utf-8"))

    def test_common_enemy_differs_only_in_advantageous_code(self):
        enemies = []
        expected = {"Fire":"풍압", "Water":"작열", "Wind":"철갑", "Iron":"전격", "Electric":"수냉"}
        for target in TARGETS.values():
            context = json.loads((ROOT / "contexts" / (target["version"] + ".json")).read_text(encoding="utf-8"))
            request = context["request"]
            self.assertNotIn("boss", request)
            self.assertIn(target["name"], request["squad"])
            enemy = copy.deepcopy(request["enemy"])
            self.assertEqual(enemy.pop("code"), expected[target["element"]])
            self.assertNotIn("patterns", enemy)
            self.assertFalse(enemy["has_parts"])
            enemies.append(enemy)
        self.assertTrue(all(e == enemies[0] for e in enemies))

    def test_all_target_mappings_and_wrong_weapon_or_identity(self):
        for target_id, target in TARGETS.items():
            with self.subTest(target=target_id):
                body = copy.deepcopy(self.fixtures[target_id])
                growth = normalize(body, os.environ["NIKKE_CALC_DIR"])
                self.assertEqual(growth["level"], 400)
                self.assertEqual(growth["collection_stage"], "SR15")
                body["character"]["favoriteItem"]["tid"] = 999999
                with self.assertRaises(EvaluationError):
                    normalize(body, os.environ["NIKKE_CALC_DIR"])
                body = copy.deepcopy(self.fixtures[target_id])
                body["character"]["name_code"] = 0
                with self.assertRaises(EvaluationError):
                    normalize(body, os.environ["NIKKE_CALC_DIR"])

    def test_cinderella_def_equipment_and_research_are_not_atk(self):
        body = copy.deepcopy(self.fixtures["cinderella"])
        body["recycleRoom"].append({"tid":1101, "lv":999})
        self.assertEqual(normalize(body, os.environ["NIKKE_CALC_DIR"])["console"]["class_level"], 100)
        body["character"]["equipment"][0]["tid"] = 3111001
        with self.assertRaises(EvaluationError):
            normalize(body, os.environ["NIKKE_CALC_DIR"])

    def test_registered_identity_role_weapon_and_company_match_sources(self):
        assets = json.loads((ROOT.parents[1] / "assets/nikkes.json").read_text(encoding="utf-8"))
        assets_by_code = {c["blablaNameCode"]: c for c in assets if c.get("blablaNameCode")}
        engine = json.loads((Path(os.environ["NIKKE_CALC_DIR"]) / "data/parsed_nikke.json").read_text(encoding="utf-8"))
        self.assertEqual(len(TARGETS), 14)
        self.assertEqual(len({t["nameCode"] for t in TARGETS.values()}), 14)
        for target in TARGETS.values():
            with self.subTest(target=target["id"]):
                source, parsed = assets_by_code[target["nameCode"]], engine[target["name"]]
                self.assertEqual(source["name"].replace(" ", ""), target["name"].replace(" ", ""))
                self.assertEqual(source["element"], target["element"])
                self.assertEqual(parsed["weapon_type"], target["weapon"])
                role = {"화력형": 1, "방어형": 2, "지원형": 3}[parsed["class"]]
                self.assertEqual(target["classIndex"], role)
                self.assertEqual(target["classResearch"], 1100 + role)
                company = {"엘리시온": 1201, "미실리스": 1202, "테트라": 1203, "필그림": 1204}
                self.assertEqual(target["companyResearch"], company[parsed["manufacturer"]])

    def test_support_and_defender_research_does_not_use_attacker_values(self):
        for key in ("nayuta", "little_mermaid", "anis_star"):
            with self.subTest(target=key):
                body = copy.deepcopy(self.fixtures[key])
                body["recycleRoom"].append({"tid": 1101, "lv": 999})
                growth = normalize(body, os.environ["NIKKE_CALC_DIR"])
                self.assertEqual(growth["console"]["class_level"], 100)
                body["character"]["equipment"][0]["tid"] = 3111001
                with self.assertRaises(EvaluationError):
                    normalize(body, os.environ["NIKKE_CALC_DIR"])
