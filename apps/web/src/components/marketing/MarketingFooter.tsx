import { Link } from "react-router-dom";
import { useAuth } from "../../store/authStore";
import { BrandWordmark } from "../common/Branding";

export default function MarketingFooter() {
  const { isAuthenticated } = useAuth();
  return (
    <footer className="border-t border-line bg-white py-10">
      <div className="mx-auto grid max-w-6xl gap-8 px-4 sm:grid-cols-2 lg:grid-cols-4">
        <div>
          <BrandWordmark height={72} />
          <p className="mt-3 text-sm text-muted">Verified impact infrastructure for everyone building a better world.</p>
        </div>
        <div className="text-sm"><h4 className="font-semibold text-ink">Product</h4><ul className="mt-2 space-y-1 text-muted"><li><Link to="/feed" className="hover:text-brand">Feed</Link></li><li><Link to="/how-it-works" className="hover:text-brand">How it works</Link></li><li><Link to="/pricing" className="hover:text-brand">Pricing</Link></li></ul></div>
        <div className="text-sm"><h4 className="font-semibold text-ink">Impact</h4><ul className="mt-2 space-y-1 text-muted"><li><Link to="/verification" className="hover:text-brand">Verification</Link></li><li><Link to="/solutions" className="hover:text-brand">Solutions</Link></li><li><Link to="/about" className="hover:text-brand">About</Link></li></ul></div>
        <div className="text-sm"><h4 className="font-semibold text-ink">Get started</h4><ul className="mt-2 space-y-1 text-muted"><li>{isAuthenticated ? <Link to="/feed" className="hover:text-brand">Open app</Link> : <Link to="/login" className="hover:text-brand">Sign in</Link>}</li><li><Link to="/register" className="hover:text-brand">Create account</Link></li><li><a href="/downloads/masaren-app-release.apk" className="hover:text-brand">Android APK</a></li></ul></div>
      </div>
      <p className="mx-auto mt-8 max-w-6xl px-4 text-xs text-muted">© 2026 MASAREEN · Aligned with UN SDGs & Egypt Vision 2030 · POAI Verification</p>
    </footer>
  );
}
