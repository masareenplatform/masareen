import { useEffect, useState, useCallback } from "react";
import { notificationService } from "../services/api";
import { useAuth } from "../store/authStore";
import { useI18n } from "../i18n";

interface Notification {
  id: string;
  title: string;
  body: string;
  channel: string;
  created_at: string;
  read: boolean;
}

function timeAgo(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

const CHANNEL_ICONS: Record<string, string> = {
  system: "⚙️",
  achievement: "🏆",
  social: "💬",
  alert: "⚠️",
  default: "🔔",
};

export default function NotificationsPage() {
  const { user } = useAuth();
  const { t } = useI18n();
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchNotifications = useCallback(async () => {
    if (!user?.id) return;
    try {
      const data = await notificationService.list(user.id);
      setNotifications(data as Notification[]);
    } catch (e) {
      console.error("Error fetching notifications", e);
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  const markAsRead = async (id: string) => {
    if (!user?.id) return;
    try {
      await notificationService.markRead(user.id, id);
      setNotifications(prev => prev.map(n => n.id === id ? { ...n, read: true } : n));
    } catch (e) {
      console.error("Error marking as read", e);
    }
  };

  const markAllRead = async () => {
    if (!user?.id) return;
    const unread = notifications.filter(n => !n.read);
    await Promise.all(unread.map(n => markAsRead(n.id)));
  };

  useEffect(() => { fetchNotifications(); }, [fetchNotifications]);

  const unreadCount = notifications.filter(n => !n.read).length;

  if (loading) return (
    <div className="mx-auto max-w-2xl p-8">
      <div className="flex items-center gap-3 text-muted">
        <div className="h-5 w-5 animate-spin rounded-full border-2 border-brand border-t-transparent" />
        Loading notifications…
      </div>
    </div>
  );

  return (
    <div className="mx-auto max-w-2xl space-y-6 animate-fade-up">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-title-lg text-ink">{t("nav.notifications")}</h1>
          {unreadCount > 0 && (
            <p className="text-sm text-muted mt-0.5">{unreadCount} unread notification{unreadCount !== 1 ? "s" : ""}</p>
          )}
        </div>
        {unreadCount > 0 && (
          <button onClick={markAllRead} className="btn-text text-sm">
            Mark all as read
          </button>
        )}
      </div>

      {/* Empty state */}
      {notifications.length === 0 ? (
        <div className="py-16 text-center">
          <div className="mx-auto mb-4 grid h-16 w-16 place-items-center rounded-full bg-navy-100">
            <span className="text-2xl">🔔</span>
          </div>
          <p className="text-title-md text-ink mb-1">All caught up</p>
          <p className="text-sm text-muted">No notifications yet. We'll let you know when something happens.</p>
        </div>
      ) : (
        <div className="flex flex-col gap-1">
          {notifications.map((n, i) => (
            <div
              key={n.id}
              className={`group rounded-xl border p-4 transition-all duration-200 animate-fade-up ${
                n.read
                  ? "border-transparent bg-white hover:bg-navy-50"
                  : "border-brand/15 bg-brand-50/50 hover:bg-brand-50"
              }`}
              style={{ animationDelay: `${i * 30}ms` }}
            >
              <div className="flex items-start gap-3">
                {/* Icon */}
                <div className={`grid h-10 w-10 shrink-0 place-items-center rounded-full text-sm ${
                  n.read ? "bg-navy-100" : "bg-brand-100"
                }`}>
                  {CHANNEL_ICONS[n.channel] || CHANNEL_ICONS.default}
                </div>

                {/* Content */}
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className={`text-sm ${n.read ? "font-medium text-muted" : "font-semibold text-ink"}`}>
                      {n.title}
                    </p>
                    {!n.read && <span className="h-2 w-2 rounded-full bg-brand shrink-0" />}
                  </div>
                  <p className="mt-0.5 text-sm text-muted">{n.body}</p>
                  <p className="mt-1.5 text-xs text-muted/50">{timeAgo(n.created_at)}</p>
                </div>

                {/* Action */}
                {!n.read && (
                  <button
                    onClick={() => markAsRead(n.id)}
                    className="shrink-0 rounded-full bg-brand/10 px-3 py-1 text-xs font-medium text-brand opacity-0 group-hover:opacity-100 transition-all duration-200 hover:bg-brand/20"
                  >
                    Mark read
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
