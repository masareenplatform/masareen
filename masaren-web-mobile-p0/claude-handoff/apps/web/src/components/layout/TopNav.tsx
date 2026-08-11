import { useState } from "react";
import { NavLink, useNavigate } from "react-router-dom";
import { useAuth } from "../../store/authStore";
import { useI18n } from "../../i18n";
import {
  IconBell, IconMessage, IconMenu, IconGlobe, IconLogout, IconUser,
} from "../icons/Icons";
import { BrandMark, BrandWordmark, AppAvatar } from "../common/Branding";
import MessengerPopup from "../social/Messenger";

function MessengerPortal({ onClose, meName, meHandle }: { onClose: () => void; meName: string; meHandle: string }) {
  return <MessengerPopup onClose={onClose} meName={meName} meHandle={meHandle} />;
}

export default function TopNav({ onMenu }: { onMenu: () => void }) {
  const { user, logout } = useAuth();
  const { t, toggle } = useI18n();
  const navigate = useNavigate();
  const [menuOpen, setMenuOpen] = useState(false);
  const [messengerOpen, setMessengerOpen] = useState(false);

  const name = user?.full_name ?? "Guest";
  const handle = (user?.email ?? "guest").split("@")[0];

  return (
    <header className="sticky top-0 z-40 border-b border-line bg-white/90 backdrop-blur">
      <div className="mx-auto flex h-14 max-w-[1180px] items-center gap-3 px-3">
        <NavLink to="/feed" className="flex items-center gap-2 shrink-0">
          <BrandMark size={34} />
          <BrandWordmark />
        </NavLink>

        <div className="relative hidden flex-1 md:block">
          <input className="glass-input" placeholder="Search impact, people, programs…" />
        </div>

        <div className="ms-auto flex items-center gap-1">
          <button className="icon-btn" onClick={toggle} title="Language" aria-label="Toggle language">
            <IconGlobe />
          </button>
          <button className="icon-btn relative" onClick={() => setMessengerOpen(true)} title="Messages" aria-label="Messages">
            <IconMessage />
            <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-accent" />
          </button>
          <button className="icon-btn md:hidden" onClick={onMenu} title="Menu" aria-label="Open menu">
            <IconMenu />
          </button>

          <div className="relative hidden md:block">
            <button
              className="flex items-center gap-2 rounded-full p-0.5 hover:bg-canvas"
              onClick={() => setMenuOpen((s) => !s)}
              aria-label="Account"
            >
              <AppAvatar name={name} handle={handle} size={34} />
            </button>
            {menuOpen && (
              <>
                <div className="fixed inset-0 z-40" onClick={() => setMenuOpen(false)} />
                <div className="absolute end-0 z-50 mt-2 w-56 animate-pop card p-2">
                  <div className="flex items-center gap-3 border-b border-line px-2 pb-3 pt-1">
                    <AppAvatar name={name} handle={handle} size={40} />
                    <div className="min-w-0">
                      <p className="truncate text-sm font-semibold text-ink">{name}</p>
                      <p className="truncate text-xs text-muted">@{handle}</p>
                    </div>
                  </div>
                  <NavLink to="/profile" className="nav-link mt-1" onClick={() => setMenuOpen(false)}>
                    <IconUser size={18} /> Profile
                  </NavLink>
                  <button
                    className="nav-link w-full text-start"
                    onClick={() => { setMenuOpen(false); logout(); navigate("/login"); }}
                  >
                    <IconLogout size={18} /> {t("action.signout")}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      {messengerOpen && (
        <MessengerPortal onClose={() => setMessengerOpen(false)} meName={name} meHandle={handle} />
      )}
    </header>
  );
}
