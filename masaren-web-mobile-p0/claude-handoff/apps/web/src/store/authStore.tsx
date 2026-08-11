import React, { createContext, useContext, useState, useEffect, useCallback } from "react";
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

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(localStorage.getItem("access_token"));
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (token) {
      const saved = localStorage.getItem("user");
      if (saved) {
        setUser(JSON.parse(saved));
        setLoading(false);
      } else {
        apiClient.get("/users/me").then(r => {
          setUser(r.data);
          localStorage.setItem("user", JSON.stringify(r.data));
        }).catch(() => {
          setToken(null);
          localStorage.removeItem("access_token");
          localStorage.removeItem("user");
        }).finally(() => setLoading(false));
      }
    } else {
      setLoading(false);
    }
  }, [token]);

  const login = useCallback((t: string, u: User) => {
    localStorage.setItem("access_token", t);
    localStorage.setItem("user", JSON.stringify(u));
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

  // Fired by services/api.ts when a 401 survives a refresh attempt (refresh
  // token missing/expired/revoked). Ends the local session so route guards
  // redirect to /login instead of the app silently failing every request.
  useEffect(() => {
    const onSessionExpired = () => logout();
    window.addEventListener("masaren:session-expired", onSessionExpired);
    return () => window.removeEventListener("masaren:session-expired", onSessionExpired);
  }, [logout]);

  return (
    <AuthContext.Provider value={{ user, token, isAuthenticated: !!token, login, logout, loading }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
