import { useRef, useState } from "react";
import { useAuth } from "../../store/authStore";
import { postService } from "../../services/postService";
import { avatarColors } from "../../services/postService";
import type { PostAuthor, PostKind, PostMedia } from "../../types/social";
import {
  IconPlus, IconImage, IconVideo, IconTask, IconProgram,
  IconEvidence, IconImpact, IconSend,
} from "../icons/Icons";

const KINDS: { key: PostKind; label: string; icon: any; accent: string }[] = [
  { key: "story", label: "Story", icon: IconPlus, accent: "text-brand" },
  { key: "program", label: "Program", icon: IconProgram, accent: "text-accent" },
  { key: "task", label: "Task", icon: IconTask, accent: "text-brand" },
  { key: "evidence", label: "Evidence", icon: IconEvidence, accent: "text-accent" },
  { key: "impact", label: "Impact", icon: IconImpact, accent: "text-brand" },
];

function Avatar({ name, handle, size = 40 }: { name: string; handle: string; size?: number }) {
  const { c1, c2 } = avatarColors(handle || name);
  return (
    <span
      className="avatar-gradient grid shrink-0 place-items-center rounded-full font-semibold text-white"
      style={{ width: size, height: size, fontSize: size * 0.4, ["--c1" as any]: c1, ["--c2" as any]: c2 }}
    >
      {(name?.[0] ?? "?").toUpperCase()}
    </span>
  );
}

export default function Composer({ onPosted }: { onPosted?: () => void }) {
  const { user } = useAuth();
  const [kind, setKind] = useState<PostKind>("story");
  const [text, setText] = useState("");
  const [media, setMedia] = useState<PostMedia[]>([]);
  const [impactValue, setImpactValue] = useState("");
  const [impactLabel, setImpactLabel] = useState("");
  const fileRef = useRef<HTMLInputElement | null>(null);

  const name = user?.full_name ?? "Guest";
  const handle = (user?.email ?? "guest").split("@")[0];

  const author: PostAuthor = {
    id: user?.id ?? "me",
    name,
    handle,
    verified: user?.role === "ORGANIZATION" || user?.role === "ADMIN",
    role: user?.role ?? "Individual",
  };

  function onFiles(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? []);
    const next = files.map((f) => ({
      url: URL.createObjectURL(f),
      type: f.type.startsWith("video") ? ("video" as const) : ("image" as const),
      name: f.name,
    }));
    setMedia((m) => [...m, ...next]);
  }

  function submit() {
    if (!text.trim() && media.length === 0) return;
    postService.create({
      author,
      text: text.trim(),
      kind,
      media,
      impactValue: impactValue ? Number(impactValue) : undefined,
      impactLabel: impactLabel || undefined,
    });
    setText(""); setMedia([]); setImpactValue(""); setImpactLabel(""); setKind("story");
    onPosted?.();
  }

  return (
    <section className="card p-4">
      <div className="flex gap-3">
        <Avatar name={name} handle={handle} />
        <div className="min-w-0 flex-1">
          <textarea
            className="glass-input min-h-[52px] resize-none"
            placeholder="Share an impact story, program, or evidence…"
            value={text}
            onChange={(e) => setText(e.target.value)}
          />

          {media.length > 0 && (
            <div className="mt-3 grid grid-cols-3 gap-2">
              {media.map((m, i) => (
                <div key={i} className="relative overflow-hidden rounded-xl border border-line">
                  {m.type === "image" ? (
                    <img src={m.url} alt={m.name} className="h-24 w-full object-cover" />
                  ) : (
                    <video src={m.url} className="h-24 w-full object-cover" muted />
                  )}
                  <button
                    className="absolute right-1 top-1 grid h-6 w-6 place-items-center rounded-full bg-black/60 text-white"
                    onClick={() => setMedia((arr) => arr.filter((_, j) => j !== i))}
                  >
                    ×
                  </button>
                </div>
              ))}
            </div>
          )}

          {kind === "impact" && (
            <div className="mt-3 flex gap-2">
              <input
                className="glass-input"
                placeholder="Value (e.g. 1200)"
                value={impactValue}
                inputMode="numeric"
                onChange={(e) => setImpactValue(e.target.value)}
              />
              <input
                className="glass-input"
                placeholder="Label (e.g. trees planted)"
                value={impactLabel}
                onChange={(e) => setImpactLabel(e.target.value)}
              />
            </div>
          )}

          <div className="mt-3 flex flex-wrap items-center gap-1.5">
            {KINDS.map((k) => (
              <button
                key={k.key}
                onClick={() => setKind(k.key)}
                className={`btn px-3 py-1.5 text-xs ${kind === k.key ? "btn-soft" : "btn-ghost"}`}
              >
                <k.icon size={16} className={k.accent} /> {k.label}
              </button>
            ))}
            <button className="icon-btn" title="Attach evidence" onClick={() => fileRef.current?.click()}>
              <IconImage size={20} />
            </button>
            <button className="icon-btn" title="Attach video" onClick={() => fileRef.current?.click()}>
              <IconVideo size={20} />
            </button>
            <input ref={fileRef} type="file" accept="image/*,video/*" multiple hidden onChange={onFiles} />
            <button className="btn-gold ms-auto px-4 py-1.5 text-sm" onClick={submit} disabled={!text.trim() && !media.length}>
              <IconSend size={16} /> Post
            </button>
          </div>
        </div>
      </div>
    </section>
  );
}
