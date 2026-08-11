import { useState, FormEvent, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../store/authStore";
import { authService, userService } from "../services/api";
import { BrandWordmark, BrandMark } from "../components/common/Branding";
import { GoogleAuth } from "../components/common/GoogleAuth";

function AnimatedBackground() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      {/* Mesh gradient blobs */}
      <div className="blob blob-1" />
      <div className="blob blob-2" />
      <div className="blob blob-3" />

      {/* Floating particles */}
      <div className="particles">
        {Array.from({ length: 12 }).map((_, i) => (
          <div
            key={i}
            className="particle"
            style={{
              left: `${10 + Math.random() * 80}%`,
              bottom: `${Math.random() * 40}%`,
              width: `${4 + Math.random() * 6}px`,
              height: `${4 + Math.random() * 6}px`,
              animationDuration: `${6 + Math.random() * 8}s`,
              animationDelay: `${Math.random() * 6}s`,
            }}
          />
        ))}
      </div>

      {/* Dotted grid overlay */}
      <div className="absolute inset-0 bg-dots opacity-30" />

      {/* Gradient overlay */}
      <div className="absolute inset-0 bg-gradient-to-b from-white/40 via-transparent to-white/60" />
    </div>
  );
}

function GoogleLogo() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
      <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 01-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/>
      <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
      <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
      <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
    </svg>
  );
}

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [focusedField, setFocusedField] = useState<string | null>(null);
  const { login, isAuthenticated, loading } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (!loading && isAuthenticated) navigate("/feed", { replace: true });
  }, [isAuthenticated, loading, navigate]);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError("");
    if (!email.trim() || !password) {
      setError("Please enter your email and password.");
      return;
    }
    setSubmitting(true);
    try {
      const tokens = await authService.login(email.trim(), password);
      const d = (tokens as any).data ?? tokens;
      localStorage.setItem("access_token", d.access_token);
      if (d.refresh_token) localStorage.setItem("refresh_token", d.refresh_token);
      let user: any = { id: d.user_id, role: d.role, email: email.trim() };
      try { user = await userService.me(); } catch { /* fallback */ }
      login(d.access_token, user);
      navigate("/feed", { replace: true });
    } catch (err: any) {
      const msg = err?.response?.data?.message || err?.response?.data?.detail || "Invalid email or password.";
      setError(typeof msg === "string" ? msg : "Login failed. Please try again.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="relative grid min-h-screen place-items-center overflow-hidden bg-aurora px-4 py-10">
      <AnimatedBackground />

      <div className="relative z-10 w-full max-w-[420px] animate-fade-up">
        {/* Logo */}
        <div className="mb-8 flex flex-col items-center">
          <BrandWordmark height={48} />
          <p className="mt-2 text-sm text-muted/70 font-medium">Verified impact, made social</p>
        </div>

        {/* Card */}
        <div className="rounded-2xl bg-white/90 backdrop-blur-xl border border-white/30 p-8 shadow-xl">
          <h1 className="text-center text-title-lg text-ink mb-1">Welcome back</h1>
          <p className="text-center text-body-sm text-muted mb-6">Sign in to your MASAREEN account</p>

          {error && (
            <div className="mb-5 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm font-medium text-red-600 animate-scale-in" role="alert">
              {error}
            </div>
          )}

          {/* Google auth */}
          <GoogleAuth mode="login" />

          <div className="my-5 flex items-center gap-3 text-xs text-muted">
            <span className="h-px flex-1 bg-line" />
            <span className="font-medium">or continue with email</span>
            <span className="h-px flex-1 bg-line" />
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="relative">
              <label className="block text-label-lg text-ink mb-1.5">Email</label>
              <input
                className={`glass-input transition-all duration-200 ${focusedField === "email" ? "ring-4 ring-brand/10 border-brand" : ""}`}
                type="email"
                inputMode="email"
                autoComplete="email"
                placeholder="your@email.com"
                autoFocus
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                onFocus={() => setFocusedField("email")}
                onBlur={() => setFocusedField(null)}
              />
            </div>

            <div className="relative">
              <label className="block text-label-lg text-ink mb-1.5">Password</label>
              <div className="relative">
                <input
                  type={showPassword ? "text" : "password"}
                  className={`glass-input pr-11 transition-all duration-200 ${focusedField === "password" ? "ring-4 ring-brand/10 border-brand" : ""}`}
                  autoComplete="current-password"
                  placeholder="Enter your password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  onFocus={() => setFocusedField("password")}
                  onBlur={() => setFocusedField(null)}
                />
                <button
                  type="button"
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-muted hover:text-ink transition-colors duration-150"
                  onClick={() => setShowPassword((s) => !s)}
                  tabIndex={-1}
                  aria-label={showPassword ? "Hide password" : "Show password"}
                >
                  {showPassword ? (
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
                  ) : (
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
                  )}
                </button>
              </div>
            </div>

            <button
              type="submit"
              className="btn-primary w-full !py-3 text-sm font-semibold"
              disabled={submitting}
            >
              {submitting ? (
                <span className="inline-flex items-center gap-2">
                  <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                  Signing in…
                </span>
              ) : "Sign In"}
            </button>
          </form>

          <p className="mt-5 text-center text-sm text-muted">
            Don't have an account?{" "}
            <Link to="/register" className="font-semibold text-brand hover:text-brand-dark transition-colors duration-150">
              Create one
            </Link>
          </p>
        </div>

        {/* Footer */}
        <p className="mt-6 text-center text-xs text-muted/50">
          By signing in, you agree to our Terms of Service and Privacy Policy
        </p>
      </div>
    </div>
  );
}
