# MASAREN Demo — Presenter Cheatsheet

## Quick Start
```bash
pip install fastapi uvicorn python-jose passlib pydantic
uvicorn demo:app --reload
# Open http://localhost:8000
# Login: sara@masaren.io / demo1234
```

## Key Talking Points per Screen

### Dashboard
- "Every number here comes from an immutable event — like a blockchain for human impact"
- "The $X total impact value is calculated using ILO wage frameworks and SDG indices"

### Programs
- "Programs are containers for verified real-world activities — like GitHub repos for impact"
- "SDG tagging means every activity is automatically mapped to the UN's 17 development goals"

### Tasks
- "The task state machine is immutable — PENDING→ASSIGNED→IN_PROGRESS→SUBMITTED→VERIFIED→COMPLETED"
- "Every transition is recorded as an event. You can audit every step years later."

### Evidence
- "In production: the field worker takes a photo, GPS coordinates are captured automatically"
- "The AI analyses the image for authenticity — scene content, metadata, fraud signals"
- "Confidence > 80% → auto-approved. Below → human review queue"
- "One approved evidence → one Impact Asset → economic value in USD"

### Impact Passport
- "This is like a LinkedIn profile, but for verified real-world impact — not self-reported"
- "10 dimensions, each scored by AI based on what was actually done in the field"
- "Bronze → Silver → Gold → Platinum — opens doors to jobs, funding, scholarships"
- "Passport ID: MP-[user]-[tier]-[level] — portable across organizations"

### Event Stream
- "This is the heartbeat of MASAREN — every action, every decision, immutably recorded"
- "AI agents consume these events. Graph Synthesis updates the knowledge graph."
- "This stream is what you'd audit for ESG compliance or donor reporting"

## Common Questions

Q: "Is the AI real?"
A: "In this demo it's simulated. In production it calls GPT-4o Vision or Gemini Pro —
   same API, just routed to the cloud because our server has no GPU."

Q: "Where is the data stored?"
A: "Demo: in-memory. Production: PostgreSQL + PostGIS (geospatial),
   Neo4j for the knowledge graph, Redis for sessions, OpenSearch for search."

Q: "Can we integrate our existing system?"
A: "Yes — we expose REST APIs, a Kafka event stream, and will have SDKs.
   Any system that can make an HTTP call can integrate."

Q: "How do you prevent fraud?"
A: "Three layers: AI Vision Agent (photo analysis), Fraud Detection Agent
   (GPS spoofing, duplicate hashes, timeline manipulation), and human review
   for anything below 80% AI confidence."
