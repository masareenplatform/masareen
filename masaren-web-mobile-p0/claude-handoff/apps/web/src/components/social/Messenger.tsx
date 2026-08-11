import { useEffect, useRef, useState } from "react";
import { chatService } from "../../services/chatService";
import { avatarColors } from "../../services/postService";
import type { ChatThread } from "../../types/social";
import { IconClose, IconSend, IconMessage } from "../icons/Icons";

function Avatar({ name, handle, size = 36 }: { name: string; handle: string; size?: number }) {
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

function time(iso: string): string {
  return new Date(iso).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

export default function MessengerPopup({ onClose, meName, meHandle }: { onClose: () => void; meName: string; meHandle: string }) {
  const [threads, setThreads] = useState<ChatThread[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [draft, setDraft] = useState("");
  const scrollRef = useRef<HTMLDivElement | null>(null);

  function refresh() {
    setThreads(chatService.list());
  }

  useEffect(() => {
    refresh();
    const off = chatService.subscribe(refresh);
    return off;
  }, []);

  const active = threads.find((t) => t.id === activeId) ?? null;

  useEffect(() => {
    if (activeId) chatService.markSeen(activeId);
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeId, active?.messages.length]);

  function open(id: string) {
    setActiveId(id);
    chatService.markSeen(id);
    setThreads(chatService.list());
  }

  function send() {
    if (!draft.trim() || !active) return;
    chatService.send(active.id, draft.trim());
    setDraft("");
    setThreads(chatService.list());
  }

  const totalUnread = threads.reduce((n, t) => n + t.unread, 0);

  return (
    <div className="fixed bottom-0 start-3 z-50 w-[min(360px,92vw)]">
      <div className="flex h-[min(540px,80vh)] flex-col overflow-hidden rounded-t-2xl border border-line bg-white shadow-float">
        {/* Header */}
        <div className="flex items-center gap-2 border-b border-line bg-brand px-3 py-2.5 text-white">
          {active ? (
            <>
              <button className="text-white/90 hover:text-white" onClick={() => setActiveId(null)}>‹</button>
              <Avatar name={active.peer.name} handle={active.peer.handle} size={30} />
              <div className="min-w-0">
                <p className="truncate text-sm font-semibold">{active.peer.name}</p>
                <p className="truncate text-[11px] text-white/70">Active now</p>
              </div>
            </>
          ) : (
            <>
              <IconMessage size={18} />
              <p className="text-sm font-semibold">Chats{totalUnread > 0 ? ` · ${totalUnread} new` : ""}</p>
            </>
          )}
          <button className="ms-auto text-white/90 hover:text-white" onClick={onClose}>
            <IconClose size={18} />
          </button>
        </div>

        {/* Body */}
        {active ? (
          <>
            <div ref={scrollRef} className="flex-1 space-y-2 overflow-y-auto bg-canvas p-3">
              {active.messages.map((m) => {
                const mine = m.authorId === "me";
                return (
                  <div key={m.id} className={`flex ${mine ? "justify-end" : "justify-start"}`}>
                    <div className={`max-w-[78%] rounded-2xl px-3 py-2 text-sm ${mine ? "bg-brand text-white" : "bg-white text-ink shadow-card"}`}>
                      <p>{m.text}</p>
                      <p className={`mt-0.5 text-[10px] ${mine ? "text-white/70" : "text-muted"}`}>{time(m.createdAt)}</p>
                    </div>
                  </div>
                );
              })}
            </div>
            <div className="flex items-center gap-2 border-t border-line p-2">
              <input
                className="glass-input"
                placeholder="Message…"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && send()}
              />
              <button className="btn-gold px-3" onClick={send}><IconSend size={16} /></button>
            </div>
          </>
        ) : (
          <ul className="flex-1 overflow-y-auto p-2">
            {threads.map((t) => (
              <li key={t.id}>
                <button onClick={() => open(t.id)} className="flex w-full items-center gap-3 rounded-xl p-2 text-start hover:bg-canvas">
                  <div className="relative">
                    <Avatar name={t.peer.name} handle={t.peer.handle} size={42} />
                    {t.unread > 0 && (
                      <span className="absolute -right-0.5 -top-0.5 grid h-5 min-w-5 place-items-center rounded-full bg-accent px-1 text-[10px] font-bold text-white">
                        {t.unread}
                      </span>
                    )}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-ink">{t.peer.name}</p>
                    <p className="truncate text-xs text-muted">{t.messages[t.messages.length - 1]?.text ?? "…"}</p>
                  </div>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
