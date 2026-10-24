import { useEffect, useState } from "react";
import { postService } from "../services/postService";
import type { Post } from "../types/social";
import Composer from "../components/social/Composer";
import PostCard from "../components/social/PostCard";
import { useI18n } from "../i18n";

type Filter = "all" | "impact" | "program" | "evidence" | "saved";

const FILTERS: { key: Filter; labelKey: string }[] = [
  { key: "all", labelKey: "feed.forYou" },
  { key: "impact", labelKey: "feed.impact" },
  { key: "program", labelKey: "feed.programs" },
  { key: "evidence", labelKey: "feed.evidence" },
  { key: "saved", labelKey: "feed.saved" },
];

export default function FeedPage() {
  const { t } = useI18n();
  const [posts, setPosts] = useState<Post[] | null>(null);
  const [filter, setFilter] = useState<Filter>("all");

  function refresh() {
    if (filter === "saved") {
      setPosts(postService.saved());
      return;
    }
    setPosts(postService.list(filter === "all" ? undefined : { kind: filter as any }));
  }

  useEffect(() => {
    setPosts(null);
    const id = setTimeout(refresh, 0);
    const off = postService.subscribe(refresh);
    return () => { clearTimeout(id); off(); };
  }, [filter]);

  return (
    <div className="mx-auto flex w-full max-w-3xl flex-col gap-5">
      {/* Header */}
      <div className="flex items-center justify-between animate-fade-up">
        <h1 className="text-display-sm text-ink">{t("feed.title")}</h1>
        <span className="chip-brand">{t("feed.verified")}</span>
      </div>

      {/* Composer */}
      <div className="animate-fade-up" style={{ animationDelay: "50ms" }}>
        <Composer onPosted={refresh} />
      </div>

      {/* Filter bar, Google-style tab bar */}
      <div className="sticky top-16 z-10 animate-fade-up" style={{ animationDelay: "100ms" }}>
        <div className="tab-bar">
          {FILTERS.map((f) => (
            <button
              key={f.key}
              onClick={() => setFilter(f.key)}
              className={`tab-item ${filter === f.key ? "tab-item-active" : ""}`}
            >
              {t(f.labelKey)}
            </button>
          ))}
        </div>
      </div>

      {/* Feed */}
      {posts === null ? (
        <div className="flex flex-col gap-4" aria-busy="true" aria-live="polite">
          <span className="sr-only">{t("feed.loading")}</span>
          {[0, 1, 2].map((i) => (
            <PostSkeleton key={i} index={i} />
          ))}
        </div>
      ) : posts.length === 0 ? (
        <div className="py-16 text-center">
          <div className="mx-auto mb-4 grid h-16 w-16 place-items-center rounded-full bg-navy-100">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" className="text-muted/50">
              <path d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
            </svg>
          </div>
          <p className="text-sm font-medium text-muted">
            {filter === "saved" ? t("feed.emptySaved") : t("feed.empty")}
          </p>
          <p className="mt-1 text-xs text-muted/60">Be the first to post something amazing.</p>
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {posts.map((p, i) => (
            <div key={p.id} className="animate-fade-up" style={{ animationDelay: `${Math.min(i * 50, 200)}ms` }}>
              <PostCard post={p} onChanged={refresh} />
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function PostSkeleton({ index }: { index: number }) {
  return (
    <div
      className="rounded-xl bg-white border border-line/50 p-5 animate-fade-up"
      style={{ animationDelay: `${index * 80}ms` }}
    >
      <div className="flex items-center gap-3">
        <div className="h-10 w-10 rounded-full skeleton" />
        <div className="flex-1 space-y-2">
          <div className="h-3 w-1/3 rounded skeleton" />
          <div className="h-2.5 w-1/4 rounded skeleton" />
        </div>
      </div>
      <div className="mt-4 space-y-2">
        <div className="h-3 w-full rounded skeleton" />
        <div className="h-3 w-11/12 rounded skeleton" />
        <div className="h-3 w-2/3 rounded skeleton" />
      </div>
      <div className="mt-4 h-32 w-full rounded-lg skeleton" />
    </div>
  );
}
