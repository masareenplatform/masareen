import { useEffect } from "react";

/**
 * Google OAuth redirect target (response_type=id_token). Google returns the
 * token in the URL fragment (#id_token=...). We forward it to the opener window
 * via postMessage and close this popup.
 */
export default function GoogleAuthCallback() {
  useEffect(() => {
    const hash = window.location.hash.replace(/^#/, "");
    const params = new URLSearchParams(hash);
    const idToken = params.get("id_token");
    try {
      if (idToken && window.opener) {
        window.opener.postMessage({ id_token: idToken }, window.location.origin);
      }
    } catch { /* ignore */ }
    window.close();
  }, []);
  return (
    <div style={{ display: "grid", placeItems: "center", height: "100vh", fontFamily: "sans-serif", color: "#0250A3" }}>
      Signing you in to MASAREEN…
    </div>
  );
}
