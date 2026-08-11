"""Evidence Service — outbound events.

Domain events are persisted transactionally by the repository:
- captured/uploaded/verified events are written to the ``evidence_events`` table
  in the same transaction as the state change (event-sourced), and
- integration events are relayed via the shared transactional outbox
  (``shared.utils.outbox.OutboxWriter``) wired in ``src/api``.

There is intentionally no fire-and-forget publisher here — that would risk losing
events on failure. This module is kept as the package marker for the events layer.
"""
