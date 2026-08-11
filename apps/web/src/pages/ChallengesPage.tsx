import { useEffect, useState } from "react";
import { challengeService, type Challenge } from "../services/api";
import { useAuth } from "../store/authStore";

// SDG accent colours (mirrors the mobile palette) for the goal tags.
const SDG_COLORS: Record<number, string> = {
  1: "#E5243B", 2: "#DDA63A", 3: "#FD6925", 4: "#C5192D", 5: "#EF402D", 6: "#26BDE2",
  7: "#FCC30B", 8: "#A21942", 9: "#FD6925", 10: "#DD1367", 11: "#FD9D24", 12: "#BF8B2E",
  13: "#3F7E44", 14: "#0A97D9", 15: "#56C02B", 16: "#00689D", 17: "#19486A",
};

export default function ChallengesPage() {
  const { user } = useAuth();
  const [items, setItems] = useState<Challenge[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState<string | null>(null);

  useEffect(() => {
    challengeService.list().then(setItems).catch(() => setItems([])).finally(() => setLoading(false));
  }, []);

  const toggle = async (c: Challenge) => {
    setBusy(c.id);
    try {
      await challengeService.join(c.id);
      setItems((prev) => prev.map((e) => (e.id === c.id ? { ...e, joined: !e.joined, participants: e.participants + (e.joined ? -1 : 1), progress: e.joined ? e.progress : Math.min(1, e.progress + 0.05) } : e)));
    } finally {
      setBusy(null);
    }
  };

  const active = items.filter((c) => c.joined).length;

  return (
    <div>
      <div className="mb-6 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="font-display text-2xl font-bold text-ink">Challenges</h1>
          <p className="text-sm text-ink/50">
            {active} active for you · complete verified actions to earn MASAREEN Coin
          </p>
        </div>
      </div>

      {loading ? (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="skeleton h-56" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="glass-card text-center text-ink/50">No challenges available right now.</div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {items.map((c) => {
            const color = SDG_COLORS[c.sdg] ?? "#0250A3";
            return (
              <article key={c.id} className="glass-card flex flex-col">
                <div className="mb-3 flex items-center gap-3">
                  <div
                    className="grid h-11 w-11 place-items-center rounded-xl text-ink"
                    style={{ background: color }}
                  >
                    <span className="text-lg font-bold">#{c.sdg}</span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <h3 className="truncate text-lg font-semibold text-ink">{c.title}</h3>
                    <span
                      className="inline-block rounded-full px-2 py-0.5 text-[11px] font-semibold text-ink"
                      style={{ background: color }}
                    >
                      SDG {c.sdg}
                    </span>
                  </div>
                  <span className="rounded-full bg-gold/15 px-2.5 py-1 text-xs font-bold text-gold">
                    {c.rewardMrc.toLocaleString()} MRC
                  </span>
                </div>

                <p className="text-sm text-ink/55">{c.description}</p>

                <div className="mt-4">
                  <div className="mb-1 flex items-center justify-between text-xs text-ink/60">
                    <span>{Math.round(c.progress * 100)}% complete</span>
                    <span>{c.participants.toLocaleString()} joined · {c.endsInDays}d left</span>
                  </div>
                  <div className="h-2 w-full overflow-hidden rounded-full bg-navy-200">
                    <div
                      className="h-full rounded-full"
                      style={{ width: `${Math.round(c.progress * 100)}%`, background: color }}
                    />
                  </div>
                </div>

                <button
                  className={`mt-5 w-full rounded-xl px-4 py-2.5 text-sm font-bold transition ${
                    c.joined ? "bg-navy-200 text-ink hover:bg-navy-300" : "btn-gold"
                  }`}
                  disabled={busy === c.id}
                  onClick={() => toggle(c)}
                >
                  {c.joined ? "Joined — tap to leave" : "Join challenge"}
                </button>
              </article>
            );
          })}
        </div>
      )}
    </div>
  );
}
