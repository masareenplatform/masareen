import { useEffect, useRef, useState } from "react";
import { useAuth } from "../store/authStore";
import { apiClient } from "../services/api";
import { postService, avatarColors } from "../services/postService";
import type { Post } from "../types/social";
import PostCard from "../components/social/PostCard";
import { useI18n } from "../i18n";
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
  "linear-gradient(135deg, #4285f4, #34a853)",
  "linear-gradient(135deg, #1a73e8, #1e8e3e)",
  "linear-gradient(135deg, #4285f4, #0d904f)",
  "linear-gradient(135deg, #1967d2, #188038)",
];

export default function ProfilePage() {
  const { user } = useAuth();
  const { t } = useI18n();
  const name = user?.full_name ?? "Guest";
  const handle = (user?.email ?? "guest").split("@")[0];
  const role = user?.role ?? "Individual";

  const [cover, setCover] = useState<string | null>(null);
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null);
  const [tab, setTab] = useState<Tab>("posts");
  const [posts, setPosts] = useState<Post[]>([]);
  const [editing, setEditing] = useState(false);
  const [editName, setEditName] = useState(name);
  const [editBio, setEditBio] = useState((user as any)?.bio ?? "");
  const [saving, setSaving] = useState(false);
  const avatarInput = useRef<HTMLInputElement | null>(null);
  const coverInput = useRef<HTMLInputElement | null>(null);

  function refresh() {
    setPosts(postService.list({ authorId: user?.id ?? "me" }));
  }
  useEffect(() => {
    refresh();
    const off = postService.subscribe(refresh);
    return off;
  }, [user?.id]);

  const totalLikes = posts.reduce((n, p) => n + p.likes, 0);
  const totalImpact = posts.reduce((n, p) => n + (p.impactValue ?? 0), 0);

  async function saveProfile() {
    setSaving(true);
    try { await apiClient.patch("/users/me/profile", { full_name: editName, bio: editBio }); setEditing(false); } catch { /* */ } finally {
      setSaving(false);
    }
  }

  async function uploadAvatar(file: File) {
    const fd = new FormData();
    fd.append("file", file);
    try {
      const r = await apiClient.post("/users/me/avatar", fd, { headers: { "Content-Type": "multipart/form-data" } });
      const url = r.data?.url ?? r.data?.data?.url;
      if (url) setAvatarUrl(url);
    } catch { /* */ }
  }

  return (
    <div className="mx-auto max-w-2xl animate-fade-up">
      <section className="rounded-xl bg-white border border-line/50 overflow-hidden">
        {/* Cover */}
        <div
          className="relative h-40 w-full sm:h-56 transition-all duration-500"
          style={{ background: cover ?? COVER_PRESETS[0] }}
        >
          <div className="absolute inset-0 bg-gradient-to-b from-transparent to-black/10" />
          <button
            className="absolute bottom-3 end-3 inline-flex items-center gap-1.5 rounded-full bg-black/30 px-3 py-1.5 text-xs font-medium text-white backdrop-blur-md hover:bg-black/50 transition-all duration-200"
            onClick={() => coverInput.current?.click()}
          >
            <IconCover size={14} /> {t("profile.editCover")}
          </button>
          <input ref={coverInput} type="file" accept="image/*" hidden onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) setCover(URL.createObjectURL(f));
          }} />
        </div>

        {/* Avatar + meta */}
        <div className="px-6 pb-6">
          <div className="-mt-14 flex items-end gap-5">
            <div className="relative group">
              {avatarUrl ? (
                <img src={avatarUrl} alt={name} className="h-28 w-28 rounded-full object-cover ring-4 ring-white shadow-lg transition-transform duration-200 group-hover:scale-105" />
              ) : (
                <div className="transition-transform duration-200 group-hover:scale-105">
                  <Avatar name={name} handle={handle} size={112} />
                </div>
              )}
              <button
                className="absolute bottom-1 end-1 grid h-8 w-8 place-items-center rounded-full bg-white text-brand shadow-md opacity-0 group-hover:opacity-100 transition-all duration-200"
                onClick={() => avatarInput.current?.click()}
                title={t("profile.changePhoto")}
              >
                <IconCamera size={15} />
              </button>
              <input ref={avatarInput} type="file" accept="image/*" hidden onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) { setAvatarUrl(URL.createObjectURL(f)); uploadAvatar(f); }
              }} />
            </div>
            <div className="mb-2 flex-1">
              <h1 className="flex items-center gap-2 text-title-lg text-ink">
                {name}
                {(role === "ORGANIZATION" || role === "ADMIN") && (
                  <span className="grid h-5 w-5 place-items-center rounded-full bg-brand">
                    <IconCheck size={11} className="text-white" />
                  </span>
                )}
              </h1>
              <p className="text-sm text-muted">@{handle}</p>
            </div>
            {!editing ? (
              <button className="btn-primary mb-2 hidden sm:inline-flex" onClick={() => { setEditing(true); setEditName(name); setEditBio((user as any)?.bio ?? ""); }}>
                {t("profile.edit")}
              </button>
            ) : (
              <div className="flex gap-2 mb-2">
                <button className="btn-ghost px-3 py-1.5 text-xs" onClick={() => setEditing(false)}>Cancel</button>
                <button className="btn-primary px-3 py-1.5 text-xs" onClick={saveProfile} disabled={saving}>
                  {saving ? "Saving…" : "Save"}
                </button>
              </div>
            )}
          </div>

          {editing ? (
            <div className="mt-4 space-y-3 animate-fade-up">
              <input className="glass-input" value={editName} onChange={(e) => setEditName(e.target.value)} placeholder="Full Name" />
              <textarea className="glass-input resize-none" rows={2} value={editBio} onChange={(e) => setEditBio(e.target.value)} placeholder="Bio (optional)" />
            </div>
          ) : (
            <p className="mt-3 text-body-md text-muted">
              {((user as any)?.bio) || `Impact-driven ${role.toLowerCase()} on MASAREEN. Building verified, measurable change, one post at a time.`}
            </p>
          )}

          <div className="mt-3 flex flex-wrap gap-2">
            <span className="chip-brand">{posts.length} posts</span>
            <span className="chip-accent">{totalLikes} likes earned</span>
            {totalImpact > 0 && (
              <span className="chip inline-flex items-center gap-1"><IconImpact size={13} /> {totalImpact.toLocaleString()} impact</span>
            )}
          </div>
        </div>

        {/* Tab bar */}
        <div className="border-t border-line/50 px-6">
          <div className="flex gap-1">
            {(["posts", "about", "impact"] as Tab[]).map((tk) => (
              <button
                key={tk}
                onClick={() => setTab(tk)}
                className={`relative px-5 py-3.5 text-sm font-medium capitalize transition-colors duration-200 ${
                  tab === tk ? "text-brand" : "text-muted hover:text-ink"
                }`}
              >
                {tk}
                {tab === tk && (
                  <span className="absolute bottom-0 left-0 right-0 h-0.5 bg-brand rounded-full" />
                )}
              </button>
            ))}
          </div>
        </div>
      </section>

      <div className="mt-4">
        {tab === "posts" &&
          (posts.length === 0 ? (
            <div className="py-12 text-center">
              <div className="mx-auto mb-3 grid h-14 w-14 place-items-center rounded-full bg-navy-100">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" className="text-muted/50">
                  <path d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
                </svg>
              </div>
              <p className="text-sm font-medium text-muted">{t("profile.noPosts")}</p>
            </div>
          ) : (
            <div className="flex flex-col gap-4">
              {posts.map((p, i) => (
                <div key={p.id} className="animate-fade-up" style={{ animationDelay: `${i * 40}ms` }}>
                  <PostCard post={p} onChanged={refresh} />
                </div>
              ))}
            </div>
          ))}
        {tab === "about" && (
          <section className="rounded-xl bg-white border border-line/50 p-6 animate-fade-up">
            <h3 className="mb-3 text-title-md text-ink">About</h3>
            <div className="space-y-2.5 text-body-md">
              <div className="flex items-center justify-between py-2 border-b border-line/30">
                <span className="text-muted">Role</span>
                <span className="font-medium text-ink">{role}</span>
              </div>
              <div className="flex items-center justify-between py-2 border-b border-line/30">
                <span className="text-muted">Email</span>
                <span className="font-medium text-ink">{user?.email ?? "-"}</span>
              </div>
              {user?.pms_score != null && (
                <div className="flex items-center justify-between py-2">
                  <span className="text-muted">PMS Score</span>
                  <span className="font-medium text-brand">{user.pms_score}</span>
                </div>
              )}
            </div>
          </section>
        )}
        {tab === "impact" && (
          <section className="rounded-xl bg-white border border-line/50 p-6 animate-fade-up">
            <h3 className="mb-4 text-title-md text-ink">Impact summary</h3>
            <div className="grid grid-cols-3 gap-4 text-center">
              <div className="rounded-xl bg-brand-50 p-4 transition-transform duration-200 hover:scale-105">
                <p className="text-display-sm text-brand font-bold">{posts.length}</p>
                <p className="text-xs text-muted mt-1">Posts</p>
              </div>
              <div className="rounded-xl bg-accent-50 p-4 transition-transform duration-200 hover:scale-105">
                <p className="text-display-sm text-accent font-bold">{totalLikes}</p>
                <p className="text-xs text-muted mt-1">Likes</p>
              </div>
              <div className="rounded-xl bg-navy-50 p-4 transition-transform duration-200 hover:scale-105">
                <p className="text-display-sm text-ink font-bold">{totalImpact.toLocaleString()}</p>
                <p className="text-xs text-muted mt-1">Impact value</p>
              </div>
            </div>
          </section>
        )}
      </div>
    </div>
  );
}
