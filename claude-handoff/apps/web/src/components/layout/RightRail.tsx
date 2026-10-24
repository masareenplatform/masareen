import { NavLink } from "react-router-dom";
import { IconSparkles, IconTrending, IconUsers } from "../icons/Icons";
import { avatarColors } from "../../services/postService";

function MiniAvatar({ name, handle }: { name: string; handle: string }) {
  const { c1, c2 } = avatarColors(handle || name);
  return (
    <span
      className="avatar-gradient grid h-9 w-9 place-items-center rounded-full text-sm font-semibold text-white"
      style={{ ["--c1" as any]: c1, ["--c2" as any]: c2 }}
    >
      {(name?.[0] ?? "?").toUpperCase()}
    </span>
  );
}

const SUGGESTIONS = [
  { name: "GreenRoots NGO", handle: "greenroots", role: "Organization" },
  { name: "Lina Haddad", handle: "lina", role: "Specialist" },
  { name: "Yusuf Rahman", handle: "yusuf", role: "Individual" },
];

const TRENDING = [
  { tag: "#CoastalRestoration", posts: "1.2k posts" },
  { tag: "#CleanWater", posts: "840 posts" },
  { tag: "#SolarForAll", posts: "612 posts" },
  { tag: "#YouthFellowship", posts: "503 posts" },
];

export default function RightRail() {
  return (
    <aside className="hidden w-80 shrink-0 lg:block">
      <div className="sticky top-20 flex flex-col gap-4">
        <section className="card p-4">
          <h3 className="mb-3 flex items-center gap-2 font-display text-sm font-bold text-ink">
            <IconUsers size={18} className="text-brand" /> People to follow
          </h3>
          <ul className="flex flex-col gap-3">
            {SUGGESTIONS.map((s) => (
              <li key={s.handle} className="flex items-center gap-3">
                <MiniAvatar name={s.name} handle={s.handle} />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold text-ink">{s.name}</p>
                  <p className="truncate text-xs text-muted">@{s.handle}</p>
                </div>
                <button className="btn-soft px-3 py-1.5 text-xs">Follow</button>
              </li>
            ))}
          </ul>
        </section>

        <section className="card p-4">
          <h3 className="mb-3 flex items-center gap-2 font-display text-sm font-bold text-ink">
            <IconTrending size={18} className="text-accent" /> Trending in impact
          </h3>
          <ul className="flex flex-col gap-2.5">
            {TRENDING.map((t) => (
              <li key={t.tag} className="cursor-pointer">
                <p className="text-sm font-semibold text-brand">{t.tag}</p>
                <p className="text-xs text-muted">{t.posts}</p>
              </li>
            ))}
          </ul>
        </section>

        <section className="card overflow-hidden">
          <div className="flex items-center gap-2 bg-gradient-to-r from-brand to-accent px-4 py-3 text-white">
            <IconSparkles size={18} />
            <p className="text-sm font-semibold">MASAREN, verified impact, made social</p>
          </div>
          <div className="flex flex-wrap gap-x-3 gap-y-1 px-4 py-3 text-xs text-muted">
            <span>About</span><span>Privacy</span><span>Terms</span>
            <span>POAI Verification</span><span>© 2026 MASAREN</span>
          </div>
        </section>
      </div>
    </aside>
  );
}
