import { describe, it, expect, beforeEach, vi } from "vitest";

// Shared, mutable mock so individual tests can script the social-service response
// without re-importing the module (which would create a second module graph and
// break the in-memory `saved`/`store` singletons). `post` resolves with a
// server-assigned id; `get` rejects so the demo store stays offline.
const postImpl = vi.fn().mockResolvedValue({ data: { id: "server_default" } });
const getImpl = vi.fn().mockRejectedValue(new Error("offline test"));

vi.mock("../services/api", () => ({
  apiClient: {
    post: (...args: any[]) => postImpl(...args),
    get: (...args: any[]) => getImpl(...args),
  },
}));

import { postService } from "../services/postService";
import type { PostAuthor } from "../types/social";

const author: PostAuthor = {
  id: "u_test",
  name: "Test User",
  handle: "testuser",
  verified: false,
  role: "Individual",
};

beforeEach(() => {
  (localStorage as any).clear();
  postImpl.mockResolvedValue({ data: { id: "server_default" } });
});

describe("postService — bookmarks (saved)", () => {
  it("starts with no saved posts", () => {
    const list = postService.list();
    expect(list.length).toBeGreaterThan(0);
    expect(postService.saved()).toHaveLength(0);
    for (const p of list) expect(postService.isSaved(p.id)).toBe(false);
  });

  it("toggleSave flips and persists saved state", () => {
    const post = postService.list()[0];
    expect(postService.isSaved(post.id)).toBe(false);

    const nowSaved = postService.toggleSave(post.id);
    expect(nowSaved).toBe(true);
    expect(postService.isSaved(post.id)).toBe(true);
    expect(postService.saved().map((p) => p.id)).toContain(post.id);

    const nowUnsaved = postService.toggleSave(post.id);
    expect(nowUnsaved).toBe(false);
    expect(postService.isSaved(post.id)).toBe(false);
    expect(postService.saved().map((p) => p.id)).not.toContain(post.id);
  });

  it("persists saved posts across reloads", () => {
    const post = postService.list()[0];
    postService.toggleSave(post.id);

    // Simulate a fresh module load by reading the persisted key directly.
    const raw = (localStorage as any).getItem("masaren_bookmarks_v1");
    expect(raw).toContain(post.id);
  });
});

describe("postService — trending", () => {
  it("derives tags from post text hashtags and programTags", () => {
    // Add a post with a known hashtag so the result is deterministic.
    postService.create({
      author,
      text: "Launching #GreenSchools across the delta this spring.",
      kind: "impact",
      programTag: "Green Schools",
    });
    const trends = postService.trending();
    const tags = trends.map((t) => t.tag);
    expect(tags).toContain("#greenschools");
    expect(tags).toContain("#greenschools"); // programTag de-dupes to same tag
    // results are sorted by count descending
    for (let i = 1; i < trends.length; i++) {
      expect(trends[i - 1].count).toBeGreaterThanOrEqual(trends[i].count);
    }
  });

  it("returns at most 8 trends", () => {
    expect(postService.trending().length).toBeLessThanOrEqual(8);
  });
});

describe("postService — core feed", () => {
  it("lists posts sorted by rank (highest first)", () => {
    const list = postService.list();
    expect(list.length).toBeGreaterThan(1);
    // engagement of first should be >= engagement of last (rank sort)
    const score = (p: any) =>
      (p.likes ?? 0) + (p.comments?.length ?? 0) * 3 + (p.shares ?? 0) * 2;
    expect(score(list[0])).toBeGreaterThanOrEqual(score(list[list.length - 1]));
  });

  it("filters by kind", () => {
    const impacts = postService.list({ kind: "impact" });
    expect(impacts.length).toBeGreaterThan(0);
    expect(impacts.every((p) => p.kind === "impact")).toBe(true);
  });

  it("creates a post and prepends it to the feed", () => {
    const before = postService.list().length;
    const created = postService.create({ author, text: "Hello impact world", kind: "story" });
    const after = postService.list();
    expect(after.length).toBe(before + 1);
    expect(after.map((p) => p.id)).toContain(created.id);
  });

  it("reconciles client id with server id after backend create (finding D)", async () => {
    // The social-service returns a server-assigned id for the post created
    // locally with a `p_…` id. The local record must adopt the server id so
    // subsequent likes/saves target the real record (no 404 from the backend).
    const serverId = "server_" + Math.random().toString(36).slice(2);
    postImpl.mockResolvedValueOnce({ data: { id: serverId } });

    const created = postService.create({ author, text: "Reconciled post", kind: "story" });
    const localId = created.id; // capture before the async reconciliation swaps it
    expect(localId.startsWith("p_")).toBe(true);

    // Allow the fire-and-forget .then() reconciliation to run.
    await new Promise((r) => setTimeout(r, 0));

    const ids = postService.list().map((p) => p.id);
    expect(ids).toContain(serverId);
    expect(ids).not.toContain(localId);
  });

  it("migrates a saved bookmark to the reconciled server id (finding D)", async () => {
    const serverId = "server_" + Math.random().toString(36).slice(2);
    postImpl.mockResolvedValueOnce({ data: { id: serverId } });

    const created = postService.create({ author, text: "Saved then reconciled", kind: "story" });
    const localId = created.id;
    postService.toggleSave(localId);
    expect(postService.isSaved(localId)).toBe(true);

    await new Promise((r) => setTimeout(r, 0));

    expect(postService.isSaved(serverId)).toBe(true);
    expect(postService.isSaved(localId)).toBe(false);
  });

  it("toggles likes on a post", () => {
    const post = postService.create({ author, text: "Like me", kind: "story" });
    const before = post.likes;
    const updated = postService.toggleLike(post.id);
    expect(updated?.likes).toBe(before + 1);
    expect(updated?.likedByMe).toBe(true);
    const reverted = postService.toggleLike(post.id);
    expect(reverted?.likes).toBe(before);
    expect(reverted?.likedByMe).toBe(false);
  });
});
