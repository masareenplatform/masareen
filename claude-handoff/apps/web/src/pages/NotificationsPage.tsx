import React, { useEffect, useState } from 'react';
import { notificationService } from '../services/api';
import { useAuth } from '../store/authStore';

interface Notification {
  id: string;
  title: string;
  body: string;
  channel: string;
  created_at: string;
  read: boolean;
}

export default function NotificationsPage() {
  const { user } = useAuth();
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchNotifications = async () => {
    if (!user?.id) return;
    try {
      const data = await notificationService.list(user.id);
      setNotifications(data as Notification[]);
    } catch (e) {
      console.error('Error fetching notifications', e);
    } finally {
      setLoading(false);
    }
  };

  const markAsRead = async (id: string) => {
    if (!user?.id) return;
    try {
      await notificationService.markRead(user.id, id);
      setNotifications(prev => prev.map(n => n.id === id ? { ...n, read: true } : n));
    } catch (e) {
      console.error('Error marking as read', e);
    }
  };

  useEffect(() => {
    fetchNotifications();
  }, [user?.id]);

  if (loading) return <div className="p-8 text-white/60">Loading notifications...</div>;

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-white mb-6">Notifications</h1>
      {notifications.length === 0 ? (
        <p className="text-white/60">No notifications yet.</p>
      ) : (
        <div className="grid gap-4">
          {notifications.map(n => (
            <div key={n.id} className={`glass rounded-xl p-4 flex justify-between items-center ${n.read ? 'opacity-70' : 'border-gold/40'}`}>
              <div>
                <p className="font-bold text-white">{n.title}</p>
                <p className="text-sm text-white/60">{n.body}</p>
                <p className="text-xs text-white/40 mt-1">{n.created_at}</p>
              </div>
              {!n.read && (
                <button
                  onClick={() => markAsRead(n.id)}
                  className="btn-gold text-xs"
                >
                  Mark as Read
                </button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
