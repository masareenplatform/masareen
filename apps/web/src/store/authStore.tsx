import React, { createContext, useContext, useState, useEffect, useCallback, useMemo } from "react";
import { User } from "../types";
import { apiClient } from "../services/api";

interface AuthContextType {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  login: (token: string, user: User) => void;
  logout: () => void;
  loading: boolean;
}

const AuthContext = createContext<AuthContextType>({
  user: null, token: null, isAuthenticated: false,
  login: () => {}, logout: () => {}, loading: true,
});

function isTokenExpired(token: string): boolean {
  try {
    const payload = JSON.parse(atob(token.split(".")[1]));
    return payload.exp * 1000 < Date.now();
  } catch {
    return true;
  }
}

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(() => {
    const t = localStorage.getItem("access_token");
    if (t && isTokenExpired(t)) {
      localStorage.removeItem("access_token");
      localStorage.removeItem("refresh_token");
      localStorage.removeItem("user");
      return null;
    }
    return t;
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (token) {
      let saved: string | null = null;
      try {
        saved = localStorage.getItem("user");
      } catch { /* corrupted storage */ }
      if (saved) {
        try {
          setUser(JSON.parse(saved));
        } catch {
          localStorage.removeItem("user");
          setUser(null);
        }
        setLoading(false);
      } else {
        apiClient.get("/users/me").then(r => {
          setUser(r.data);
          try { localStorage.setItem("user", JSON.stringify(r.data)); } catch { /* quota */ }
        }).catch(() => {
          setToken(null);
          localStorage.removeItem("access_token");
          localStorage.removeItem("user");
        }).finally(() => setLoading(false));
      }
    } else {
      setUser(null);
      setLoading(false);
    }
  }, [token]);

  const login = useCallback((t: string, u: User) => {
    try {
      localStorage.setItem("access_token", t);
      localStorage.setItem("user", JSON.stringify(u));
    } catch { /* quota */ }
    setToken(t);
    setUser(u);
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem("access_token");
    localStorage.removeItem("refresh_token");
    localStorage.removeItem("user");
    setToken(null);
    setUser(null);
  }, []);

  useEffect(() => {
    const onSessionExpired = () => logout();
    window.addEventListener("masaren:session-expired", onSessionExpired);
    return () => window.removeEventListener("masaren:session-expired", onSessionExpired);
  }, [logout]);

  const value = useMemo(() => ({
    user, token, isAuthenticated: !!token, login, logout, loading,
  }), [user, token, login, logout, loading]);

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
