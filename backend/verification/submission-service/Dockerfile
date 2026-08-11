FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app

WORKDIR /app

COPY backend/shared/ ./shared/
COPY backend/verification/submission-service/ .

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8001

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8001/health/live || exit 1

CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8001"]
