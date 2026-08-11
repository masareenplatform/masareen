FROM python:3.12-slim
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev && rm -rf /var/lib/apt/lists/*

COPY ai/fraud-service/python/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Shared kernel (required by the service at runtime) + service source.
COPY shared /app/shared
COPY ai/fraud-service/python /app/service

ENV PYTHONPATH=/app
WORKDIR /app/service
EXPOSE 8090
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8090"]
