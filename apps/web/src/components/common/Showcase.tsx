import { useState, useEffect, useRef } from "react";
import { BrandWordmark } from "./Branding";
import { avatarColors } from "../../services/postService";
import { IconGoogle } from "../icons/Icons";

/* ── Gradient initial avatar (kept for app-consistent look) ── */
export function MiniAvatar({ name, size = 36, ring }: { name: string; size?: number; ring?: boolean }) {
  const { c1, c2 } = avatarColors(name || "?");
  return (
    <span
      className={`grid shrink-0 place-items-center rounded-full font-semibold text-white ${ring ? "ring-2 ring-white" : ""}`}
      style={{ width: size, height: size, fontSize: size * 0.4, background: `linear-gradient(135deg, ${c1}, ${c2})` }}
    >
      {(name?.[0] ?? "?").toUpperCase()}
    </span>
  );
}

/* ── Real human-face avatar (deterministic via pravatar seed) ── */
export function FaceAvatar({ seed, size = 40, ring = false, src }: { seed: string; size?: number; ring?: boolean; src?: string }) {
  const fallback = `https://i.pravatar.cc/${Math.max(64, size * 2)}?u=${encodeURIComponent(seed)}`;
  const [img, setImg] = useState(src || fallback);
  return (
    <img
      src={img}
      alt={seed}
      width={size}
      height={size}
      loading="lazy"
      onError={() => { if (img !== fallback) setImg(fallback); }}
      className={`shrink-0 rounded-full object-cover ${ring ? "ring-2 ring-white" : ""}`}
      style={{ width: size, height: size }}
    />
  );
}

/* ── Stacked overlapping avatars (social proof) ── */
export function StackedAvatars({ names, size = 34, max = 5 }: { names: string[]; size?: number; max?: number }) {
  const shown = names.slice(0, max);
  const extra = names.length - shown.length;
  return (
    <div className="flex items-center">
      {shown.map((n, i) => (
        <span key={i} className="overflow-visible" style={{ marginLeft: i === 0 ? 0 : -size * 0.35, zIndex: max - i }}>
          <FaceAvatar seed={n} size={size} ring />
        </span>
      ))}
      {extra > 0 && (
        <span
          className="grid shrink-0 place-items-center rounded-full bg-brand font-semibold text-white ring-2 ring-white"
          style={{ width: size, height: size, fontSize: size * 0.32, marginLeft: -size * 0.35 }}
        >
          +{extra}
        </span>
      )}
    </div>
  );
}

/* ── Venn-style overlapping avatars (synergy / collaboration) ── */
export function VennAvatars({ names, size = 40 }: { names: string[]; size?: number }) {
  const a = names.slice(0, 3);
  const positions = [
    { left: 0, top: 0 },
    { left: size * 0.55, top: 0 },
    { left: size * 0.28, top: size * 0.5 },
  ];
  return (
    <div className="relative" style={{ width: size * 1.5, height: size * 1.35 }}>
      {a.map((n, i) => (
        <span key={i} className="absolute" style={{ ...positions[i], zIndex: 3 - i }}>
          <FaceAvatar seed={n} size={size} ring />
        </span>
      ))}
    </div>
  );
}

