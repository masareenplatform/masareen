import React, { createContext, useContext, useState, useCallback } from "react";

interface AdminUser {
  id: string;
  email: string;
  full_name: string;
  role: string;
}

interface AuthContextType {
  user: AdminUser | null;
  token: string | null;
  isAuthenticated: boolean;
  login: (token: string, user: AdminUser) => void;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType>({
  user: null,
  token: null,
  isAuthenticated: false,
  login: () => {},
  logout: () => {},
});

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [user, setUser] = useState<AdminUser | null>(() => {
    const saved = localStorage.getItem("admin_user");
    return saved ? JSON.parse(saved) : null;
  });
  const [token, setToken] = useState<string | null>(() =>
    localStorage.getItem("admin_token")
  );

  const login = useCallback((t: string, u: AdminUser) => {
    localStorage.setItem("admin_token", t);
    localStorage.setItem("admin_user", JSON.stringify(u));
    setToken(t);
    setUser(u);
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem("admin_token");
    localStorage.removeItem("admin_user");
    setToken(null);
    setUser(null);
  }, []);

  return (
    <AuthContext.Provider value={{ user, token, isAuthenticated: !!token, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
