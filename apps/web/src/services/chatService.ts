// chatService — mock messenger backend with live updates via the realtime bus.
// Swap the in-memory store for `apiClient` calls once a real chat service exists.

import { realtime, TOPICS } from "./realtime";
import type { ChatThread, ChatMessage, PostAuthor } from "../types/social";

const LS_KEY = "masaren_threads_v1";

function uid(prefix = "m"): string {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 6)}`;
}

function ago(min: number): string {
  return new Date(Date.now() - min * 60_000).toISOString();
}

const PEERS: PostAuthor[] = [
  { id: "u_amira", name: "Amira Saleh", handle: "amira", verified: true, role: "Organization" },
  { id: "u_yusuf", name: "Yusuf Rahman", handle: "yusuf", role: "Individual" },
  { id: "u_lina", name: "Lina Haddad", handle: "lina", verified: true, role: "Specialist" },
];

function seed(): ChatThread[] {
  return [
    {
      id: "t1",
      peer: PEERS[0],
      unread: 2,
      lastActive: ago(3),
      messages: [
        { id: uid(), threadId: "t1", authorId: "u_amira", text: "Hi! Loved the coastal restoration update 🌱", createdAt: ago(12) },
        { id: uid(), threadId: "t1", authorId: "me", text: "Thank you! 340 volunteers showed up.", createdAt: ago(9) },
        { id: uid(), threadId: "t1", authorId: "u_amira", text: "Can we feature it in the newsletter?", createdAt: ago(3) },
      ],
    },
    {
      id: "t2",
      peer: PEERS[2],
      unread: 0,
      lastActive: ago(80),
      messages: [
        { id: uid(), threadId: "t2", authorId: "u_lina", text: "Audit trail for Aswan is ready.", createdAt: ago(85) },
        { id: uid(), threadId: "t2", authorId: "me", text: "Awesome, reviewing now.", createdAt: ago(80) },
      ],
    },
    {
      id: "t3",
      peer: PEERS[1],
      unread: 0,
      lastActive: ago(200),
      messages: [{ id: uid(), threadId: "t3", authorId: "u_yusuf", text: "See you at the coding club Saturday?", createdAt: ago(200) }],
    },
  ];
}

function load(): ChatThread[] {
  try {
    const raw = localStorage.getItem(LS_KEY);
    if (raw) return JSON.parse(raw) as ChatThread[];
  } catch {}
  const s = seed();
  try { localStorage.setItem(LS_KEY, JSON.stringify(s)); } catch {}
  return s;
}

let threads: ChatThread[] = load();

function persist() {
  try { localStorage.setItem(LS_KEY, JSON.stringify(threads)); } catch {}
}

export const chatService = {
  list(): ChatThread[] {
    return [...threads].sort((a, b) => b.lastActive.localeCompare(a.lastActive));
  },

  send(threadId: string, text: string): ChatMessage | undefined {
    const t = threads.find((x) => x.id === threadId);
    if (!t) return;
    const msg: ChatMessage = {
      id: uid(),
      threadId,
      authorId: "me",
      text,
      createdAt: new Date().toISOString(),
      seen: false,
    };
    t.messages = [...t.messages, msg];
    t.lastActive = msg.createdAt;
    persist();
    realtime.publish(TOPICS.MESSAGE_NEW, msg);
    return msg;
  },

  receive(threadId: string, peerId: string, text: string): ChatMessage | undefined {
    const t = threads.find((x) => x.id === threadId);
    if (!t) return;
    const msg: ChatMessage = {
      id: uid(),
      threadId,
      authorId: peerId,
      text,
      createdAt: new Date().toISOString(),
      seen: false,
    };
    t.messages = [...t.messages, msg];
    t.lastActive = msg.createdAt;
    t.unread += 1;
    persist();
    realtime.publish(TOPICS.MESSAGE_NEW, msg);
    return msg;
  },

  markSeen(threadId: string) {
    const t = threads.find((x) => x.id === threadId);
    if (!t) return;
    t.unread = 0;
    t.messages = t.messages.map((m) => ({ ...m, seen: true }));
    persist();
  },

  subscribe(handler: () => void): () => void {
    return realtime.subscribe(TOPICS.MESSAGE_NEW, handler);
  },
};
