import React, { useEffect, useState } from "react";
import { chatService } from "../services/api";

interface Conversation {
  id: string;
  title: string;
  updated_at: string;
}

interface ChatMessage {
  id: string;
  role: "user" | "assistant" | "system";
  content: string;
  created_at: string;
}

export default function ChatPage() {
  const userId = localStorage.getItem("user_id") || "demo-user";
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);

  const loadConversations = async () => {
    try {
      const res: any = await chatService.listConversations(userId);
      setConversations(Array.isArray(res?.data) ? res.data : []);
    } catch (e) {
      console.error("Error loading conversations", e);
    }
  };

  useEffect(() => {
    loadConversations();
  }, []);

  const loadMessages = async (id: string) => {
    try {
      const res: any = await chatService.getMessages(id);
      setMessages(Array.isArray(res?.data) ? res.data : []);
    } catch (e) {
      console.error("Error loading messages", e);
    }
  };

  const handleSelect = (id: string) => {
    setActiveId(id);
    loadMessages(id);
  };

  const handleNew = async () => {
    try {
      const res: any = await chatService.createConversation(userId, "New conversation");
      const id = res?.data?.id;
      await loadConversations();
      if (id) handleSelect(id);
    } catch (e) {
      alert("Could not start a conversation");
    }
  };

  const handleSend = async () => {
    if (!activeId || !draft.trim()) return;
    setBusy(true);
    const text = draft.trim();
    setDraft("");
    setMessages((m) => [...m, { id: "tmp", role: "user", content: text, created_at: "" }]);
    try {
      const res: any = await chatService.sendMessage(activeId, userId, text);
      const reply = res?.data?.assistant_reply;
      setMessages((m) => [
        ...m,
        { id: "tmp-2", role: "assistant", content: reply || "(no reply)", created_at: "" },
      ]);
    } catch (e) {
      setMessages((m) => [
        ...m,
        { id: "tmp-err", role: "assistant", content: "Error contacting chat service.", created_at: "" },
      ]);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex h-[80vh] gap-4">
      <aside className="hidden w-64 shrink-0 card overflow-auto p-3 sm:block">
        <button onClick={handleNew} className="btn-gold mb-3 w-full">
          + New chat
        </button>
        {conversations.map((c) => (
          <button
            key={c.id}
            onClick={() => handleSelect(c.id)}
            className={`nav-link mb-1 w-full text-start ${activeId === c.id ? "nav-link-active" : ""}`}
          >
            <span className="truncate font-medium">{c.title}</span>
          </button>
        ))}
        {conversations.length === 0 && (
          <p className="px-3 py-2 text-sm text-muted">No conversations yet.</p>
        )}
      </aside>

      <section className="card flex flex-1 flex-col p-4">
        {!activeId ? (
          <p className="m-auto text-muted">Select or start a conversation.</p>
        ) : (
          <>
            <div className="mb-4 flex-1 space-y-3 overflow-auto">
              {messages.map((m) => (
                <div key={m.id} className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}>
                  <div
                    className={`max-w-[70%] rounded-2xl px-4 py-2 ${
                      m.role === "user" ? "bg-brand text-white" : "bg-canvas text-ink"
                    }`}
                  >
                    {m.content}
                  </div>
                </div>
              ))}
            </div>
            <div className="flex gap-2">
              <input
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleSend()}
                placeholder="Type a message…"
                className="glass-input"
              />
              <button onClick={handleSend} disabled={busy} className="btn-gold">
                {busy ? "…" : "Send"}
              </button>
            </div>
          </>
        )}
      </section>
    </div>
  );
}
