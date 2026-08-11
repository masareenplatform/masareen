import { NavLink } from "react-router-dom";
import { useI18n } from "../../i18n";
import { BrandMark, BrandWordmark, PRIMARY_NAV, TOOLS_NAV, NavItem } from "../common/Branding";
import { IconPlus } from "../icons/Icons";

function NavRow({ item, onNavigate }: { item: NavItem; onNavigate?: () => void }) {
  return (
    <NavLink
      to={item.to}
      onClick={onNavigate}
      className={({ isActive }) => `nav-link ${isActive ? "nav-link-active" : ""}`}
    >
      <span className="text-brand"><item.icon size={20} /></span>
      <span>{item.label}</span>
    </NavLink>
  );
}

export function SidebarNav({ onNavigate, onCompose }: { onNavigate?: () => void; onCompose?: () => void }) {
  const { t } = useI18n();
  return (
    <div className="flex flex-col gap-1 p-3">
      <button className="btn-gold mb-3 w-full" onClick={onCompose}>
        <IconPlus size={18} /> Create post
      </button>

      <p className="px-3 pb-1 pt-1 text-[11px] font-bold uppercase tracking-wide text-muted">Menu</p>
      {PRIMARY_NAV.map((it) => <NavRow key={it.to} item={it} onNavigate={onNavigate} />)}

      <p className="px-3 pb-1 pt-4 text-[11px] font-bold uppercase tracking-wide text-muted">Tools</p>
      {TOOLS_NAV.map((it) => <NavRow key={it.to} item={it} onNavigate={onNavigate} />)}
    </div>
  );
}

export default function Sidebar({ onCompose }: { onCompose: () => void }) {
  return (
    <aside className="hidden md:flex w-64 shrink-0 flex-col">
      <div className="sticky top-16 flex flex-col gap-1">
        <div className="flex items-center gap-2 px-3 py-3">
          <BrandMark size={34} />
          <BrandWordmark />
        </div>
        <SidebarNav onCompose={onCompose} />
      </div>
    </aside>
  );
}
