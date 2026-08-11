import { useState, useEffect } from "react";
import { NavLink, useLocation, useNavigate } from "react-router-dom";
import {
  IconHome, IconCompass, IconTask, IconBell, IconUser,
  IconReports, IconProgram, IconEvidence, IconBadge, IconHandshake,
  IconWallet, IconAds, IconBilling, IconMoney, IconChat, IconMenu,
  IconClose, IconPlus, IconLogout,
} from "../icons/Icons";
import Composer from "../social/Composer";
import { useAuth } from "../../store/authStore";

/* ── Brand identity (mirrors Flutter's gradient wordmark + logo mark) ── */

export function BrandMark({ size = 36, className = "" }: { size?: number; className?: string }) {
  return (
    <span
      className={`brand-mark rounded-xl ${className}`}
      style={{ width: size, height: size, fontSize: size * 0.5 }}
      aria-hidden
    >
      M
    </span>
  );
}

export function BrandWordmark({ className = "" }: { className?: string }) {
  return (
    <span className={`brand-wordmark ${className}`} style={{ fontSize: "1.35rem" }}>
      MASAREN
    </span>
  );
}

export function AppAvatar({
  name, handle, size = 40, gradient = true,
}: { name: string; handle?: string; size?: number; gradient?: boolean }) {
  const seed = handle || name;
  const c1 = "#0250A3";
  const c2 = "#0077C8";
  return (
    <span
      className={`${gradient ? "avatar-gradient" : "app-avatar"} grid shrink-0 place-items-center rounded-full font-semibold text-white`}
      style={{
        width: size, height: size, fontSize: size * 0.4,
        ...(gradient ? { ["--c1" as any]: c1, ["--c2" as any]: c2 } : {}),
      }}
    >
      {(name?.[0] ?? "?").toUpperCase()}
    </span>
  );
}

/* ── Shared navigation model (one platform: web mirrors the Flutter shell) ── */

export type NavItem = {
  to: string;
  label: string;
  icon: (p: { className?: string; size?: number }) => JSX.Element;
  primary?: boolean;
};

export const PRIMARY_NAV: NavItem[] = [
  { to: "/feed", label: "Home", icon: IconHome, primary: true },
  { to: "/opportunities", label: "Explore", icon: IconCompass, primary: true },
  { to: "/tasks", label: "Tasks", icon: IconTask, primary: true },
  { to: "/notifications", label: "Alerts", icon: IconBell, primary: true },
  { to: "/profile", label: "Profile", icon: IconUser, primary: true },
];

export const TOOLS_NAV: NavItem[] = [
  { to: "/dashboard", label: "Dashboard", icon: IconReports },
  { to: "/programs", label: "Programs", icon: IconProgram },
  { to: "/evidence", label: "Evidence", icon: IconEvidence },
  { to: "/passport", label: "Impact Passport", icon: IconBadge },
  { to: "/collaborate", label: "Collaborate", icon: IconHandshake },
  { to: "/wallet", label: "MASAREN Coin", icon: IconWallet },
  { to: "/ads", label: "Ads Manager", icon: IconAds },
  { to: "/payments", label: "Payments", icon: IconBilling },
  { to: "/revenue", label: "Platform Revenue", icon: IconMoney },
  { to: "/chat", label: "Assistant", icon: IconChat },
  { to: "/portfolio", label: "Portfolio", icon: IconReports },
  { to: "/reports", label: "Reports", icon: IconReports },
  { to: "/billing", label: "Billing", icon: IconBilling },
];

/* ── Mobile bottom navigation (mirrors Flutter NavigationBar) ── */

export function BottomNav({ onCompose }: { onCompose: () => void }) {
  const { pathname } = useLocation();
  const isActive = (to: string) => pathname === to || pathname.startsWith(to + "/");
  return (
    <nav className="bottom-nav md:hidden" aria-label="Primary">
      {PRIMARY_NAV.slice(0, 2).map((it) => (
        <NavLink key={it.to} to={it.to} className={`bottom-nav-item ${isActive(it.to) ? "active" : ""}`}>
          <it.icon size={22} />
          {it.label}
        </NavLink>
      ))}
      <div className="bottom-nav-fab">
        <button className="compose-fab h-12 w-12 -translate-y-3" onClick={onCompose} aria-label="Create post">
          <IconPlus size={26} />
        </button>
      </div>
      {PRIMARY_NAV.slice(2).map((it) => (
        <NavLink key={it.to} to={it.to} className={`bottom-nav-item ${isActive(it.to) ? "active" : ""}`}>
          <it.icon size={22} />
          {it.label}
        </NavLink>
      ))}
    </nav>
  );
}

/* ── Mobile "More" sheet (mirrors Flutter AppMenuSheet) ── */

export function MenuSheet({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { pathname } = useLocation();
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  if (!open) return null;
  const isActive = (to: string) => pathname === to || pathname.startsWith(to + "/");
  const name = user?.full_name ?? "Guest";
  const handle = (user?.email ?? "guest").split("@")[0];
  return (
    <div className="fixed inset-0 z-50 md:hidden" role="dialog" aria-modal="true">
      <div className="absolute inset-0 bg-ink/40 backdrop-blur-sm animate-fade-up" onClick={onClose} />
      <div className="absolute inset-x-0 bottom-0 max-h-[82vh] overflow-y-auto rounded-t-3xl bg-white p-3 pb-6 shadow-float animate-nav-in">
        <div className="mx-auto mb-3 h-1.5 w-10 rounded-full bg-line" />
        <p className="mb-2 px-2 font-display text-sm font-bold text-ink">MASAREN Tools</p>
        {TOOLS_NAV.map((it) => (
          <NavLink
            key={it.to}
            to={it.to}
            onClick={onClose}
            className={`flex items-center gap-3 rounded-xl px-3 py-3 text-sm font-medium transition ${
              isActive(it.to) ? "bg-brand-50 text-brand-700" : "text-ink hover:bg-canvas"
            }`}
          >
            <span className="text-brand"><it.icon size={20} /></span>
            {it.label}
          </NavLink>
        ))}
        <div className="my-2 border-t border-line" />
        <NavLink to="/profile" onClick={onClose} className="flex items-center gap-3 rounded-xl px-3 py-3 text-sm font-medium text-ink hover:bg-canvas">
          <AppAvatar name={name} handle={handle} size={24} />
          <span className="truncate">{name}</span>
        </NavLink>
        <button
          className="flex w-full items-center gap-3 rounded-xl px-3 py-3 text-sm font-medium text-like hover:bg-canvas"
          onClick={() => { onClose(); logout(); navigate("/login"); }}
        >
          <IconLogout size={20} /> Sign Out
        </button>
      </div>
    </div>
  );
}

/* ── Compose modal (mirrors Flutter ComposeSheet) ── */

export function ComposeModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const [key, setKey] = useState(0);
  useEffect(() => { if (open) setKey((k) => k + 1); }, [open]);
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-[60] grid place-items-end sm:place-items-center" role="dialog" aria-modal="true">
      <div className="absolute inset-0 bg-ink/40 backdrop-blur-sm animate-fade-up" onClick={onClose} />
      <div className="relative w-full max-w-xl animate-nav-in rounded-t-3xl bg-white p-4 shadow-float sm:rounded-3xl">
        <div className="mb-3 flex items-center justify-between">
          <p className="font-display text-base font-bold text-ink">Create impact post</p>
          <button className="icon-btn" onClick={onClose} aria-label="Close"><IconClose size={20} /></button>
        </div>
        <Composer key={key} onPosted={onClose} />
      </div>
    </div>
  );
}
