FROM python:3.13-slim
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY engine_lock.json /tmp/engine_lock.json
RUN python -c "import json,subprocess; d=json.load(open('/tmp/engine_lock.json')); subprocess.run(['git','clone',d['repository'],'/opt/nikke-calc'],check=True); subprocess.run(['git','-C','/opt/nikke-calc','checkout','--detach',d['commit']],check=True)"
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
COPY . /app/services/nikke_score/
ENV NIKKE_CALC_DIR=/opt/nikke-calc PYTHONIOENCODING=utf-8 PYTHONDONTWRITEBYTECODE=1
# Deploy with authentication required; only the Firebase function identity may invoke.
CMD ["sh", "-c", "exec gunicorn --bind :${PORT:-8080} --workers 1 --threads 4 --timeout 110 services.nikke_score.server:app"]
