import { useState, FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";
import { authService } from "../services/api";
import { BrandMark, BrandWordmark } from "../components/common/Branding";
import { IconGoogle } from "../components/icons/Icons";

export default function RegisterPage() {
  const [formData, setFormData] = useState({
    full_name: "",
    email: "",
    password: "",
    phone: "",
    national_id: "",
    university_id: "",
    role: "INDIVIDUAL" as "INDIVIDUAL" | "ORGANIZATION",
    audience: "STUDENT" as "STUDENT" | "PROFESSIONAL" | "NGO" | "CORPORATE" | "GOVERNMENT",
  });
  const [error, setError] = useState("");
  const [ok, setOk] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError("");
    try {
      await authService.register({
        full_name: formData.full_name,
        email: formData.email,
        password: formData.password,
        phone: formData.phone,
        role: formData.role,
      });
      setOk(true);
      setTimeout(() => navigate("/login"), 900);
    } catch (err: any) {
      setError(err?.response?.data?.message || "Registration failed");
    }
  };

  const updateField = (field: string, val: any) => {
    setFormData((prev) => ({ ...prev, [field]: val }));
  };

  const fieldCls =
    "glass-input mb-3 [appearance:none]";

  return (
    <div className="relative grid min-h-screen place-items-center overflow-hidden bg-aurora-light px-4 py-10">
      <div className="pointer-events-none absolute inset-0 bg-dots opacity-50" />
      <div className="relative w-full max-w-[460px]">
        <div className="mb-6 flex flex-col items-center">
          <BrandMark size={64} />
          <BrandWordmark className="mt-1 !text-3xl" />
        </div>

        <form onSubmit={handleSubmit} className="card animate-fade-up p-6">
          <h2 className="mb-1 text-center font-display text-xl font-extrabold text-ink">
            Create your verified impact account
          </h2>

          {error && (
            <div className="mb-4 mt-3 rounded-xl border border-rose-200 bg-rose-50 px-3 py-2 text-sm font-medium text-rose-600">
              {error}
            </div>
          )}
          {ok && (
            <div className="mb-4 mt-3 rounded-xl border border-accent/30 bg-accent-50 px-3 py-2 text-sm font-medium text-accent-700">
              Account created, redirecting to sign in…
            </div>
          )}

          <button
            type="button"
            className="btn mb-4 w-full border border-line bg-white text-ink hover:bg-canvas"
          >
            <IconGoogle size={18} /> Continue with Google
          </button>

          <div className="my-4 flex items-center gap-3 text-xs text-muted">
            <span className="h-px flex-1 bg-line" /> or <span className="h-px flex-1 bg-line" />
          </div>

          <div className="grid grid-cols-1 gap-0 sm:grid-cols-2 sm:gap-3">
            <input className={fieldCls} placeholder="Full Name" value={formData.full_name} onChange={(e) => updateField("full_name", e.target.value)} />
            <input className={fieldCls} placeholder="Email" value={formData.email} onChange={(e) => updateField("email", e.target.value)} />
          </div>

          <input type="password" className={fieldCls} placeholder="Strong Password (8+ chars, mixed case)" value={formData.password} onChange={(e) => updateField("password", e.target.value)} />

          <div className="grid grid-cols-1 gap-0 sm:grid-cols-2 sm:gap-3">
            <input className={fieldCls} placeholder="Phone Number" value={formData.phone} onChange={(e) => updateField("phone", e.target.value)} />
            <input className={fieldCls} placeholder="National ID" value={formData.national_id} onChange={(e) => updateField("national_id", e.target.value)} />
          </div>

          <div className="grid grid-cols-1 gap-0 sm:grid-cols-2 sm:gap-3">
            <select className={fieldCls} value={formData.role} onChange={(e) => updateField("role", e.target.value)}>
              <option value="INDIVIDUAL">Individual</option>
              <option value="ORGANIZATION">Organization</option>
            </select>
            <select className={fieldCls} value={formData.audience} onChange={(e) => updateField("audience", e.target.value)}>
              <option value="STUDENT">Student</option>
              <option value="PROFESSIONAL">Professional</option>
              <option value="NGO">NGO</option>
              <option value="CORPORATE">Corporate</option>
              <option value="GOVERNMENT">Government</option>
            </select>
          </div>

          {formData.audience === "STUDENT" && (
            <input className={fieldCls} placeholder="University ID" value={formData.university_id} onChange={(e) => updateField("university_id", e.target.value)} />
          )}

          <button type="submit" className="btn-gold mt-1 w-full">Create Account</button>

          <p className="mt-4 text-center text-sm text-muted">
            Already registered?{" "}
            <Link to="/login" className="font-semibold text-brand hover:underline">Sign In</Link>
          </p>
        </form>
      </div>
    </div>
  );
}