/* ── Google sign-in button ── */
export function GoogleButton({ onClick, label = "Continue with Google", full = true }: any) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex items-center justify-center gap-3 rounded-xl border border-line bg-white px-4 py-2.5 text-sm font-semibold text-ink transition hover:bg-canvas ${full ? "w-full" : ""}`}
    >
      <IconGoogle size={18} />
      {label}
    </button>
  );
}

/* ── Phone mockup for app showcase (dark app UI) ── */
export function PhoneMock({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return (
    <div className={`phone ${className}`}>
      <div className="phone-screen" style={{ background: "#0A1626" }}>
        <div className="flex items-center gap-2 border-b border-white/10 bg-white/5 px-3 py-2">
          <BrandWordmark className="brightness-0 invert" height={18} />
          <span className="ms-auto chip-accent text-[10px]">Live</span>
        </div>
        <div className="h-[calc(100%-38px)] overflow-hidden bg-[#0A1626]">{children}</div>
      </div>
    </div>
  );
}



/* ── Multi-step onboarding modal (interests / domains / skills / CV) ── */
const INTERESTS = ["Climate", "Education", "Health", "Poverty", "Gender", "Water", "Energy", "Governance"];
const DOMAINS = ["NGO", "Corporate CSR", "Government", "University", "Startup", "Community"];
const SKILLS = ["Project Mgmt", "Field Work", "Data", "Monitoring", "Fundraising", "Design", "Engineering", "Research"];

export function OnboardingModal({ open, onClose, onDone }: { open: boolean; onClose: () => void; onDone: (data: any) => void }) {
  const [step, setStep] = useState(0);
  const [sel, setSel] = useState<{ interests: string[]; domains: string[]; skills: string[]; cv: string }>({
    interests: [], domains: [], skills: [], cv: "",
  });
  useEffect(() => { if (open) setStep(0); }, [open]);
  if (!open) return null;
  const toggle = (k: "interests" | "domains" | "skills", v: string) =>
    setSel((s) => ({ ...s, [k]: s[k].includes(v) ? s[k].filter((x) => x !== v) : [...s[k], v] }));
  const steps = [
    { title: "What causes move you?", sub: "Pick the impact areas you care about.", opts: INTERESTS, key: "interests" as const },
    { title: "Your working domain", sub: "Where do you create impact?", opts: DOMAINS, key: "domains" as const },
    { title: "Your skills", sub: "What do you bring to a team?", opts: SKILLS, key: "skills" as const },
    { title: "A little about you", sub: "Paste a short bio or CV link (optional).", key: "cv" as const },
  ];
  const s = steps[step];
  return (
    <div className="fixed inset-0 z-[80] grid place-items-center px-4" role="dialog" aria-modal="true">
      <div className="absolute inset-0 bg-ink/50 backdrop-blur-sm" onClick={onClose} />
      <div className="relative w-full max-w-md animate-nav-in rounded-3xl bg-white p-5 shadow-float">
        <div className="mb-4 flex items-center justify-between">
          <p className="font-display text-lg font-bold text-ink">{s.title}</p>
          <button className="icon-btn" onClick={onClose} aria-label="Close">✕</button>
        </div>
        <p className="mb-4 text-sm text-muted">{s.sub}</p>
        {s.key === "cv" ? (
          <textarea
            className="glass-input min-h-[120px] w-full"
            placeholder="Short bio, LinkedIn, or CV link…"
            value={sel.cv}
            onChange={(e) => setSel((x) => ({ ...x, cv: e.target.value }))}
          />
        ) : (
          <div className="flex flex-wrap gap-2">
            {s.opts!.map((o) => {
              const active = sel[s.key].includes(o);
              return (
                <button
                  key={o}
                  onClick={() => toggle(s.key, o)}
                  className={`rounded-full px-3 py-1.5 text-sm font-medium transition ${
                    active ? "bg-brand text-white" : "bg-canvas text-ink hover:bg-brand-50"
                  }`}
                >
                  {o}
                </button>
              );
            })}
          </div>
        )}
        <div className="mt-6 flex items-center justify-between">
          <span className="text-xs text-muted">Step {step + 1} / {steps.length}</span>
          <div className="flex gap-2">
            {step > 0 && <button className="btn-ghost" onClick={() => setStep((x) => x - 1)}>Back</button>}
            {step < steps.length - 1 ? (
              <button className="btn-gold" onClick={() => setStep((x) => x + 1)}>Next</button>
            ) : (
              <button className="btn-gold" onClick={() => { onDone(sel); onClose(); }}>Finish</button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
