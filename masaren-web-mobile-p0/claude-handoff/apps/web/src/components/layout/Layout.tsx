import { useState } from "react";
import { Outlet, Navigate } from "react-router-dom";
import { useAuth } from "../../store/authStore";
import TopNav from "./TopNav";
import RightRail from "./RightRail";
import Sidebar from "./Sidebar";
import { BottomNav, MenuSheet, ComposeModal } from "../common/Branding";

export default function Layout() {
  const { isAuthenticated, loading } = useAuth();
  const [composeOpen, setComposeOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  if (loading) return <div className="grid min-h-screen place-items-center text-muted">Loading…</div>;
  if (!isAuthenticated) return <Navigate to="/login" replace />;

  return (
    <div className="flex min-h-screen flex-col bg-canvas">
      <TopNav onMenu={() => setMenuOpen(true)} />

      <div className="mx-auto flex w-full max-w-[1180px] flex-1 gap-5 px-3 py-5 pb-24 md:pb-5">
        <Sidebar onCompose={() => setComposeOpen(true)} />
        <main className="min-w-0 flex-1">
          <div className="animate-fade-up">
            <Outlet />
          </div>
        </main>
        <RightRail />
      </div>

      <BottomNav onCompose={() => setComposeOpen(true)} />
      <MenuSheet open={menuOpen} onClose={() => setMenuOpen(false)} />
      <ComposeModal open={composeOpen} onClose={() => setComposeOpen(false)} />
    </div>
  );
}
