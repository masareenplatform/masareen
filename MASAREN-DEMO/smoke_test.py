"""End-to-end smoke test for the MASAREN demo BFF (no backend required).

Exercises the real persisted flow: register -> login -> create org -> program
-> task -> submit evidence -> list evidence -> portfolio. All state is real
SQLite; backend calls are best-effort and will fail closed (IN_REVIEW) when the
backend is unreachable (which it is in this no-Docker environment).
"""
import os
import sys

from fastapi.testclient import TestClient

# force a fresh DB so the run is deterministic
DB = os.path.join(os.path.dirname(__file__), "smoke_test.db")
if os.path.exists(DB):
    os.remove(DB)
os.environ["DEMO_DB_PATH"] = DB


def main() -> int:
    # import demo after env is set so it picks up the temp DB
    import demo  # noqa: E402

    with TestClient(demo.app) as c:
        # register
        r = c.post("/api/auth/register", json={
            "email": "smoke@masaren.dev",
            "password": "demo1234",
            "full_name": "Smoke Tester",
            "role": "contributor",
            "country": "EG",
        })
        assert r.status_code == 200, (r.status_code, r.text)
        reg = r.json()
        assert "access_token" in reg, reg
        token = reg["access_token"]
        uid = reg["user_id"]
        print("register OK ->", reg.get("email"), uid)

        # create org
        r = c.post("/api/organizations", json={
            "name": "Smoke Org", "org_type": "ngo", "country": "EG",
            "description": "test", "website": "https://example.org",
        }, headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200, (r.status_code, r.text)
        org = r.json()
        print("org OK ->", org)

        # create program
        r = c.post("/api/programs", json={
            "title": "Smoke Program", "description": "test", "organization_id": org["id"],
            "sdgs": [1, 2],
        }, headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200, (r.status_code, r.text)
        prog = r.json()
        print("program OK ->", prog)

        # create task
        r = c.post("/api/tasks", json={
            "title": "Smoke Task", "description": "test", "program_id": prog["id"],
            "organization_id": org["id"],
        }, headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200, (r.status_code, r.text)
        task = r.json()
        print("task OK ->", task)

        # submit evidence (capture)
        r = c.post("/api/evidence", json={
            "task_id": task["id"], "media_type": "photo", "description": "smoke evidence",
            "latitude": 30.0, "longitude": 31.0, "media_url": "https://example.org/x.jpg",
        }, headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200, (r.status_code, r.text)
        ev = r.json()
        print("evidence OK ->", ev)
        ev_id = ev["id"]

        # list evidence (normalized)
        r = c.get("/api/evidence", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200, (r.status_code, r.text)
        rows = r.json()
        assert isinstance(rows, list) and rows, rows
        print("list evidence OK -> count", len(rows), "| first title:", rows[0].get("title"))

        # portfolio
        r = c.get(f"/api/users/{uid}/portfolio", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200, (r.status_code, r.text)
        print("portfolio OK ->", r.json())

    if os.path.exists(DB):
        os.remove(DB)
    print("\nALL SMOKE CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
