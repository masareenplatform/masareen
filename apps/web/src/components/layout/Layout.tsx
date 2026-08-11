import { useState, useEffect, useCallback } from "react";
import { Outlet, Navigate, useLocation } from "react-router-dom";
import { useAuth } from "../../store/authStore";
import TopNav from "./TopNav";
import RightRail from "./RightRail";
import Sidebar from "./Sidebar";
import { BottomNav, MenuSheet, ComposeModal } from "../common/Branding";

function PageTransition({ children }: { children: React.ReactNode }) {
  const location = useLocation();
  const [display, setDisplay] = useState(children);

  useEffect(() => {
    setDisplay(children);
  }, [children, location.pathname]);

  return (
    <div className="animate-fade-up" key={location.pathname}>
      {display}
    </div>
  );
}

export default function Layout() {
  const { isAuthenticated, loading } = useAuth();
  const [composeOpen, setComposeOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  if (loading) return (
    <div className="grid min-h-screen place-items-center bg-canvas">
      <div className="flex flex-col items-center gap-4">
        <div className="relative h-12 w-12">
          <div className="absolute inset-0 rounded-full border-4 border-navy-200" />
          <div className="absolute inset-0 rounded-full border-4 border-brand border-t-transparent animate-spin" />
        </div>
        <p className="text-sm font-medium text-muted animate-pulse-soft">Loading MASAREEN…</p>
      </div>
    </div>
  );
  if (!isAuthenticated) return <Navigate to="/login" replace />;

  return (
    <div className="app-shell flex min-h-screen flex-col">
      <TopNav onMenu={() => setMenuOpen(true)} />

      <div className="flex w-full flex-1 gap-5 px-4 py-4 pb-24 md:pb-4 md:px-6 lg:gap-6">
        <Sidebar onCompose={() => setComposeOpen(true)} />
        <main className="mx-auto min-w-0 w-full max-w-[1400px] flex-1">
          <PageTransition>
            <Outlet />
          </PageTransition>
        </main>
        <RightRail />
      </div>

      <BottomNav onCompose={() => setComposeOpen(true)} />
      <MenuSheet open={menuOpen} onClose={() => setMenuOpen(false)} />
      <ComposeModal open={composeOpen} onClose={() => setComposeOpen(false)} />
    </div>
  );
}
