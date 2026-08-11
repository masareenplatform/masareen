#!/bin/bash
cd /home/sms/masarenfinal/backend
export PYTHONPATH="."
export DATABASE_URL="postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren"
export REDIS_URL="redis://localhost:6379"
export JWT_SECRET="masaren-alpha-change-me"
export JWT_ALGORITHM="HS256"
export CORS_ORIGINS="*"
export AUTO_VERIFY_ON_REGISTER="true"
exec .venv_linux/bin/python -m uvicorn combined.main:app --host 0.0.0.0 --port 8080 --log-level info
