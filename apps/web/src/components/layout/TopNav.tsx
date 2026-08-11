import { useEffect, useRef, useState } from "react";
import { NavLink, useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "../../store/authStore";
import { useI18n } from "../../i18n";
import {
  IconBell, IconMessage, IconMenu, IconGlobe, IconLogout, IconUser, IconSearch,
} from "../icons/Icons";
import { BrandMark, AppAvatar } from "../common/Branding";
import { userService, programService, opportunityService, notificationService } from "../../services/api";
import MessengerPopup from "../social/Messenger";

type Hit =
  | { kind: "people"; id: string; title: string; sub: string }
  | { kind: "programs" | "opportunities"; id: string; title: string; sub: string };

function MessengerPortal({ onClose, meName, meHandle }: { onClose: () => void; meName: string; meHandle: string }) {
  return <MessengerPopup onClose={onClose} meName={meName} meHandle={meHandle} />;
}

export default function TopNav({ onMenu }: { onMenu: () => void }) {
  const { user, logout } = useAuth();
  const { t, toggle } = useI18n();
  const navigate = useNavigate();
  const location = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);
  const [messengerOpen, setMessengerOpen] = useState(false);

  // Search
  const [query, setQuery] = useState("");
  const [hits, setHits] = useState<Hit[]>([]);
  const [searchOpen, setSearchOpen] = useState(false);
  const searchBoxRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    let alive = true;
    Promise.all([
      programService.list().catch(() => []),
      opportunityService.list().catch(() => []),
      userService.suggestedUsers(50).catch(() => []),
    ]).then(([programs, opps, people]) => {
      if (!alive) return;
      const p: Hit[] = (programs as any[]).map((x) => ({ kind: "programs", id: x.id, title: x.title, sub: "Program" }));
      const o: Hit[] = (opps as any[]).map((x) => ({ kind: "opportunities", id: x.id, title: x.title, sub: "Opportunity" }));
      const u: Hit[] = (people as any[]).map((x) => ({ kind: "people", id: x.id, title: x.full_name, sub: `@${(x.email ?? x.full_name ?? "").split("@")[0]}` }));
      cacheRef.current = [...p, ...o, ...u];
    });
    return () => { alive = false; };
  }, []);

  const cacheRef = useRef<Hit[]>([]);

  useEffect(() => {
    const q = query.trim().toLowerCase();
    if (!q) { setHits([]); return; }
    const id = setTimeout(() => {
      const next = cacheRef.current
        .filter((h) => h.title.toLowerCase().includes(q) || h.sub.toLowerCase().includes(q))
        .slice(0, 8);
      setHits(next);
    }, 200);
    return () => clearTimeout(id);
  }, [query]);

  useEffect(() => {
    const onDoc = (e: MouseEvent) => {
      if (searchBoxRef.current && !searchBoxRef.current.contains(e.target as Node)) setSearchOpen(false);
    };
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, []);

  function goTo(h: Hit) {
    setSearchOpen(false);
    setQuery("");
    if (h.kind === "people") navigate(`/personnel/${h.id}`);
    else if (h.kind === "programs") navigate("/programs");
    else navigate("/opportunities");
  }

  // Notifications
  const [unread, setUnread] = useState(0);
  useEffect(() => {
    if (!user?.id) { setUnread(0); return; }
    let alive = true;
    const load = () =>
      notificationService.list(user.id).then((items: any[]) => {
        if (!alive) return;
        const list = Array.isArray(items) ? items : [];
        setUnread(list.filter((n: any) => n?.read !== true).length);
      }).catch(() => {});
    load();
    const timer = setInterval(load, 60_000);
    return () => { alive = false; clearInterval(timer); };
  }, [user?.id]);

  const name = user?.full_name ?? "Guest";
  const handle = (user?.email ?? "guest").split("@")[0];

  return (
    <header className="app-topbar sticky top-0 z-40 border-b border-line/50">
      <div className="mx-auto flex h-16 max-w-[1280px] items-center gap-4 px-4">
        {/* Logo */}
        <NavLink to="/feed" className="shrink-0 transition-transform duration-200 hover:scale-105" aria-label="MASAREEN home">
          <BrandMark size={36} />
        </NavLink>

        {/* Search */}
        <div ref={searchBoxRef} className="relative hidden flex-1 md:block max-w-xl">
          <div className="relative">
            <IconSearch size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-muted/50" />
            <input
              className="nav-search w-full pl-10 pr-4"
              placeholder={t("feed.search")}
              value={query}
              onChange={(e) => { setQuery(e.target.value); setSearchOpen(true); }}
              onFocus={() => setSearchOpen(true)}
              aria-label={t("feed.search")}
            />
          </div>
          {searchOpen && query.trim() && (
            <div className="absolute z-50 mt-2 w-full max-h-[60vh] overflow-y-auto rounded-xl bg-white border border-line shadow-xl animate-scale-in">
              {hits.length === 0 ? (
                <p className="px-4 py-6 text-center text-sm text-muted">{t("search.noResults")}</p>
              ) : (
                <ul className="flex flex-col gap-0.5 p-2">
                  {hits.map((h) => (
                    <li key={`${h.kind}-${h.id}`}>
                      <button
                        className="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-start hover:bg-navy-50 transition-colors duration-150"
                        onClick={() => goTo(h)}
                      >
                        <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-brand-50 text-xs font-semibold text-brand">
                          {(h.title?.[0] ?? "?").toUpperCase()}
                        </span>
                        <span className="min-w-0 flex-1">
                          <span className="block truncate text-sm font-medium text-ink">{h.title}</span>
                          <span className="block truncate text-xs text-muted">{h.sub}</span>
                        </span>
                        <span className="chip text-[10px] uppercase">{t(`search.${h.kind}`)}</span>
                      </button>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          )}
        </div>

        {/* Actions */}
        <div className="ms-auto flex items-center gap-1">
          <button className="icon-btn" onClick={toggle} title="Language" aria-label="Toggle language">
            <IconGlobe size={20} />
          </button>
          <button className="icon-btn relative" onClick={() => setMessengerOpen(true)} title="Messages" aria-label="Messages">
            <IconMessage size={20} />
            <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-accent animate-pulse-soft" />
          </button>
          <button
            className="icon-btn relative"
            onClick={() => navigate("/notifications")}
            title={t("nav.notifications")}
            aria-label={t("nav.notifications")}
          >
            <IconBell size={20} />
            {unread > 0 && (
              <span className="notification-badge">{unread > 9 ? "9+" : unread}</span>
            )}
          </button>
          <button className="icon-btn md:hidden" onClick={onMenu} title="Menu" aria-label="Open menu">
            <IconMenu size={20} />
          </button>

          {/* User menu */}
          <div className="relative hidden md:block">
            <button
              className="flex items-center gap-2 rounded-full p-1 transition-all duration-200 hover:bg-navy-100"
              onClick={() => setMenuOpen((s) => !s)}
              aria-label="Account"
            >
              <AppAvatar name={name} handle={handle} size={32} />
            </button>
            {menuOpen && (
              <>
                <div className="fixed inset-0 z-40" onClick={() => setMenuOpen(false)} />
                <div className="absolute end-0 z-50 mt-2 w-60 animate-scale-in rounded-xl bg-white border border-line shadow-xl p-2">
                  <div className="flex items-center gap-3 border-b border-line px-3 pb-3 pt-2">
                    <AppAvatar name={name} handle={handle} size={36} />
                    <div className="min-w-0">
                      <p className="truncate text-sm font-semibold text-ink">{name}</p>
                      <p className="truncate text-xs text-muted">@{handle}</p>
                    </div>
                  </div>
                  <NavLink
                    to="/profile"
                    className="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-ink hover:bg-navy-50 transition-colors duration-150 mt-1"
                    onClick={() => setMenuOpen(false)}
                  >
                    <IconUser size={18} className="text-muted" />
                    {t("profile.card")}
                  </NavLink>
                  <button
                    className="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-like hover:bg-red-50 transition-colors duration-150"
                    onClick={() => { setMenuOpen(false); logout(); navigate("/login"); }}
                  >
                    <IconLogout size={18} />
                    {t("action.signout")}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      {messengerOpen && (
        <MessengerPortal onClose={() => setMessengerOpen(false)} meName={name} meHandle={handle} />
      )}
    </header>
  );
}
