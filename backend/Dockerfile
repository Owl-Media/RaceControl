# RaceControl API — container image for Coolify (or any Docker host).
#
# Local development does NOT need this: use ./run.sh instead.
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# curl is only needed for the container healthcheck.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies first so this layer caches across code changes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# FastF1 caches downloaded timing/telemetry here. Mount a persistent volume at
# /data in Coolify, otherwise every redeploy re-downloads everything (slow, and
# it burns through the upstream rate limits).
ENV FASTF1_CACHE=/data/fastf1_cache
RUN mkdir -p /data/fastf1_cache

# Run as a non-root user.
RUN useradd --create-home --uid 1000 appuser \
    && chown -R appuser:appuser /app /data
USER appuser

ENV PORT=8000
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT}/api/health" || exit 1

# One worker by default: each worker keeps its own in-process session cache, so
# extra workers multiply memory use rather than sharing it. Raise WEB_CONCURRENCY
# only if you also raise the container's memory limit.
CMD ["sh", "-c", "exec uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000} --workers ${WEB_CONCURRENCY:-1} --timeout-keep-alive 65"]
