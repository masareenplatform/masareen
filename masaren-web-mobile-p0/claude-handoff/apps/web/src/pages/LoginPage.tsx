import { useState, FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../store/authStore";
import { authService, userService } from "../services/api";
import { BrandMark, BrandWordmark } from "../components/common/Branding";
import { IconGoogle } from "../components/icons/Icons";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError("");
    try {
      const tokens = await authService.login(email, password);
      localStorage.setItem("access_token", tokens.access_token);
      if (tokens.refresh_token) localStorage.setItem("refresh_token", tokens.refresh_token);
      let user: any = { id: tokens.user_id, role: tokens.role, email };
      try {
        user = await userService.me();
      } catch {
        /* fall back to token-derived identity */
      }
      login(tokens.access_token, user);
      navigate("/dashboard");
    } catch (err: any) {
      setError(err?.response?.data?.message || "Login failed");
    }
  };

  return (
    <div className="relative grid min-h-screen place-items-center overflow-hidden bg-aurora-light px-4 py-10">
      <div className="pointer-events-none absolute inset-0 bg-dots opacity-50" />
      <div className="relative w-full max-w-[400px]">
        <div className="mb-6 flex flex-col items-center">
          <BrandMark size={64} />
          <BrandWordmark className="mt-1 !text-3xl" />
        </div>

        <form
          onSubmit={handleSubmit}
          className="card animate-fade-up p-6"
        >
          {error && (
            <div className="mb-4 rounded-xl border border-rose-200 bg-rose-50 px-3 py-2 text-sm font-medium text-rose-600">
              {error}
            </div>
          )}

          <button
            type="button"
            className="btn w-full border border-line bg-white text-ink hover:bg-canvas"
          >
            <IconGoogle size={18} /> Continue with Google
          </button>

          <div className="my-4 flex items-center gap-3 text-xs text-muted">
            <span className="h-px flex-1 bg-line" /> or <span className="h-px flex-1 bg-line" />
          </div>

          <input className="glass-input mb-3" placeholder="Email" value={email} onChange={(e) => setEmail(e.target.value)} />
          <input type="password" className="glass-input mb-4" placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)} />

          <button type="submit" className="btn-gold w-full">Sign In</button>

          <p className="mt-4 text-center text-sm text-muted">
            No account?{" "}
            <Link to="/register" className="font-semibold text-brand hover:underline">Register</Link>
          </p>
        </form>
      </div>
    </div>
  );
}
