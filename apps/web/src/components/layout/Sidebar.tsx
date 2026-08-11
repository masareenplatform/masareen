import { NavLink } from "react-router-dom";
import { useI18n } from "../../i18n";
import { useAuth } from "../../store/authStore";
import { BrandMark, BrandWordmark, PRIMARY_NAV, TOOLS_NAV, NavItem, AppAvatar } from "../common/Branding";
import { IconPlus, IconUser } from "../icons/Icons";

function ProfileCard() {
  const { t } = useI18n();
  const { user } = useAuth();
  const name = user?.full_name ?? "Guest";
  const handle = (user?.email ?? "guest").split("@")[0];
  const role = user?.role ?? "Individual";
  const pms = user?.pms_score ?? 0;
  const strength = Math.max(4, Math.min(100, Math.round((pms / 1000) * 100)));

  return (
    <NavLink to="/profile" className="group block rounded-xl border border-line/50 bg-white p-4 transition-all duration-200 hover:shadow-md hover:border-brand/20 hover:-translate-y-0.5">
      <div className="flex items-center gap-3">
        <div className="relative">
          <AppAvatar name={name} handle={handle} size={44} />
          <span className="absolute -bottom-0.5 -right-0.5 h-3.5 w-3.5 rounded-full border-2 border-white bg-accent" />
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold text-ink">{name}</p>
          <p className="truncate text-xs text-muted">@{handle}</p>
        </div>
      </div>
      <div className="mt-3">
        <div className="mb-1.5 flex items-center justify-between text-xs">
          <span className="text-muted font-medium">{t("profile.strength")}</span>
          <span className="font-semibold text-brand">{t("profile.score")} {pms}</span>
        </div>
        <div className="h-1.5 w-full overflow-hidden rounded-full bg-navy-100">
          <div
            className="h-full rounded-full bg-gradient-to-r from-brand to-accent transition-all duration-700 ease-out"
            style={{ width: `${strength}%` }}
          />
        </div>
        <p className="mt-2 text-[11px] font-medium uppercase tracking-wider text-muted/70">{role}</p>
      </div>
    </NavLink>
  );
}

function NavRow({ item, onNavigate }: { item: NavItem; onNavigate?: () => void }) {
  return (
    <NavLink
      to={item.to}
      onClick={onNavigate}
      className={({ isActive }) =>
        `flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-all duration-200 group ${
          isActive
            ? "bg-brand-50 text-brand shadow-sm"
            : "text-muted hover:bg-navy-100 hover:text-ink hover:translate-x-0.5"
        }`
      }
    >
      {({ isActive }) => (
        <>
          <span className={`transition-colors duration-200 ${isActive ? "text-brand" : "text-muted group-hover:text-ink"}`}>
            <item.icon size={20} />
          </span>
          <span>{item.label}</span>
          {isActive && <span className="ml-auto h-1.5 w-1.5 rounded-full bg-brand" />}
        </>
      )}
    </NavLink>
  );
}

export function SidebarNav({ onNavigate, onCompose }: { onNavigate?: () => void; onCompose?: () => void }) {
  return (
    <div className="flex flex-col gap-0.5 px-2">
      <button
        className="btn-primary mb-4 w-full group"
        onClick={onCompose}
      >
        <IconPlus size={18} className="transition-transform duration-200 group-hover:rotate-90" />
        Create post
      </button>

      <p className="px-3 pb-1.5 pt-2 text-[11px] font-semibold uppercase tracking-wider text-muted/60">Menu</p>
      {PRIMARY_NAV.map((it) => <NavRow key={it.to} item={it} onNavigate={onNavigate} />)}

      <p className="px-3 pb-1.5 pt-4 text-[11px] font-semibold uppercase tracking-wider text-muted/60">Tools</p>
      {TOOLS_NAV.map((it) => <NavRow key={it.to} item={it} onNavigate={onNavigate} />)}
    </div>
  );
}

export default function Sidebar({ onCompose }: { onCompose: () => void }) {
  return (
    <aside className="hidden md:flex w-64 shrink-0 flex-col">
      <div className="sticky top-16 flex flex-col gap-3">
        <ProfileCard />
        <SidebarNav onCompose={onCompose} />
      </div>
    </aside>
  );
}
