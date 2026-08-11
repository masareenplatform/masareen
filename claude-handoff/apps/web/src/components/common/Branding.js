import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useState, useEffect } from "react";
import { NavLink, useLocation, useNavigate } from "react-router-dom";
import { IconHome, IconCompass, IconTask, IconBell, IconUser, IconReports, IconProgram, IconEvidence, IconBadge, IconHandshake, IconWallet, IconAds, IconBilling, IconMoney, IconChat, IconClose, IconPlus, IconLogout, } from "../icons/Icons";
import Composer from "../social/Composer";
import { useAuth } from "../../store/authStore";
/* ── Brand identity (mirrors Flutter's gradient wordmark + logo mark) ── */
export function BrandMark({ size = 36, className = "" }) {
    return (_jsx("span", { className: `brand-mark rounded-xl ${className}`, style: { width: size, height: size, fontSize: size * 0.5 }, "aria-hidden": true, children: "M" }));
}
export function BrandWordmark({ className = "" }) {
    return (_jsx("span", { className: `brand-wordmark ${className}`, style: { fontSize: "1.35rem" }, children: "MASAREN" }));
}
export function AppAvatar({ name, handle, size = 40, gradient = true, }) {
    const seed = handle || name;
    const c1 = "#0250A3";
    const c2 = "#0077C8";
    return (_jsx("span", { className: `${gradient ? "avatar-gradient" : "app-avatar"} grid shrink-0 place-items-center rounded-full font-semibold text-white`, style: {
            width: size, height: size, fontSize: size * 0.4,
            ...(gradient ? { ["--c1"]: c1, ["--c2"]: c2 } : {}),
        }, children: (name?.[0] ?? "?").toUpperCase() }));
}
export const PRIMARY_NAV = [
    { to: "/feed", label: "Home", icon: IconHome, primary: true },
    { to: "/opportunities", label: "Explore", icon: IconCompass, primary: true },
    { to: "/tasks", label: "Tasks", icon: IconTask, primary: true },
    { to: "/notifications", label: "Alerts", icon: IconBell, primary: true },
    { to: "/profile", label: "Profile", icon: IconUser, primary: true },
];
export const TOOLS_NAV = [
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
export function BottomNav({ onCompose }) {
    const { pathname } = useLocation();
    const isActive = (to) => pathname === to || pathname.startsWith(to + "/");
    return (_jsxs("nav", { className: "bottom-nav md:hidden", "aria-label": "Primary", children: [PRIMARY_NAV.slice(0, 2).map((it) => (_jsxs(NavLink, { to: it.to, className: `bottom-nav-item ${isActive(it.to) ? "active" : ""}`, children: [_jsx(it.icon, { size: 22 }), it.label] }, it.to))), _jsx("div", { className: "bottom-nav-fab", children: _jsx("button", { className: "compose-fab h-12 w-12 -translate-y-3", onClick: onCompose, "aria-label": "Create post", children: _jsx(IconPlus, { size: 26 }) }) }), PRIMARY_NAV.slice(2).map((it) => (_jsxs(NavLink, { to: it.to, className: `bottom-nav-item ${isActive(it.to) ? "active" : ""}`, children: [_jsx(it.icon, { size: 22 }), it.label] }, it.to)))] }));
}
/* ── Mobile "More" sheet (mirrors Flutter AppMenuSheet) ── */
export function MenuSheet({ open, onClose }) {
    const { pathname } = useLocation();
    const { user, logout } = useAuth();
    const navigate = useNavigate();
    if (!open)
        return null;
    const isActive = (to) => pathname === to || pathname.startsWith(to + "/");
    const name = user?.full_name ?? "Guest";
    const handle = (user?.email ?? "guest").split("@")[0];
    return (_jsxs("div", { className: "fixed inset-0 z-50 md:hidden", role: "dialog", "aria-modal": "true", children: [_jsx("div", { className: "absolute inset-0 bg-ink/40 backdrop-blur-sm animate-fade-up", onClick: onClose }), _jsxs("div", { className: "absolute inset-x-0 bottom-0 max-h-[82vh] overflow-y-auto rounded-t-3xl bg-white p-3 pb-6 shadow-float animate-nav-in", children: [_jsx("div", { className: "mx-auto mb-3 h-1.5 w-10 rounded-full bg-line" }), _jsx("p", { className: "mb-2 px-2 font-display text-sm font-bold text-ink", children: "MASAREN Tools" }), TOOLS_NAV.map((it) => (_jsxs(NavLink, { to: it.to, onClick: onClose, className: `flex items-center gap-3 rounded-xl px-3 py-3 text-sm font-medium transition ${isActive(it.to) ? "bg-brand-50 text-brand-700" : "text-ink hover:bg-canvas"}`, children: [_jsx("span", { className: "text-brand", children: _jsx(it.icon, { size: 20 }) }), it.label] }, it.to))), _jsx("div", { className: "my-2 border-t border-line" }), _jsxs(NavLink, { to: "/profile", onClick: onClose, className: "flex items-center gap-3 rounded-xl px-3 py-3 text-sm font-medium text-ink hover:bg-canvas", children: [_jsx(AppAvatar, { name: name, handle: handle, size: 24 }), _jsx("span", { className: "truncate", children: name })] }), _jsxs("button", { className: "flex w-full items-center gap-3 rounded-xl px-3 py-3 text-sm font-medium text-like hover:bg-canvas", onClick: () => { onClose(); logout(); navigate("/login"); }, children: [_jsx(IconLogout, { size: 20 }), " Sign Out"] })] })] }));
}
/* ── Compose modal (mirrors Flutter ComposeSheet) ── */
export function ComposeModal({ open, onClose }) {
    const [key, setKey] = useState(0);
    useEffect(() => { if (open)
        setKey((k) => k + 1); }, [open]);
    if (!open)
        return null;
    return (_jsxs("div", { className: "fixed inset-0 z-[60] grid place-items-end sm:place-items-center", role: "dialog", "aria-modal": "true", children: [_jsx("div", { className: "absolute inset-0 bg-ink/40 backdrop-blur-sm animate-fade-up", onClick: onClose }), _jsxs("div", { className: "relative w-full max-w-xl animate-nav-in rounded-t-3xl bg-white p-4 shadow-float sm:rounded-3xl", children: [_jsxs("div", { className: "mb-3 flex items-center justify-between", children: [_jsx("p", { className: "font-display text-base font-bold text-ink", children: "Create impact post" }), _jsx("button", { className: "icon-btn", onClick: onClose, "aria-label": "Close", children: _jsx(IconClose, { size: 20 }) })] }), _jsx(Composer, { onPosted: onClose }, key)] })] }));
}
