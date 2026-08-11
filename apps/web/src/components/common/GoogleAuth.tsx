import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { authService, userService } from "../../services/api";
import { useAuth } from "../../store/authStore";
import { GoogleButton } from "./Showcase";

export const GOOGLE_CLIENT_ID =
  "975868482938-b3kr1balvl6ml314qm4c7nlkpm8d41kj.apps.googleusercontent.com";

/**
 * Opens Google's OAuth consent in a popup, waits for the redirect callback
 * (served by GoogleAuthCallback), then exchanges the id_token with our backend
 * and logs the user in. The callback page posts the id_token back via
 * window.postMessage to avoid leaking it in the URL.
 */
export function GoogleAuth({ mode = "login", onBefore, onAfter, full = true }: any) {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");

  const start = () => {
    setErr(""); setBusy(true);
    onBefore?.();
    const redirectUri = `${window.location.origin}/oauth/google/callback`;
    const url =
      "https://accounts.google.com/o/oauth2/v2/auth?" +
      new URLSearchParams({
        client_id: GOOGLE_CLIENT_ID,
        redirect_uri: redirectUri,
        response_type: "id_token",
        scope: "openid email profile",
        nonce: Math.random().toString(36).slice(2),
        prompt: "select_account",
      }).toString();

    const popup = window.open(url, "masareen-google", "width=480,height=640");
    const onMsg = async (e: MessageEvent) => {
      if (e.origin !== window.location.origin) return;
      const idToken = e.data?.id_token;
      if (!idToken) return;
      window.removeEventListener("message", onMsg);
      popup?.close();
      try {
        const res = await authService.google(idToken);
        const d = res.data;
        let user: any = { id: d.user_id, role: d.role, email: d.email, full_name: d.full_name };
        try { user = await userService.me(); } catch { /* use token-derived */ }
        if (d.refresh_token) localStorage.setItem("refresh_token", d.refresh_token);
        login(d.access_token, user);
        onAfter?.(user);
        navigate("/onboarding");
      } catch (e: any) {
        setErr(e?.response?.data?.message || "Google sign-in failed");
        setBusy(false);
      }
    };
    window.addEventListener("message", onMsg);
    const poll = setInterval(() => {
      if (popup?.closed) { clearInterval(poll); window.removeEventListener("message", onMsg); setBusy(false); }
    }, 800);
  };

  return (
    <div className="w-full">
      <GoogleButton onClick={start} label={mode === "register" ? "Sign up with Google" : "Continue with Google"} full={full} />
      {busy && <p className="mt-2 text-center text-xs text-muted">Waiting for Google…</p>}
      {err && <p className="mt-2 text-center text-xs text-red-600">{err}</p>}
    </div>
  );
}
