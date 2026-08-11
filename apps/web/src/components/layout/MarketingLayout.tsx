import { Outlet, Link, useLocation } from "react-router-dom";
import { useEffect, useRef, useState } from "react";
import { BrandWordmark } from "../common/Branding";
import { GoogleAuth } from "../common/GoogleAuth";

/**
 * Public marketing shell (no auth required). Wraps the landing page and the
 * standalone content pages (pricing, about, solutions, …) with a shared nav +
 * footer. Page changes fade/slide in without a full reload (SPA + keyed
 * transition), so moving between marketing pages feels like one continuous site.
 */
export default function MarketingLayout() {
  const location = useLocation();
  const [display, setDisplay] = useState(location.pathname);
  const [phase, setPhase] = useState<"in" | "out">("in");
  const timer = useRef<number>();

  useEffect(() => {
    if (location.pathname === display) return;
    setPhase("out");
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => {
      setDisplay(location.pathname);
      setPhase("in");
      window.scrollTo({ top: 0, behavior: "smooth" });
    }, 220);
    return () => window.clearTimeout(timer.current);
  }, [location.pathname, display]);

  return (
    <div className="min-h-screen bg-white text-ink">
      <header className="sticky top-0 z-50 border-b border-line/70 bg-white/85 backdrop-blur">
        <div className="mx-auto flex h-24 max-w-6xl items-center gap-3 px-4">
          <span className="logo-box !p-2">
            <Link to="/"><BrandWordmark height={88} /></Link>
          </span>
          <nav className="ms-4 hidden items-center gap-1 text-sm font-medium text-muted lg:flex">
            <div className="nav-item">
              <button className="rounded-lg px-3 py-1.5 hover:bg-canvas hover:text-ink">Platform ▾</button>
              <div className="mega grid grid-cols-2 gap-1">
                {[["Feed & Stories","/feed"],["Programs","/programs"],["Tasks","/tasks"],["Evidence","/evidence"],["Impact Passport","/passport"],["Opportunities","/opportunities"]].map(([t,l]) => (
                  <Link key={t} to={l} className="rounded-lg px-3 py-2 text-sm text-ink hover:bg-canvas">{t}</Link>
                ))}
              </div>
            </div>
            <div className="nav-item">
              <button className="rounded-lg px-3 py-1.5 hover:bg-canvas hover:text-ink">Solutions ▾</button>
              <div className="mega grid grid-cols-2 gap-1">
                {[["NGOs","/solutions/ngo"],["Corporates","/solutions/corporate"],["Government","/solutions/government"],["Universities","/solutions/university"],["Investors","/solutions/investor"],["Communities","/solutions/community"]].map(([t,l]) => (
                  <Link key={t} to={l} className="rounded-lg px-3 py-2 text-sm text-ink hover:bg-canvas">{t}</Link>
                ))}
              </div>
            </div>
            <div className="nav-item">
              <button className="rounded-lg px-3 py-1.5 hover:bg-canvas hover:text-ink">Resources ▾</button>
              <div className="mega grid grid-cols-1 gap-1">
                {[["How verification works","/how-it-works"],["Evidence & proof","/verification"],["SDGs & Egypt 2030","/sdg"],["Pricing","/pricing"],["About","/about"],["Blog & guides","/resources"]].map(([t,l]) => (
                  <Link key={t} to={l} className="rounded-lg px-3 py-2 text-sm text-ink hover:bg-canvas">{t}</Link>
                ))}
              </div>
            </div>
            <Link to="/pricing" className="rounded-lg px-3 py-1.5 hover:bg-canvas hover:text-ink">Pricing</Link>
            <Link to="/about" className="rounded-lg px-3 py-1.5 hover:bg-canvas hover:text-ink">About</Link>
          </nav>
          <div className="ms-auto flex items-center gap-2">
            <Link to="/login" className="btn-ghost px-3 py-1.5 text-sm">Sign in</Link>
            <Link to="/register" className="btn-gold px-3 py-1.5 text-sm">Get started</Link>
          </div>
        </div>
      </header>

      <div
        className="page-fade"
        style={{ opacity: phase === "in" ? 1 : 0, transform: phase === "in" ? "none" : "translateY(14px)" }}
      >
        <Outlet context={{ pathname: display }} />
      </div>

      <footer className="mt-16 border-t border-line bg-canvas py-10">
        <div className="mx-auto grid max-w-6xl gap-8 px-4 sm:grid-cols-2 lg:grid-cols-4">
          <div>
            <BrandWordmark height={56} />
            <p className="mt-3 max-w-xs text-sm text-muted">Verified impact infrastructure for everyone building a better world.</p>
          </div>
          <div className="text-sm">
            <h4 className="font-semibold text-ink">Product</h4>
            <ul className="mt-2 space-y-1 text-muted">
              <li><Link to="/how-it-works" className="hover:text-brand">How it works</Link></li>
              <li><Link to="/verification" className="hover:text-brand">Verification</Link></li>
              <li><Link to="/pricing" className="hover:text-brand">Pricing</Link></li>
              <li><Link to="/feed" className="hover:text-brand">Open app</Link></li>
            </ul>
          </div>
          <div className="text-sm">
            <h4 className="font-semibold text-ink">Solutions</h4>
            <ul className="mt-2 space-y-1 text-muted">
              <li><Link to="/solutions/ngo" className="hover:text-brand">NGOs</Link></li>
              <li><Link to="/solutions/corporate" className="hover:text-brand">Corporates</Link></li>
              <li><Link to="/solutions/government" className="hover:text-brand">Government</Link></li>
              <li><Link to="/solutions/university" className="hover:text-brand">Universities</Link></li>
            </ul>
          </div>
          <div className="text-sm">
            <h4 className="font-semibold text-ink">Company</h4>
            <ul className="mt-2 space-y-1 text-muted">
              <li><Link to="/about" className="hover:text-brand">About</Link></li>
              <li><Link to="/resources" className="hover:text-brand">Resources</Link></li>
              <li><Link to="/login" className="hover:text-brand">Sign in</Link></li>
              <li><Link to="/register" className="hover:text-brand">Get started</Link></li>
            </ul>
          </div>
        </div>
        <p className="mx-auto mt-8 max-w-6xl px-4 text-xs text-muted">© 2026 MASAREEN · Aligned with UN SDGs & Egypt Vision 2030 · POAI Verification</p>
      </footer>
    </div>
  );
}
