import { useEffect, useState } from "react";
import { postService } from "../services/postService";
import type { Post } from "../types/social";
import Composer from "../components/social/Composer";
import PostCard from "../components/social/PostCard";
import { useI18n } from "../i18n";

type Filter = "all" | "impact" | "program" | "evidence";

const FILTERS: { key: Filter; label: string }[] = [
  { key: "all", label: "For You" },
  { key: "impact", label: "Impact" },
  { key: "program", label: "Programs" },
  { key: "evidence", label: "Evidence" },
];

export default function FeedPage() {
  const { t } = useI18n();
  const [posts, setPosts] = useState<Post[]>([]);
  const [filter, setFilter] = useState<Filter>("all");

  function refresh() {
    setPosts(postService.list(filter === "all" ? undefined : { kind: filter as any }));
  }

  useEffect(() => {
    refresh();
    const off = postService.subscribe(refresh);
    return off;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter]);

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-4">
      <div className="flex items-center justify-between">
        <h1 className="font-display text-xl font-extrabold text-ink">{t("feed.title")}</h1>
        <span className="chip-brand">POAI · Verified</span>
      </div>

      <Composer onPosted={refresh} />

      <div className="sticky top-[112px] z-10 -mx-1 flex gap-1 rounded-2xl bg-white/80 px-1 py-1 backdrop-blur">
        {FILTERS.map((f) => (
          <button
            key={f.key}
            onClick={() => setFilter(f.key)}
            className={`flex-1 rounded-xl px-3 py-2 text-sm font-semibold transition ${
              filter === f.key ? "bg-brand text-white" : "text-muted hover:bg-canvas"
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      {posts.length === 0 ? (
        <p className="py-10 text-center text-sm text-muted">{t("feed.empty")}</p>
      ) : (
        <div className="flex flex-col gap-4">
          {posts.map((p) => (
            <PostCard key={p.id} post={p} onChanged={refresh} />
          ))}
        </div>
      )}
    </div>
  );
}
