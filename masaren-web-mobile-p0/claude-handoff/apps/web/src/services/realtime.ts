// Realtime layer: an in-app event bus (works with zero backend) plus an
// optional WebSocket connection. UI components publish/subscribe to topics so
// the feed, messenger and notifications update live — NO manual refresh.
//
// Wire `VITE_WS_URL` (or set window.__MASAREN_WS__) to a broadcast WS server to
// get cross-tab / cross-user live updates. The bundled `ws-server.mjs` does this.

type Handler = (payload: any) => void;

class RealtimeBus {
  private target: EventTarget;
  private socket: WebSocket | null = null;
  private url: string | null = null;
  private reconnectTimer: any = null;

  constructor() {
    this.target = new EventTarget();
    this.url =
      (import.meta as any).env?.VITE_WS_URL ||
      (typeof window !== "undefined" ? (window as any).__MASAREN_WS__ : null) ||
      null;
    if (this.url) this.connect();
  }

  private connect() {
    if (!this.url) return;
    try {
      this.socket = new WebSocket(this.url);
      this.socket.addEventListener("message", (ev) => {
        try {
          const { topic, payload } = JSON.parse((ev as MessageEvent).data);
          if (topic) this.localEmit(topic, payload);
        } catch {}
      });
      this.socket.addEventListener("close", () => {
        this.reconnectTimer = setTimeout(() => this.connect(), 2500);
      });
    } catch {
      this.socket = null;
    }
  }

  private localEmit(topic: string, payload: any) {
    this.target.dispatchEvent(new CustomEvent(topic, { detail: payload }));
  }

  publish(topic: string, payload: any) {
    // Local subscribers always fire immediately.
    this.localEmit(topic, payload);
    // If a WS is live, fan out to everyone else.
    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      try {
        this.socket.send(JSON.stringify({ topic, payload }));
      } catch {}
    }
  }

  subscribe(topic: string, handler: Handler) {
    const listener = (e: Event) => handler((e as CustomEvent).detail);
    this.target.addEventListener(topic, listener as EventListener);
    return () => this.target.removeEventListener(topic, listener as EventListener);
  }
}

export const realtime = new RealtimeBus();

// Topic helpers
export const TOPICS = {
  POST_NEW: "post:new",
  POST_REACT: "post:react",
  POST_COMMENT: "post:comment",
  MESSAGE_NEW: "message:new",
  NOTIFICATION: "notification:new",
  PROFILE_UPDATE: "profile:update",
} as const;
