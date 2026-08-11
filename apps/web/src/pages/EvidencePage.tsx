import { useState } from "react";
import { evidenceService } from "../services/api";

interface EvidenceItem {
  id: string; task_id: string; media_type: string; status: string;
  submitted_by?: string; is_approved?: boolean; storage_url?: string | null;
}

const mediaColors: Record<string, string> = {
  PHOTO: "#DBEAFE", IMAGE: "#DBEAFE", VIDEO: "#FEF3C7", DOCUMENT: "#E0E7FF", AUDIO: "#D1FAE5", OTHER: "#F3F4F6",
};

export default function EvidencePage() {
  const [items, setItems] = useState<EvidenceItem[]>([]);
  const [taskId, setTaskId] = useState("");
  const [mediaType, setMediaType] = useState("PHOTO");
  const [submitting, setSubmitting] = useState(false);
  const [loaded, setLoaded] = useState(false);

  const load = async (id: string) => {
    if (!id) return;
    try {
      const rows = await evidenceService.listForTask(id);
      setItems(rows);
    } catch {
      setItems([]);
    } finally {
      setLoaded(true);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!taskId) return;
    setSubmitting(true);
    try {
      // Evidence is scoped to a task in the verification domain.
      await evidenceService.capture({
        task_id: taskId,
        submitted_by: taskId, // caller identity is enforced server-side via JWT
        media_type: mediaType,
        file_size_bytes: 1800000,
      });
      await load(taskId);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div>
      <h2 className="text-2xl font-bold text-ink mb-6">Evidence</h2>

      <form onSubmit={handleSubmit} className="flex gap-3 mb-6 flex-wrap items-center">
        <input placeholder="Task ID" value={taskId} onChange={e => setTaskId(e.target.value)}
          className="glass-input" />
        <select value={mediaType} onChange={e => setMediaType(e.target.value)} className="glass-input w-auto">
          <option value="PHOTO">PHOTO</option>
          <option value="VIDEO">VIDEO</option>
          <option value="AUDIO">AUDIO</option>
          <option value="DOCUMENT">DOCUMENT</option>
        </select>
        <button type="button" onClick={() => load(taskId)} className="btn-ghost">
          Load
        </button>
        <button type="submit" disabled={submitting} className="btn-gold">
          {submitting ? "Submitting…" : "Capture Evidence"}
        </button>
      </form>

      {loaded && items.length === 0 ? <p className="text-muted">No evidence for this task.</p> : null}
      {items.length > 0 && (
        <div className="glass rounded-2xl overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-navy-100 text-left text-muted text-xs uppercase tracking-wide">
                {["Evidence ID", "Type", "Approved", "Status"].map(h => (
                  <th key={h} className="px-4 py-3 font-semibold">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {items.map(ev => (
                <tr key={ev.id} className="border-t border-line/60 hover:bg-navy-100 transition">
                  <td className="px-4 py-3 text-ink font-medium">{ev.id}</td>
                  <td className="px-4 py-3">
                    <span className="inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold"
                      style={{ background: mediaColors[ev.media_type] || "#F3F4F6", color: "#374151" }}>{ev.media_type}</span>
                  </td>
                  <td className="px-4 py-3 font-semibold" style={{ color: ev.is_approved ? "#6EE7B7" : "#FCA5A5" }}>
                    {ev.is_approved ? "Yes" : "No"}
                  </td>
                  <td className="px-4 py-3 text-ink/70">{ev.status}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
