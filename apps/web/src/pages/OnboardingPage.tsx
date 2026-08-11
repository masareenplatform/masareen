import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { OnboardingModal } from "../components/common/Showcase";
import { useAuth } from "../store/authStore";
import { apiClient } from "../services/api";

export default function OnboardingPage() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [open, setOpen] = useState(true);
  const [saving, setSaving] = useState(false);

  const done = async (data: any) => {
    setSaving(true);
    try {
      await apiClient.patch("/users/me/profile", {
        bio: data.cv || undefined,
        skills: data.skills,
        target_audience: data.domains[0] || undefined,
      });
    } catch { /* non-fatal for demo */ }
    setSaving(false);
    navigate("/feed");
  };

  return (
    <div className="grid min-h-screen place-items-center bg-aurora-light px-4">
      <div className="text-center">
        <p className="font-display text-2xl font-extrabold text-ink">Welcome to MASAREEN</p>
        <p className="mt-2 text-muted">Let's tailor your impact feed. This takes 30 seconds.</p>
      </div>
      <OnboardingModal open={open} onClose={() => navigate("/feed")} onDone={done} />
      {saving && <p className="mt-3 text-sm text-muted">Saving your preferences…</p>}
    </div>
  );
}
