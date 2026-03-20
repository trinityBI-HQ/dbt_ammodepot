FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN pip install --no-cache-dir uv

WORKDIR /app

COPY ecs/pyproject.toml ./pyproject.toml
RUN uv sync --no-dev --frozen 2>/dev/null || uv sync --no-dev

COPY ammodepot/ ./ammodepot/
WORKDIR /app/ammodepot
RUN uv run dbt deps --profiles-dir .

COPY ecs/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
