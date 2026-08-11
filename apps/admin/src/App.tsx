import { Routes, Route, Navigate, useNavigate } from "react-router-dom";
import { useAuth } from "./auth";
import LoginPage from "./pages/LoginPage";
import ReviewsPage from "./pages/ReviewsPage";
import DashboardPage from "./pages/DashboardPage";
import CollaborationsPage from "./pages/CollaborationsPage";

function RequireAuth({ children }: { children: JSX.Element }) {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? children : <Navigate to="/login" replace />;
}

export default function App() {
  const { isAuthenticated, logout } = useAuth();
  const navigate = useNavigate();

  return (
    <div style={{ minHeight: "100vh" }}>
      {isAuthenticated && (
        <header
          style={{
            background: "var(--navy)",
            color: "#fff",
            padding: "12px 24px",
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
          }}
        >
          <strong style={{ letterSpacing: 1 }}>MASAREEN · ADMIN</strong>
          <nav style={{ display: "flex", gap: 16, alignItems: "center" }}>
            <a href="/">Dashboard</a>
            <a href="/reviews">Verification Queue</a>
            <a href="/collaborations">Collaborations</a>
            <button
              className="btn btn-ghost"
              style={{ color: "var(--navy)" }}
              onClick={() => {
                logout();
                navigate("/login");
              }}
            >
              Sign out
            </button>
          </nav>
        </header>
      )}
      <main style={{ maxWidth: 1100, margin: "0 auto", padding: 24 }}>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route
            path="/"
            element={
              <RequireAuth>
                <DashboardPage />
              </RequireAuth>
            }
          />
          <Route
            path="/reviews"
            element={
              <RequireAuth>
                <ReviewsPage />
              </RequireAuth>
            }
          />
          <Route
            path="/collaborations"
            element={
              <RequireAuth>
                <CollaborationsPage />
              </RequireAuth>
            }
          />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
    </div>
  );
}
