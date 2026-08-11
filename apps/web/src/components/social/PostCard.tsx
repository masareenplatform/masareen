import { useState, useRef, useEffect, useCallback } from "react";
import { Link } from "react-router-dom";
import Hls from "hls.js";
import type { Post } from "../../types/social";
import { postService, avatarColors } from "../../services/postService";
import { userService } from "../../services/api";
import { useAuth } from "../../store/authStore";
import { useI18n } from "../../i18n";
import {
  IconHeart, IconComment, IconShare, IconCheck, IconEvidence, IconImpact, IconBookmark,
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
  announcement: { label: "Platform", cls: "chip-gold" },
  synergy: { label: "Synergy", cls: "chip-accent" },
  opportunity: { label: "Opportunity", cls: "chip-gold" },
  recognition: { label: "Recognition", cls: "chip-recognition" },
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

function RippleButton({ children, className, onClick, ...props }: any) {
  const ref = useRef<HTMLButtonElement>(null);

  function handleClick(e: React.MouseEvent) {
    const el = ref.current;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    const ripple = document.createElement("span");
    const size = Math.max(rect.width, rect.height);
    ripple.style.width = ripple.style.height = `${size}px`;
    ripple.style.left = `${e.clientX - rect.left - size / 2}px`;
    ripple.style.top = `${e.clientY - rect.top - size / 2}px`;
    ripple.className = "ripple";
    el.appendChild(ripple);
    setTimeout(() => ripple.remove(), 600);
    onClick?.(e);
  }

  return (
    <button ref={ref} className={`ripple-container ${className}`} onClick={handleClick} {...props}>
      {children}
    </button>
  );
}

export default function PostCard({ post, onChanged }: { post: Post; onChanged?: () => void }) {
  const { user } = useAuth();
  const { t } = useI18n();
  const [showComments, setShowComments] = useState(false);
  const [draft, setDraft] = useState("");
  const [saved, setSaved] = useState(() => postService.isSaved(post.id));
  const [following, setFollowing] = useState(false);
  const [followPending, setFollowPending] = useState(false);
  const [likeAnimating, setLikeAnimating] = useState(false);

  const me: Post["author"] = {
    id: user?.id ?? "me",
    name: user?.full_name ?? "Guest",
    handle: (user?.email ?? "guest").split("@")[0],
  };

  const isMe = post.author.id === (user?.id ?? "me");

  function toggleSave() { setSaved(postService.toggleSave(post.id)); }

  async function followAuthor() {
    if (isMe) return;
    setFollowPending(true);
    try { await userService.follow(post.author.id); setFollowing(true); } catch { /* */ } finally {
      setFollowPending(false);
    }
  }

  const badge = KIND_BADGE[post.kind] ?? { label: post.kind ?? "Post", cls: "chip-brand" };

  function like() {
    setLikeAnimating(true);
    postService.toggleLike(post.id);
    onChanged?.();
    setTimeout(() => setLikeAnimating(false), 400);
  }
  function comment() {
    if (!draft.trim()) return;
    postService.addComment(post.id, me, draft.trim());
    setDraft("");
    setShowComments(true);
    onChanged?.();
  }
  function share() { postService.share(post.id); onChanged?.(); }

  const accentCls =
    post.kind === "recognition" ? "ring-1 ring-accent/30" :
    post.kind === "announcement" || post.kind === "opportunity" || post.kind === "synergy"
    ? "ring-1 ring-amber-300/40" : "";

  const confidence = (post as any).confidence_score;
  const confidenceLabel = confidence != null
    ? confidence >= 0.8 ? "Verified" : confidence >= 0.5 ? "Partial" : "Unverified"
    : null;
  const confidenceCls = confidence != null
    ? confidence >= 0.8 ? "bg-emerald-50 text-emerald-600" :
      confidence >= 0.5 ? "bg-amber-50 text-amber-600" :
      "bg-navy-100 text-muted"
    : "";

  return (
    <article className={`post-card rounded-xl bg-white border border-line/50 p-5 ${accentCls}`}>
      {/* Header */}
      <div className="flex items-start gap-3">
        <Link to={`/personnel/${post.author.id}`} className="shrink-0 transition-transform duration-200 hover:scale-105">
          <Avatar name={post.author.name} handle={post.author.handle} />
        </Link>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-1.5">
            <Link to={`/personnel/${post.author.id}`} className="group">
              <p className="text-sm font-semibold text-ink group-hover:text-brand transition-colors duration-150">
                {post.author.name}
              </p>
            </Link>
            {post.author.verified && (
              <span className="grid h-4 w-4 place-items-center rounded-full bg-brand">
                <IconCheck size={10} className="text-white" />
              </span>
            )}
          </div>
          <p className="text-xs text-muted">
            @{post.author.handle} · {timeAgo(post.createdAt)}
          </p>
        </div>
        {!isMe && (
          <button
            className={`btn text-xs px-3 py-1.5 ${following ? "btn-soft" : "btn-primary"}`}
            onClick={followAuthor}
            disabled={followPending}
          >
            {following ? t("action.following") : t("action.follow")}
          </button>
        )}
        <span className={`shrink-0 ${badge.cls}`}>{badge.label}</span>
        {confidenceLabel && (
          <span className={`shrink-0 text-[10px] font-medium px-2 py-0.5 rounded-full ${confidenceCls}`}>
            {confidenceLabel}
          </span>
        )}
      </div>

      {/* Content */}
      {post.text && (
        <p className="mt-3.5 whitespace-pre-wrap text-[15px] leading-relaxed text-ink">{post.text}</p>
      )}

      {/* Media */}
      {post.media && post.media.length > 0 && (
        <div className={`mt-3.5 grid gap-2 overflow-hidden rounded-xl ${post.media.length > 1 ? "grid-cols-2" : "grid-cols-1"}`}>
          {post.media.map((m, i) => (
            <div key={i} className="relative overflow-hidden bg-navy-50 group">
              {m.type === "image" ? (
                m.url ? (
                  <img src={m.url} alt={m.name} className="max-h-[420px] w-full object-cover transition-transform duration-300 group-hover:scale-[1.02]" />
                ) : (
                  <div className="flex h-40 items-center justify-center gap-2 text-muted">
                    <IconEvidence size={18} /> {m.name ?? "Evidence"}
                  </div>
                )
              ) : (
                m.url ? (
                  <HlsVideo src={m.url} className="max-h-[420px] w-full object-cover" />
                ) : (
                  <div className="flex h-40 items-center justify-center text-muted">Video</div>
                )
              )}
            </div>
          ))}
        </div>
      )}

      {/* Impact / Tags */}
      {(post.impactValue !== undefined || post.programTag) && (
        <div className="mt-3.5 flex flex-wrap items-center gap-2">
          {post.impactValue !== undefined && (
            <span className="inline-flex items-center gap-1.5 rounded-lg bg-accent-50 px-3 py-1.5 text-sm font-semibold text-accent">
              <IconImpact size={15} /> {post.impactValue.toLocaleString()} {post.impactLabel ?? "impact"}
            </span>
          )}
          {post.programTag && <span className="chip">📌 {post.programTag}</span>}
          {post.sdg && <span className="chip-brand">SDG {post.sdg}</span>}
        </div>
      )}

      {/* Actions */}
      <div className="mt-3.5 flex items-center gap-1 border-t border-line/50 pt-2.5 text-sm text-muted">
        <RippleButton
          className={`btn-ghost flex-1 ${post.likedByMe ? "text-like" : ""}`}
          onClick={like}
        >
          <IconHeart
            size={18}
            className={`transition-all duration-200 ${post.likedByMe ? "fill-like text-like" : ""} ${likeAnimating ? "scale-125" : ""}`}
          />
          <span className="transition-colors duration-150">{post.likes > 0 ? post.likes : t("action.like")}</span>
        </RippleButton>
        <button className="btn-ghost flex-1" onClick={() => setShowComments((s) => !s)}>
          <IconComment size={18} />
          <span>{post.comments.length > 0 ? post.comments.length : t("action.comment")}</span>
        </button>
        <button className="btn-ghost flex-1" onClick={share}>
          <IconShare size={18} />
          <span>{post.shares > 0 ? post.shares : t("action.share")}</span>
        </button>
        <button
          className={`icon-btn px-3 ${saved ? "text-brand" : ""}`}
          onClick={toggleSave}
          title={t("action.save")}
          aria-label={t("action.save")}
        >
          <IconBookmark size={18} className={saved ? "fill-current text-brand" : ""} />
        </button>
      </div>

      {/* Comments */}
      {showComments && (
        <div className="mt-3 space-y-2 animate-fade-up">
          {post.comments.map((c) => (
            <div key={c.id} className="flex gap-2.5 rounded-lg bg-navy-50 p-3">
              <Avatar name={c.author.name} handle={c.author.handle} size={28} />
              <div>
                <p className="text-xs font-semibold text-ink">{c.author.name}</p>
                <p className="text-sm text-ink">{c.text}</p>
              </div>
            </div>
          ))}
          <div className="flex gap-2 pt-1">
            <input
              className="glass-input flex-1 !py-2 !px-3 !text-sm"
              placeholder={t("post.replyPlaceholder")}
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && comment()}
            />
            <button className="btn-primary px-3 !py-2 text-xs" onClick={comment}>
              {t("action.post")}
            </button>
          </div>
        </div>
      )}
    </article>
  );
}

function HlsVideo({ src, className }: { src: string; className?: string }) {
  const ref = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (src.includes(".m3u8") && Hls.isSupported()) {
      const hls = new Hls({ enableWorker: true, lowLatencyMode: true });
      hls.loadSource(src);
      hls.attachMedia(el);
      return () => { hls.destroy(); };
    } else {
      el.src = src;
    }
  }, [src]);

  return <video ref={ref} controls className={className} playsInline preload="metadata" />;
}
