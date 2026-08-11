import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { adminApi } from "../api";
import { useAuth } from "../auth";

export default function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      const data = await adminApi.login(email, password);
      const token = data.access_token ?? data.token;
      const user = data.user ?? data;
      if (!token) throw new Error("No access token returned");
      login(token, {
        id: user.id ?? user.user_id ?? "",
        email: user.email ?? email,
        full_name: user.full_name ?? email,
        role: user.role ?? "ADMIN",
      });
      navigate("/");
    } catch (err: any) {
      setError(err?.response?.data?.message ?? err.message ?? "Login failed");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div style={{ maxWidth: 380, margin: "80px auto" }}>
      <div className="card">
        <h1 style={{ marginTop: 0, color: "var(--navy)" }}>Admin Sign In</h1>
        <form onSubmit={submit} style={{ display: "grid", gap: 12 }}>
          <input
            className="input"
            placeholder="admin@masaren.io"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            type="email"
            required
          />
          <input
            className="input"
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            type="password"
            required
          />
          {error && <p style={{ color: "#dc2626", margin: 0, fontSize: 13 }}>{error}</p>}
          <button className="btn btn-primary" disabled={busy} type="submit">
            {busy ? "Signing in..." : "Sign In"}
          </button>
        </form>
      </div>
    </div>
  );
}
