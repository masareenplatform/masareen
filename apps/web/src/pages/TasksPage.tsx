import { useState, useEffect } from "react";
import { taskService } from "../services/api";
import { useAuth } from "../store/authStore";
import type { Task } from "../types";

const statusColors: Record<string, string> = {
  PENDING: "#FEF3C7", ASSIGNED: "#DBEAFE", IN_PROGRESS: "#DBEAFE",
  SUBMITTED: "#E0E7FF", VERIFIED: "#D1FAE5", COMPLETED: "#D1FAE5", CANCELLED: "#FEE2E2",
};

const statusText: Record<string, string> = {
  PENDING: "#92400E", ASSIGNED: "#1E40AF", IN_PROGRESS: "#1E40AF",
  SUBMITTED: "#3730A3", VERIFIED: "#065F46", COMPLETED: "#065F46", CANCELLED: "#991B1B",
};

export default function TasksPage() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const { user } = useAuth();

  useEffect(() => {
    if (!user?.id) return;
    taskService.listForUser(user.id).then(setTasks).catch(() => setTasks([]));
  }, [user?.id]);

  return (
    <div>
      <h2 className="text-2xl font-bold text-ink mb-6">Tasks</h2>
      {tasks.length === 0 ? <p className="text-muted">No tasks assigned.</p> : (
        <div className="glass rounded-2xl overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-navy-100 text-left text-muted text-xs uppercase tracking-wide">
                {["Title", "Status", "Assignee", "Evidence", "Due Date"].map(h => (
                  <th key={h} className="px-4 py-3 font-semibold">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {tasks.map(t => (
                <tr key={t.id} className="border-t border-line/60 hover:bg-navy-100 transition">
                  <td className="px-4 py-3 text-ink font-medium">{t.title}</td>
                  <td className="px-4 py-3">
                    <span className="inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold"
                      style={{ background: statusColors[t.status] || "#F3F4F6", color: statusText[t.status] || "#6B7280" }}>{t.status}</span>
                  </td>
                  <td className="px-4 py-3 text-ink/70">{t.assignee_id || "—"}</td>
                  <td className="px-4 py-3 text-ink/70">{(t.evidence_ids?.length ?? 0)} files</td>
                  <td className="px-4 py-3 text-ink/70">{t.due_date ? new Date(t.due_date).toLocaleDateString() : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
