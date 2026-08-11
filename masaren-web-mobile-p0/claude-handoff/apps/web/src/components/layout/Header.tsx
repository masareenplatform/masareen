import { useAuth } from "../../store/authStore";
import { useI18n } from "../../i18n";

export default function Header() {
  const { user, logout } = useAuth();
  const { t, toggle, locale } = useI18n();
  return (
    <header className="sticky top-0 z-30 flex items-center justify-between gap-3 px-4 md:px-6 h-16 glass-strong border-b border-white/10">
      <div className="flex items-center gap-2">
        <div className="h-9 w-9 rounded-xl bg-gradient-to-br from-gold-light to-gold flex items-center justify-center text-navy-900 font-extrabold shadow-glow-gold">
          M
        </div>
        <div className="leading-tight">
          <p className="font-display font-bold text-white text-lg">{t("app.name")}</p>
          <p className="text-[10px] uppercase tracking-[0.2em] text-white/40">Impact Infrastructure</p>
        </div>
      </div>

      <div className="flex items-center gap-2 md:gap-4">
        <button onClick={toggle} className="btn-ghost !px-3 !py-1.5 text-xs" aria-label="Toggle language">
          {locale === "ar" ? "EN" : "ع"}
        </button>
        <span className="hidden sm:block text-sm text-white/70">{user?.full_name}</span>
        <div className="h-9 w-9 rounded-full bg-white/10 border border-white/15 flex items-center justify-center text-sm font-semibold text-white">
          {(user?.full_name?.[0] ?? "U").toUpperCase()}
        </div>
        <button onClick={logout} className="btn-ghost !px-3 !py-1.5 text-xs">
          {t("action.signout")}
        </button>
      </div>
    </header>
  );
}
