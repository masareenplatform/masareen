import { useState, useEffect } from "react";
import { apiClient } from "../services/api";
import { useAuth } from "../store/authStore";
import type { ImpactPassport } from "../types";

const tierColors: Record<string, string> = {
  BRONZE: "#CD7F32", SILVER: "#A0A0A0", GOLD: "#C9A84C", PLATINUM: "#E5E4E2",
};

export default function PassportPage() {
  const { user } = useAuth();
  const [passport, setPassport] = useState<ImpactPassport | null>(null);

  useEffect(() => {
    if (!user?.id) return;
    apiClient.get(`/users/${user.id}/impact-passport`).then(r => setPassport(r.data)).catch(() => {});
  }, [user?.id]);

  return (
    <div>
      <h2 className="text-2xl font-bold text-white mb-6">Impact Passport</h2>
      {!passport ? <p className="text-white/60">No passport data available.</p> : (
        <div className="glass-card max-w-md">
          <p className="text-xs uppercase tracking-wide text-white/60 mb-1">PASSPORT ID</p>
          <p className="text-sm text-white font-semibold mb-5">{passport.passport_id}</p>
          <p className="text-xs uppercase tracking-wide text-white/60 mb-1">FULL NAME</p>
          <p className="text-base text-white font-semibold mb-5">{passport.full_name}</p>
          <div className="flex gap-8">
            <div>
              <p className="text-xs uppercase tracking-wide text-white/60 mb-1">PMS SCORE</p>
              <p className="text-2xl font-bold text-white">{passport.pms_score}</p>
            </div>
            <div>
              <p className="text-xs uppercase tracking-wide text-white/60 mb-1">TIER</p>
              <p className="text-2xl font-bold" style={{ color: tierColors[passport.tier] || "#e8edf7" }}>{passport.tier}</p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
