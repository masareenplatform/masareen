FROM python:3.12-slim
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev && rm -rf /var/lib/apt/lists/*

COPY reputation/impact-score-service/python/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY shared /app/shared
COPY reputation/impact-score-service/python /app/service

ENV PYTHONPATH=/app
WORKDIR /app/service
EXPOSE 8094
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8094"]
