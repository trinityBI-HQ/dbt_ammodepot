FROM public.ecr.aws/lambda/python:3.11

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN pip install --no-cache-dir uv

COPY pyproject.toml ${LAMBDA_TASK_ROOT}/

WORKDIR ${LAMBDA_TASK_ROOT}

RUN uv pip install --system --no-cache -r pyproject.toml

COPY main.py ${LAMBDA_TASK_ROOT}/
COPY ssm-payloads/ ${LAMBDA_TASK_ROOT}/ssm-payloads/

CMD ["main.handler"]
