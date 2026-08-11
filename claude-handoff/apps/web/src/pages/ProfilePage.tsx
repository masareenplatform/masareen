import { useEffect, useRef, useState } from "react";
import { useAuth } from "../store/authStore";
import { postService, avatarColors } from "../services/postService";
import type { Post } from "../types/social";
import PostCard from "../components/social/PostCard";
import { IconCamera, IconCover, IconCheck, IconImpact } from "../components/icons/Icons";

function Avatar({ name, handle, size = 96 }: { name: string; handle: string; size?: number }) {
  const { c1, c2 } = avatarColors(handle || name);
  return (
    <span
      className="avatar-gradient grid shrink-0 place-items-center rounded-full font-bold text-white ring-4 ring-white"
      style={{ width: size, height: size, fontSize: size * 0.42, ["--c1" as any]: c1, ["--c2" as any]: c2 }}
    >
      {(name?.[0] ?? "?").toUpperCase()}
    </span>
  );
}

type Tab = "posts" | "about" | "impact";

const COVER_PRESETS = [
  "linear-gradient(135deg,#2563eb,#16a34a)",
  "linear-gradient(135deg,#1d4ed8,#22c55e)",
  "linear-gradient(135deg,#0ea5e9,#14b8a6)",
  "linear-gradient(135deg,#4f46e5,#16a34a)",
];

export default function ProfilePage() {
  const { user } = useAuth();
  const name = user?.full_name ?? "Guest";
  const handle = (user?.email ?? "guest").split("@")[0];
  const role = user?.role ?? "Individual";

  const [cover, setCover] = useState<string | null>(null);
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null);
  const [tab, setTab] = useState<Tab>("posts");
  const [posts, setPosts] = useState<Post[]>([]);
  const avatarInput = useRef<HTMLInputElement | null>(null);
  const coverInput = useRef<HTMLInputElement | null>(null);

  function refresh() {
    setPosts(postService.list({ authorId: user?.id ?? "me" }));
  }
  useEffect(() => {
    refresh();
    const off = postService.subscribe(refresh);
    return off;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

  const totalLikes = posts.reduce((n, p) => n + p.likes, 0);
  const totalImpact = posts.reduce((n, p) => n + (p.impactValue ?? 0), 0);

  return (
    <div className="mx-auto max-w-2xl">
      <section className="card overflow-hidden">
        {/* Cover */}
        <div
          className="relative h-40 w-full sm:h-56"
          style={{ background: cover ?? COVER_PRESETS[0] }}
        >
          <button
            className="absolute bottom-3 end-3 inline-flex items-center gap-1.5 rounded-full bg-black/40 px-3 py-1.5 text-xs font-medium text-white backdrop-blur hover:bg-black/55"
            onClick={() => coverInput.current?.click()}
          >
            <IconCover size={15} /> Edit cover
          </button>
          <input
            ref={coverInput}
            type="file"
            accept="image/*"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) setCover(URL.createObjectURL(f));
            }}
          />
        </div>

        {/* Avatar + meta */}
        <div className="px-4 pb-4">
          <div className="-mt-12 flex items-end gap-4">
            <div className="relative">
              {avatarUrl ? (
                <img src={avatarUrl} alt={name} className="h-24 w-24 rounded-full object-cover ring-4 ring-white" />
              ) : (
                <Avatar name={name} handle={handle} size={96} />
              )}
              <button
                className="absolute bottom-1 end-1 grid h-7 w-7 place-items-center rounded-full bg-white text-brand shadow-card"
                onClick={() => avatarInput.current?.click()}
                title="Change photo"
              >
                <IconCamera size={15} />
              </button>
              <input
                ref={avatarInput}
                type="file"
                accept="image/*"
                hidden
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) setAvatarUrl(URL.createObjectURL(f));
                }}
              />
            </div>
            <div className="mb-1 flex-1">
              <h1 className="flex items-center gap-1.5 font-display text-xl font-extrabold text-ink">
                {name}
                {(role === "ORGANIZATION" || role === "ADMIN") && <IconCheck size={18} className="text-brand" />}
              </h1>
              <p className="text-sm text-muted">@{handle}</p>
            </div>
            <button className="btn-gold mb-1 hidden sm:inline-flex">Edit profile</button>
          </div>

          <p className="mt-3 text-sm text-ink">
            Impact-driven {role.toLowerCase()} on MASAREN. Building verified, measurable change — one post at a time.
          </p>

          <div className="mt-3 flex flex-wrap gap-2">
            <span className="chip-brand">{posts.length} posts</span>
            <span className="chip-accent">{totalLikes} likes earned</span>
            {totalImpact > 0 && (
              <span className="chip inline-flex items-center gap-1"><IconImpact size={13} /> {totalImpact.toLocaleString()} impact</span>
            )}
          </div>
        </div>

        {/* Tabs */}
        <div className="flex border-t border-line text-sm font-semibold">
          {(["posts", "about", "impact"] as Tab[]).map((tk) => (
            <button
              key={tk}
              onClick={() => setTab(tk)}
              className={`flex-1 py-3 capitalize transition ${
                tab === tk ? "border-b-2 border-brand text-brand" : "text-muted hover:bg-canvas"
              }`}
            >
              {tk}
            </button>
          ))}
        </div>
      </section>

      <div className="mt-4">
        {tab === "posts" &&
          (posts.length === 0 ? (
            <p className="py-10 text-center text-sm text-muted">No posts yet. Share your first impact story!</p>
          ) : (
            <div className="flex flex-col gap-4">
              {posts.map((p) => <PostCard key={p.id} post={p} onChanged={refresh} />)}
            </div>
          ))}
        {tab === "about" && (
          <section className="card p-4 text-sm text-ink">
            <h3 className="mb-2 font-display font-bold">About</h3>
            <p className="text-muted">Role: <span className="text-ink">{role}</span></p>
            <p className="mt-1 text-muted">Email: <span className="text-ink">{user?.email ?? "—"}</span></p>
            <p className="mt-1 text-muted">PMS Score: <span className="text-ink">{user?.pms_score ?? "—"}</span></p>
          </section>
        )}
        {tab === "impact" && (
          <section className="card p-4">
            <h3 className="mb-3 font-display font-bold text-ink">Impact summary</h3>
            <div className="grid grid-cols-3 gap-3 text-center">
              <div className="rounded-2xl bg-brand-50 p-3">
                <p className="font-display text-2xl font-extrabold text-brand">{posts.length}</p>
                <p className="text-xs text-muted">Posts</p>
              </div>
              <div className="rounded-2xl bg-accent-50 p-3">
                <p className="font-display text-2xl font-extrabold text-accent-700">{totalLikes}</p>
                <p className="text-xs text-muted">Likes</p>
              </div>
              <div className="rounded-2xl bg-canvas p-3">
                <p className="font-display text-2xl font-extrabold text-ink">{totalImpact.toLocaleString()}</p>
                <p className="text-xs text-muted">Impact value</p>
              </div>
            </div>
          </section>
        )}
      </div>
    </div>
  );
}
