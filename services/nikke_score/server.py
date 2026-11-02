"""Private Cloud Run WSGI service; localhost server for development."""
from collections import OrderedDict
import copy
import json
import os
import threading
from wsgiref.simple_server import make_server
from .adapter import EvaluationError
from .evaluator import Evaluator

_evaluator = None
_init_lock = threading.Lock()
_gate = threading.BoundedSemaphore(1)
_cache_lock = threading.Lock()
_cache = OrderedDict()
MAX_BODY = 65536


def evaluator():
    global _evaluator
    with _init_lock:
        if _evaluator is None:
            _evaluator = Evaluator(os.environ["NIKKE_CALC_DIR"])
    return _evaluator


def evaluate(body):
    instance = evaluator()
    _, _, key = instance.prepare(body)
    with _cache_lock:
        if key in _cache:
            _cache.move_to_end(key)
            return {**copy.deepcopy(_cache[key]), "cacheHit": True}
    if not _gate.acquire(blocking=False):
        raise EvaluationError("busy", "다른 딜량을 계산 중입니다. 잠시 후 다시 시도해 주세요.")
    try:
        result = instance.evaluate(body)
        with _cache_lock:
            _cache[key] = copy.deepcopy(result)
            while len(_cache) > 64:
                _cache.popitem(last=False)
        return {**result, "cacheHit": False}
    finally:
        _gate.release()


def app(environ, start_response):
    status = "200 OK"
    try:
        path, method = environ.get("PATH_INFO"), environ.get("REQUEST_METHOD")
        if path == "/health" and method == "GET":
            result = {"status": "ready", "contextHash": evaluator().context_hash}
        elif path == "/evaluate" and method == "POST":
            size = int(environ.get("CONTENT_LENGTH") or 0)
            if not 0 < size <= MAX_BODY:
                status, result = "413 Payload Too Large", {"error": "Invalid request size"}
            else:
                result = evaluate(json.loads(environ["wsgi.input"].read(size)))
        else:
            status, result = "404 Not Found", {"error": "Not found"}
    except EvaluationError as error:
        result = error.as_result()
    except (ValueError, TypeError):
        status, result = "400 Bad Request", {"error": "Invalid JSON request"}
    except Exception:
        import traceback
        traceback.print_exc()
        status, result = "503 Service Unavailable", {"error": "Evaluation service unavailable"}
    encoded = json.dumps(result, ensure_ascii=False, allow_nan=False).encode("utf-8")
    start_response(status, [("Content-Type", "application/json; charset=utf-8"),
                            ("Content-Length", str(len(encoded))), ("Cache-Control", "no-store")])
    return [encoded]


if __name__ == "__main__":
    evaluator()
    with make_server("127.0.0.1", int(os.environ.get("PORT", "8080")), app) as server:
        print("Local damage service: http://127.0.0.1:8080", flush=True)
        server.serve_forever()
