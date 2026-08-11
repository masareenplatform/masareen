import { useEffect, useMemo, useState } from "react";
import { opportunityService } from "../services/api";
import { useAuth } from "../store/authStore";
import { useI18n } from "../i18n";
import type { Opportunity } from "../types";

const TYPES = ["JOB", "FUNDING", "SCHOLARSHIP", "RESEARCH", "CONSULTING", "VOLUNTEER"] as const;
type OppType = (typeof TYPES)[number];

const typeAccent: Record<string, string> = {
  JOB: "from-sky-400/30 to-sky-500/10 text-sky-200",
  FUNDING: "from-emerald-400/30 to-emerald-500/10 text-emerald-200",
  SCHOLARSHIP: "from-amber-400/30 to-amber-500/10 text-amber-200",
  RESEARCH: "from-indigo-400/30 to-indigo-500/10 text-indigo-200",
  CONSULTING: "from-fuchsia-400/30 to-fuchsia-500/10 text-fuchsia-200",
  VOLUNTEER: "from-pink-400/30 to-pink-500/10 text-pink-200",
};

export default function OpportunitiesPage() {
  const { user } = useAuth();
  const { t, dir } = useI18n();
  const [opps, setOpps] = useState<Opportunity[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<OppType | "ALL">("ALL");
  const [applied, setApplied] = useState<Record<string, boolean>>({});
  const [busy, setBusy] = useState<string | null>(null);

  useEffect(() => {
    opportunityService
      .list()
      .then((data) => setOpps(data as Opportunity[]))
      .catch(() => setOpps([]))
      .finally(() => setLoading(false));
  }, []);

  const filtered = useMemo(
    () => (filter === "ALL" ? opps : opps.filter((o) => o.opp_type === filter)),
    [opps, filter]
  );

  const apply = async (id: string) => {
    setBusy(id);
    try {
      await opportunityService.apply(id, user?.id || "current-user");
      setApplied((s) => ({ ...s, [id]: true }));
    } catch (e) {
      console.error("Apply failed", e);
    } finally {
      setBusy(null);
    }
  };

  return (
    <div>
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <h1 className="font-display text-2xl font-bold text-white">{t("marketplace.title")}</h1>
        <div className="flex flex-wrap gap-2">
          <button
            className={`chip ${filter === "ALL" ? "border-gold/50 text-gold" : ""}`}
            onClick={() => setFilter("ALL")}
          >
            {t("common.all")}
          </button>
          {TYPES.map((ty) => (
            <button
              key={ty}
              className={`chip ${filter === ty ? "border-gold/50 text-gold" : ""}`}
              onClick={() => setFilter(ty)}
            >
              {ty}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="grid gap-4 sm:grid-cols-2">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="skeleton h-40" />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <div className="glass-card text-center text-white/50">{t("marketplace.empty")}</div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {filtered.map((o) => (
            <article key={o.id} className="glass-card flex flex-col">
              <div
                className={`mb-3 inline-flex w-fit rounded-lg bg-gradient-to-br px-2.5 py-1 text-xs font-semibold ${
                  typeAccent[o.opp_type] || "from-white/10 text-white/70"
                }`}
              >
                {o.opp_type}
              </div>
              <h3 className="text-lg font-semibold text-white">{o.title}</h3>
              <p className="mt-1 text-sm text-white/50">
                Min PMS {o.min_pms_score} · {o.status}
              </p>
              <div className="mt-3 flex flex-wrap gap-1.5">
                {(o.required_skills || []).slice(0, 4).map((s) => (
                  <span key={s} className="chip text-white/60">
                    {s}
                  </span>
                ))}
              </div>
              <div className="mt-auto pt-5">
                <button
                  className="btn-gold w-full"
                  disabled={!!applied[o.id] || busy === o.id}
                  onClick={() => apply(o.id)}
                >
                  {applied[o.id] ? t("action.applied") : t("action.apply")}
                </button>
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
