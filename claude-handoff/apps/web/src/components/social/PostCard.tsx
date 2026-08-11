import { useState } from "react";
import type { Post } from "../../types/social";
import { postService, avatarColors } from "../../services/postService";
import { useAuth } from "../../store/authStore";
import {
  IconHeart, IconComment, IconShare, IconCheck, IconEvidence, IconImpact,
} from "../icons/Icons";

function Avatar({ name, handle, size = 40 }: { name: string; handle: string; size?: number }) {
  const { c1, c2 } = avatarColors(handle || name);
  return (
    <span
      className="avatar-gradient grid shrink-0 place-items-center rounded-full font-semibold text-white"
      style={{ width: size, height: size, fontSize: size * 0.4, ["--c1" as any]: c1, ["--c2" as any]: c2 }}
    >
      {(name?.[0] ?? "?").toUpperCase()}
    </span>
  );
}

const KIND_BADGE: Record<string, { label: string; cls: string }> = {
  story: { label: "Story", cls: "chip-brand" },
  program: { label: "Program", cls: "chip-accent" },
  task: { label: "Task", cls: "chip-brand" },
  evidence: { label: "Evidence", cls: "chip-accent" },
  impact: { label: "Impact", cls: "chip-brand" },
};

function timeAgo(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1) return "now";
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h`;
  return `${Math.floor(h / 24)}d`;
}

export default function PostCard({ post, onChanged }: { post: Post; onChanged?: () => void }) {
  const { user } = useAuth();
  const [showComments, setShowComments] = useState(false);
  const [draft, setDraft] = useState("");

  const me: Post["author"] = {
    id: user?.id ?? "me",
    name: user?.full_name ?? "Guest",
    handle: (user?.email ?? "guest").split("@")[0],
  };

  const badge = KIND_BADGE[post.kind];

  function like() {
    postService.toggleLike(post.id);
    onChanged?.();
  }
  function comment() {
    if (!draft.trim()) return;
    postService.addComment(post.id, me, draft.trim());
    setDraft("");
    setShowComments(true);
    onChanged?.();
  }
  function share() {
    postService.share(post.id);
    onChanged?.();
  }

  return (
    <article className="card animate-fade-up p-4">
      <div className="flex items-center gap-3">
        <Avatar name={post.author.name} handle={post.author.handle} />
        <div className="min-w-0">
          <p className="flex items-center gap-1.5 text-sm font-semibold text-ink">
            {post.author.name}
            {post.author.verified && <IconCheck size={15} className="text-brand" />}
          </p>
          <p className="truncate text-xs text-muted">
            @{post.author.handle} · {timeAgo(post.createdAt)}
          </p>
        </div>
        <span className={`ms-auto ${badge.cls}`}>{badge.label}</span>
      </div>

      {post.text && <p className="mt-3 whitespace-pre-wrap text-[15px] leading-relaxed text-ink">{post.text}</p>}

      {post.media.length > 0 && (
        <div className={`mt-3 grid gap-2 overflow-hidden rounded-xl ${post.media.length > 1 ? "grid-cols-2" : "grid-cols-1"}`}>
          {post.media.map((m, i) => (
            <div key={i} className="relative overflow-hidden bg-canvas">
              {m.type === "image" ? (
                m.url ? <img src={m.url} alt={m.name} className="max-h-[420px] w-full object-cover" />
                      : <div className="flex h-40 items-center justify-center gap-2 text-muted"><IconEvidence size={18} /> {m.name ?? "Evidence"}</div>
              ) : (
                m.url ? <video src={m.url} controls className="max-h-[420px] w-full object-cover" />
                      : <div className="flex h-40 items-center justify-center text-muted">Video</div>
              )}
            </div>
          ))}
        </div>
      )}

      {(post.impactValue !== undefined || post.programTag) && (
        <div className="mt-3 flex flex-wrap items-center gap-2">
          {post.impactValue !== undefined && (
            <span className="inline-flex items-center gap-1.5 rounded-xl bg-accent-50 px-3 py-1.5 text-sm font-bold text-accent-700">
              <IconImpact size={16} /> {post.impactValue.toLocaleString()} {post.impactLabel ?? "impact"}
            </span>
          )}
          {post.programTag && <span className="chip">📌 {post.programTag}</span>}
          {post.sdg && <span className="chip-brand">SDG {post.sdg}</span>}
        </div>
      )}

      <div className="mt-3 flex items-center gap-1 border-t border-line pt-2 text-sm text-muted">
        <button className={`btn-ghost flex-1 ${post.likedByMe ? "text-rose-500" : ""}`} onClick={like}>
          <IconHeart size={18} className={post.likedByMe ? "fill-rose-500 text-rose-500" : ""} />
          {post.likes > 0 ? post.likes : "Like"}
        </button>
        <button className="btn-ghost flex-1" onClick={() => setShowComments((s) => !s)}>
          <IconComment size={18} /> {post.comments.length > 0 ? post.comments.length : "Comment"}
        </button>
        <button className="btn-ghost flex-1" onClick={share}>
          <IconShare size={18} /> {post.shares > 0 ? post.shares : "Share"}
        </button>
      </div>

      {showComments && (
        <div className="mt-3 border-t border-line pt-3">
          <div className="flex gap-2">
            <input
              className="glass-input"
              placeholder="Write a comment…"
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && comment()}
            />
            <button className="btn-soft px-3" onClick={comment}>Send</button>
          </div>
          <ul className="mt-3 flex flex-col gap-3">
            {post.comments.map((c) => (
              <li key={c.id} className="flex gap-2">
                <Avatar name={c.author.name} handle={c.author.handle} size={30} />
                <div className="rounded-2xl bg-canvas px-3 py-2">
                  <p className="text-xs font-semibold text-ink">{c.author.name}</p>
                  <p className="text-sm text-ink">{c.text}</p>
                </div>
              </li>
            ))}
            {post.comments.length === 0 && <li className="text-xs text-muted">No comments yet.</li>}
          </ul>
        </div>
      )}
    </article>
  );
}
