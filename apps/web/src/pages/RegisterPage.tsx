import { useState, FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";
import { authService, userService } from "../services/api";
import { useAuth } from "../store/authStore";
import { BrandWordmark, BrandMark } from "../components/common/Branding";
import { GoogleAuth } from "../components/common/GoogleAuth";

const AUDIENCES = ["STUDENT", "PROFESSIONAL", "NGO", "CORPORATE", "GOVERNMENT"] as const;

function AnimatedBackground() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      <div className="blob blob-1" />
      <div className="blob blob-2" />
      <div className="blob blob-3" />
      <div className="particles">
        {Array.from({ length: 10 }).map((_, i) => (
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
      <div className="absolute inset-0 bg-dots opacity-30" />
      <div className="absolute inset-0 bg-gradient-to-b from-white/40 via-transparent to-white/60" />
    </div>
  );
}

export default function RegisterPage() {
  const [formData, setFormData] = useState({
    full_name: "",
    email: "",
    password: "",
    phone: "",
    national_id: "",
    university_id: "",
    role: "INDIVIDUAL" as "INDIVIDUAL" | "ORGANIZATION",
    audience: "STUDENT" as (typeof AUDIENCES)[number],
  });
  const [consent, setConsent] = useState(false);
  const [error, setError] = useState("");
  const [ok, setOk] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const navigate = useNavigate();
  const { login } = useAuth();

  const pwValid = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/.test(formData.password);
  const pwStrength = formData.password.length === 0 ? 0 :
    [formData.password.length >= 8, /[A-Z]/.test(formData.password), /[a-z]/.test(formData.password),
     /\d/.test(formData.password), /[@$!%*?&]/.test(formData.password)].filter(Boolean).length;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError("");
    setOk("");
    if (!consent) { setError("Please accept the terms to create your account."); return; }
    if (!pwValid) { setError("Password must be at least 8 characters and include uppercase, lowercase, a number and a special character."); return; }
    setSubmitting(true);
    try {
      const res = await authService.register({
        full_name: formData.full_name,
        email: formData.email,
        password: formData.password,
        phone: formData.phone,
        national_id: formData.national_id || undefined,
        university_id: formData.university_id || undefined,
        role: formData.role,
        audience: formData.audience,
      });
      if (res?.auto_verified) {
        try {
          const tokens = await authService.login(formData.email, formData.password);
          const d = (tokens as any).data ?? tokens;
          if (d.access_token) {
            localStorage.setItem("access_token", d.access_token);
            if (d.refresh_token) localStorage.setItem("refresh_token", d.refresh_token);
            let user: any = { id: d.user_id, role: d.role, email: formData.email };
            try { user = await userService.me(); } catch { /* fallback */ }
            login(d.access_token, user);
            setOk("Account created and verified, taking you in…");
            setTimeout(() => navigate("/feed"), 700);
            return;
          }
        } catch { /* fall through */ }
      }
      setOk(res?.message || "Account created, redirecting to sign in…");
      setTimeout(() => navigate("/login"), 1200);
    } catch (err: any) {
      const data = err?.response?.data;
      setError(data?.message || data?.detail?.[0]?.msg || err?.message || "Registration failed");
    } finally {
      setSubmitting(false);
    }
  };

  const updateField = (field: string, val: any) => setFormData((prev) => ({ ...prev, [field]: val }));
  const fieldCls = "glass-input";
  const strengthColors = ["bg-red-400", "bg-orange-400", "bg-amber-400", "bg-brand-300", "bg-accent"];
  const strengthLabels = ["Weak", "Fair", "Good", "Strong", "Excellent"];

  return (
    <div className="relative grid min-h-screen place-items-center overflow-hidden bg-aurora px-4 py-10">
      <AnimatedBackground />

      <div className="relative z-10 w-full max-w-[480px] animate-fade-up">
        <div className="mb-8 flex flex-col items-center">
          <BrandWordmark height={48} />
          <p className="mt-2 text-sm text-muted/70 font-medium">Join the verified impact network</p>
        </div>

        <div className="rounded-2xl bg-white/90 backdrop-blur-xl border border-white/30 p-8 shadow-xl">
          <h1 className="text-center text-title-lg text-ink mb-1">Create your account</h1>
          <p className="text-center text-body-sm text-muted mb-6">Tell us about yourself to personalize your experience</p>

          {error && (
            <div className="mb-5 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm font-medium text-red-600 animate-scale-in">{error}</div>
          )}
          {ok && (
            <div className="mb-5 rounded-lg border border-accent/30 bg-accent-50 px-4 py-3 text-sm font-medium text-accent animate-scale-in">{ok}</div>
          )}

          <GoogleAuth mode="register" />

          <div className="my-5 flex items-center gap-3 text-xs text-muted">
            <span className="h-px flex-1 bg-line" />
            <span className="font-medium">or fill in the details</span>
            <span className="h-px flex-1 bg-line" />
          </div>

          <form onSubmit={handleSubmit} className="space-y-3.5">
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <label className="block text-label-lg text-ink mb-1.5">Full Name</label>
                <input className={fieldCls} placeholder="John Doe" value={formData.full_name} onChange={(e) => updateField("full_name", e.target.value)} />
              </div>
              <div>
                <label className="block text-label-lg text-ink mb-1.5">Email</label>
                <input className={fieldCls} type="email" inputMode="email" autoComplete="email" placeholder="your@email.com" required value={formData.email} onChange={(e) => updateField("email", e.target.value)} />
              </div>
            </div>

            <div>
              <label className="block text-label-lg text-ink mb-1.5">Password</label>
              <input
                type="password"
                className={`${fieldCls} ${formData.password && !pwValid ? "border-red-300 focus:border-red-400 focus:ring-red-100" : ""}`}
                placeholder="Min 8 chars: A-Z, a-z, 0-9, symbol"
                value={formData.password}
                onChange={(e) => updateField("password", e.target.value)}
              />
              {formData.password.length > 0 && (
                <div className="mt-2">
                  <div className="flex gap-1">
                    {[0, 1, 2, 3, 4].map((i) => (
                      <div
                        key={i}
                        className={`h-1 flex-1 rounded-full transition-all duration-300 ${
                          i < pwStrength ? strengthColors[pwStrength - 1] : "bg-navy-200"
                        }`}
                      />
                    ))}
                  </div>
                  <p className="mt-1 text-[11px] text-muted">
                    {pwStrength > 0 ? strengthLabels[pwStrength - 1] : "Enter a password"}
                  </p>
                </div>
              )}
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <label className="block text-label-lg text-ink mb-1.5">Phone (optional)</label>
                <input className={fieldCls} placeholder="+1 234 567 890" value={formData.phone} onChange={(e) => updateField("phone", e.target.value)} />
              </div>
              <div>
                <label className="block text-label-lg text-ink mb-1.5">National ID (optional)</label>
                <input className={fieldCls} placeholder="ID number" value={formData.national_id} onChange={(e) => updateField("national_id", e.target.value)} />
              </div>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <label className="block text-label-lg text-ink mb-1.5">Account Type</label>
                <select className={fieldCls} value={formData.role} onChange={(e) => updateField("role", e.target.value)}>
                  <option value="INDIVIDUAL">Individual</option>
                  <option value="ORGANIZATION">Organization</option>
                </select>
              </div>
              <div>
                <label className="block text-label-lg text-ink mb-1.5">Audience</label>
                <select className={fieldCls} value={formData.audience} onChange={(e) => updateField("audience", e.target.value)}>
                  {AUDIENCES.map((a) => (
                    <option key={a} value={a}>{a.charAt(0) + a.slice(1).toLowerCase()}</option>
                  ))}
                </select>
              </div>
            </div>

            {formData.audience === "STUDENT" && (
              <div>
                <label className="block text-label-lg text-ink mb-1.5">University ID (optional)</label>
                <input className={fieldCls} placeholder="Student ID" value={formData.university_id} onChange={(e) => updateField("university_id", e.target.value)} />
              </div>
            )}

            <label className="flex items-start gap-3 text-sm text-muted cursor-pointer">
              <input
                type="checkbox"
                className="mt-0.5 h-4 w-4 rounded border-line text-brand focus:ring-brand/20"
                checked={consent}
                onChange={(e) => setConsent(e.target.checked)}
              />
              <span>
                I agree to the MASAREEN Terms of Service and Privacy Policy, and consent to processing my data for the alpha programme.
              </span>
            </label>

            <button type="submit" className="btn-primary w-full !py-3 text-sm font-semibold" disabled={submitting}>
              {submitting ? (
                <span className="inline-flex items-center gap-2">
                  <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                  Creating account…
                </span>
              ) : "Create Account"}
            </button>
          </form>

          <p className="mt-5 text-center text-sm text-muted">
            Already registered?{" "}
            <Link to="/login" className="font-semibold text-brand hover:text-brand-dark transition-colors duration-150">
              Sign In
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}
