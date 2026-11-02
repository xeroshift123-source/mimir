"""Local CLI. Input is a Mimir snapshot subset, not an engine request."""
import argparse
import json
import os
from pathlib import Path
from .adapter import EvaluationError
from .evaluator import Evaluator

parser = argparse.ArgumentParser()
parser.add_argument("input", type=Path)
parser.add_argument("--engine", default=os.environ.get("NIKKE_CALC_DIR"))
parser.add_argument("--output", type=Path)
args = parser.parse_args()
if not args.engine:
    parser.error("--engine or NIKKE_CALC_DIR is required")
try:
    result = Evaluator(args.engine).evaluate(json.loads(args.input.read_text(encoding="utf-8")))
except EvaluationError as error:
    result = error.as_result()
text = json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False)
if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(text + "\n", encoding="utf-8")
else:
    print(text)
raise SystemExit(0 if result["status"] == "ok" else 2)
