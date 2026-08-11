import { useState, useEffect } from "react";
import { programService } from "../services/api";
import type { Program } from "../types";

export default function ProgramsPage() {
  const [programs, setPrograms] = useState<Program[]>([]);

  useEffect(() => {
    programService.list().then(setPrograms).catch(() => setPrograms([]));
  }, []);

  const badge = (status: string) => ({
    padding: "3px 10px", borderRadius: 6, fontSize: 11, fontWeight: 600,
    background: status === "ACTIVE" || status === "COMPLETED" ? "#D1FAE5" : "#FEF3C7",
    color: status === "ACTIVE" || status === "COMPLETED" ? "#065F46" : "#92400E",
  } as React.CSSProperties);

  return (
    <div>
      <h2 className="text-2xl font-bold text-ink mb-6">Programs</h2>
      {programs.length === 0 ? <p className="text-muted">No programs yet.</p> : (
        <div className="glass rounded-2xl overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-navy-100 text-left text-muted text-xs uppercase tracking-wide">
                {["Title", "SDG Goals", "Enrolled", "Status"].map(h => (
                  <th key={h} className="px-4 py-3 font-semibold">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {programs.map(p => (
                <tr key={p.id} className="border-t border-line/60 hover:bg-navy-100 transition">
                  <td className="px-4 py-3 text-ink font-medium">{p.title}</td>
                  <td className="px-4 py-3 text-ink/70">{p.sdg_goals?.join(", ")}</td>
                  <td className="px-4 py-3 text-ink/70">{p.enrolled_count}</td>
                  <td className="px-4 py-3"><span style={badge(p.status)}>{p.status}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
