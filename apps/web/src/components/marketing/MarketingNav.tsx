import { Link } from "react-router-dom";
import { useAuth } from "../../store/authStore";

export default function MarketingNav() {
  const { isAuthenticated } = useAuth();
  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-white/10 backdrop-blur-md">
      <div className="mx-auto flex h-20 max-w-6xl items-center gap-3 px-4">
        <Link to="/" className="flex items-center gap-2">
          <span className="grid place-items-center rounded-2xl px-3 py-1.5 shadow-card">
            <img src="/logo-512.png" alt="MASAREEN" style={{ height: 54, width: "auto", objectFit: "contain", filter: "brightness(0) invert(1)" }} />
          </span>
        </Link>
        <nav className="ms-6 hidden items-center gap-1 text-sm font-medium text-white/75 lg:flex">
          <div className="nav-item">
            <button className="rounded-lg px-3 py-1.5 hover:bg-white/10 hover:text-white">Platform ▾</button>
            <div className="mega grid grid-cols-2 gap-1">
              {[["Feed & Stories","/feed"],["Programs","/programs"],["Tasks","/tasks"],["Evidence","/evidence"],["Impact Passport","/passport"],["Opportunities","/opportunities"]].map(([t,l]) => (
                <Link key={t} to={l} className="rounded-lg px-3 py-2 text-sm text-ink hover:bg-canvas">{t}</Link>
              ))}
            </div>
          </div>
          <div className="nav-item">
            <button className="rounded-lg px-3 py-1.5 hover:bg-white/10 hover:text-white">Solutions ▾</button>
            <div className="mega grid grid-cols-2 gap-1">
              {[["NGOs","/solutions/ngo"],["Corporates","/solutions/corporate"],["Government","/solutions/government"],["Universities","/solutions/university"],["Investors","/solutions/investor"],["Communities","/solutions/community"]].map(([t,l]) => (
                <Link key={t} to={l} className="rounded-lg px-3 py-2 text-sm text-ink hover:bg-canvas">{t}</Link>
              ))}
            </div>
          </div>
          <div className="nav-item">
            <button className="rounded-lg px-3 py-1.5 hover:bg-white/10 hover:text-white">Resources ▾</button>
            <div className="mega grid grid-cols-1 gap-1">
              {[["How verification works","/how-it-works"],["Evidence & proof","/evidence"],["SDGs & Egypt 2030","#sdg"],["Pricing","/pricing"],["About","/about"],["Blog & guides","/resources"]].map(([t,l]) => (
                <Link key={t} to={l} className="rounded-lg px-3 py-2 text-sm text-ink hover:bg-canvas">{t}</Link>
              ))}
            </div>
          </div>
          <a href="/" className="rounded-lg px-3 py-1.5 hover:bg-white/10 hover:text-white">Home</a>
          <a href="/pricing" className="rounded-lg px-3 py-1.5 hover:bg-white/10 hover:text-white">Pricing</a>
        </nav>
        <div className="ms-auto flex items-center gap-2">
          {isAuthenticated ? (
            <Link to="/feed" className="btn-gold px-4 py-1.5 text-sm">Open app</Link>
          ) : (
            <>
              <Link to="/login" className="rounded-xl px-3 py-1.5 text-sm font-semibold text-white/90 hover:bg-white/10">Sign in</Link>
              <Link to="/register" className="btn-gold px-3 py-1.5 text-sm">Get started</Link>
            </>
          )}
        </div>
      </div>
    </header>
  );
}
