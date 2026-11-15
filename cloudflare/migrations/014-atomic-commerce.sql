-- ---------- Atomic commerce, task ownership and evidence linkage (v1.3) ----------
ALTER TABLE tasks ADD COLUMN author_id INTEGER;
CREATE INDEX IF NOT EXISTS idx_tasks_author ON tasks(author_id);

ALTER TABLE evidence ADD COLUMN task_id INTEGER;
CREATE INDEX IF NOT EXISTS idx_evidence_task ON evidence(task_id);

CREATE TABLE IF NOT EXISTS daily_claims (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id   INTEGER NOT NULL,
  claim_date TEXT NOT NULL,
  amount     REAL NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE (owner_id, claim_date)
);
CREATE INDEX IF NOT EXISTS idx_daily_claims_owner ON daily_claims(owner_id, claim_date);
