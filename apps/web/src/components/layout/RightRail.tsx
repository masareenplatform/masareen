import { useEffect, useState } from "react";
import { NavLink, Link } from "react-router-dom";
import { IconSparkles, IconTrending, IconUsers, IconCheck, IconBadge } from "../icons/Icons";
import { avatarColors, postService, recognizedInstitutions } from "../../services/postService";
import { userService } from "../../services/api";
import { useI18n } from "../../i18n";
import { useAuth } from "../../store/authStore";

interface Suggestion {
  id: string;
  full_name: string;
  email: string;
  role: string;
}

function MiniAvatar({ name, handle }: { name: string; handle: string }) {
  const { c1, c2 } = avatarColors(handle || name);
  return (
    <span
      className="avatar-gradient grid h-9 w-9 place-items-center rounded-full text-xs font-semibold text-white"
      style={{ ["--c1" as any]: c1, ["--c2" as any]: c2 }}
    >
      {(name?.[0] ?? "?").toUpperCase()}
    </span>
  );
}

export default function RightRail() {
  const { t } = useI18n();
  const { user } = useAuth();
  const [people, setPeople] = useState<Suggestion[]>([]);
  const [followed, setFollowed] = useState<Record<string, boolean>>({});
  const [pending, setPending] = useState<string | null>(null);
  const [trends, setTrends] = useState<{ tag: string; count: number }[]>([]);

  useEffect(() => {
    let alive = true;
    userService.suggestedUsers(6).then((list: any[]) => {
      if (!alive) return;
      setPeople(list.filter((p) => p.id !== user?.id));
    }).catch(() => {});
    setTrends(postService.trending());
    return () => { alive = false; };
  }, [user?.id]);

  async function follow(id: string) {
    setPending(id);
    try {
      await userService.follow(id);
      setFollowed((f) => ({ ...f, [id]: !f[id] }));
    } catch {
      /* keep optimistic state */
    } finally {
      setPending(null);
    }
  }

  return (
    <aside className="hidden w-80 shrink-0 lg:block">
      <div className="sticky top-20 flex flex-col gap-4">
        {/* People you may know */}
        <section className="rounded-xl bg-white border border-line/50 p-4">
          <h3 className="mb-3 flex items-center gap-2 text-title-md text-ink">
            <IconUsers size={18} className="text-brand" />
            {t("rail.people")}
          </h3>
          <ul className="flex flex-col gap-2.5">
            {people.length === 0 ? (
              <li className="py-2 text-xs text-muted">{t("search.noResults")}</li>
            ) : (
              people.map((s) => {
                const isF = !!followed[s.id];
                const handle = (s.email ?? "user").split("@")[0];
                return (
                  <li key={s.id} className="flex items-center gap-3 rounded-lg p-1.5 -mx-1.5 transition-colors duration-150 hover:bg-navy-50">
                    <MiniAvatar name={s.full_name} handle={handle} />
                    <NavLink to={`/personnel/${s.id}`} className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium text-ink">{s.full_name}</p>
                      <p className="truncate text-xs text-muted">@{handle}</p>
                    </NavLink>
                    <button
                      className={`btn text-xs px-3 py-1.5 ${isF ? "btn-soft" : "btn-primary"}`}
                      onClick={() => follow(s.id)}
                      disabled={pending === s.id}
                    >
                      {isF ? <><IconCheck size={14} /> {t("action.following")}</> : t("action.follow")}
                    </button>
                  </li>
                );
              })
            )}
          </ul>
        </section>

        {/* Recognized institutions */}
        <section className="rounded-xl overflow-hidden bg-white border border-line/50">
          <div className="flex items-center gap-2 bg-gradient-to-r from-brand to-accent px-4 py-3 text-white">
            <IconBadge size={18} />
            <p className="text-sm font-semibold">Esteemed Recognition</p>
          </div>
          <ul className="flex flex-col gap-1 p-2">
            {recognizedInstitutions.map((it) => (
              <li key={it.id}>
                <Link
                  to={`/institution/${it.id}`}
                  className="flex items-center gap-3 rounded-lg p-2 transition-colors duration-150 hover:bg-navy-50"
                >
                  <span className="grid h-10 w-10 place-items-center rounded-full bg-gradient-to-br from-brand to-accent text-sm font-bold text-white">
                    {it.name[0]}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium text-ink">{it.name}</p>
                    <p className="truncate text-xs text-muted">{it.note}</p>
                  </div>
                  <span className="chip-recognition shrink-0 text-[10px]">{it.badge}</span>
                </Link>
              </li>
            ))}
          </ul>
        </section>

        {/* Trending */}
        <section className="rounded-xl bg-white border border-line/50 p-4">
          <h3 className="mb-3 flex items-center gap-2 text-title-md text-ink">
            <IconTrending size={18} className="text-accent" />
            {t("rail.trending")}
          </h3>
          <ul className="flex flex-col gap-2">
            {trends.length === 0 ? (
              <li className="py-2 text-xs text-muted">{t("search.noResults")}</li>
            ) : (
              trends.map((tr) => (
                <li key={tr.tag} className="cursor-pointer rounded-lg p-2 -mx-2 transition-colors duration-150 hover:bg-navy-50">
                  <p className="text-sm font-medium text-brand">{tr.tag}</p>
                  <p className="text-xs text-muted">{tr.count} posts</p>
                </li>
              ))
            )}
          </ul>
        </section>

        {/* Footer */}
        <section className="rounded-xl bg-white border border-line/50 p-4">
          <div className="flex items-center gap-2 mb-3">
            <IconSparkles size={16} className="text-brand/60" />
            <p className="text-xs font-medium text-muted/70">MASAREEN, verified impact, made social</p>
          </div>
          <div className="flex flex-wrap gap-x-3 gap-y-1 text-xs text-muted/50">
            <span className="hover:text-muted cursor-pointer transition-colors">About</span>
            <span className="hover:text-muted cursor-pointer transition-colors">Privacy</span>
            <span className="hover:text-muted cursor-pointer transition-colors">Terms</span>
            <span className="hover:text-muted cursor-pointer transition-colors">POAI Verification</span>
            <span>© 2026 MASAREEN</span>
          </div>
        </section>
      </div>
    </aside>
  );
}
