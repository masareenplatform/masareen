import { useRef, useState, useCallback } from "react";
import { useAuth } from "../../store/authStore";
import { postService, avatarColors } from "../../services/postService";
import type { PostAuthor, PostKind, PostMedia } from "../../types/social";
import { useI18n } from "../../i18n";
import {
  IconPlus, IconImage, IconVideo, IconTask, IconProgram,
  IconEvidence, IconImpact, IconSend,
} from "../icons/Icons";

const KINDS: { key: PostKind; labelKey: string; icon: any; accent: string }[] = [
  { key: "story", labelKey: "post.kind.story", icon: IconPlus, accent: "text-brand" },
  { key: "program", labelKey: "post.kind.program", icon: IconProgram, accent: "text-accent" },
  { key: "task", labelKey: "post.kind.task", icon: IconTask, accent: "text-brand" },
  { key: "evidence", labelKey: "post.kind.evidence", icon: IconEvidence, accent: "text-accent" },
  { key: "impact", labelKey: "post.kind.impact", icon: IconImpact, accent: "text-brand" },
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
  const { t } = useI18n();
  const [kind, setKind] = useState<PostKind>("story");
  const [text, setText] = useState("");
  const [media, setMedia] = useState<PostMedia[]>([]);
  const [impactValue, setImpactValue] = useState("");
  const [impactLabel, setImpactLabel] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [focused, setFocused] = useState(false);
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

  const removeMedia = useCallback((idx: number) => {
    setMedia((arr) => {
      const removed = arr[idx];
      if (removed?.url?.startsWith("blob:")) URL.revokeObjectURL(removed.url);
      return arr.filter((_, j) => j !== idx);
    });
  }, []);

  function onFiles(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? []);
    const next = files.map((f) => ({
      url: URL.createObjectURL(f),
      type: f.type.startsWith("video") ? ("video" as const) : ("image" as const),
      name: f.name,
      _file: f,
    }));
    setMedia((m) => [...m, ...next]);
    e.target.value = "";
  }

  async function submit() {
    if (!text.trim() && media.length === 0) return;
    setSubmitting(true);
    try {
      const token = localStorage.getItem("masaren_token") || "";
      const uploaded: PostMedia[] = [];
      for (const m of media) {
        if ((m as any)._file) {
          const f = (m as any)._file as File;
          const isVideo = f.type.startsWith("video");
          const fd = new FormData();
          fd.append("file", f);
          try {
            const url = isVideo
              ? `${window.location.origin}/api/v1/videos/upload`
              : `${window.location.origin}/api/v1/users/me/avatar`;
            const res = await fetch(url, {
              method: "POST",
              headers: { Authorization: `Bearer ${token}` },
              body: fd,
            });
            const data = await res.json();
            const d = data?.data ?? data;
            if (isVideo) {
              uploaded.push({ url: d.hls_url || "", type: "video", name: f.name });
            } else {
              uploaded.push({ url: d.avatar_url || d.url || "", type: "image", name: f.name });
            }
          } catch {
            uploaded.push({ url: (m as any).url, type: m.type, name: m.name });
          }
        } else {
          uploaded.push(m);
        }
      }
      await postService.create({
        author,
        text: text.trim(),
        kind,
        media: uploaded,
        impactValue: impactValue ? Number(impactValue) : undefined,
        impactLabel: impactLabel || undefined,
      });
      media.forEach(m => { if (m.url?.startsWith("blob:")) URL.revokeObjectURL(m.url); });
      setText(""); setMedia([]); setImpactValue(""); setImpactLabel(""); setKind("story");
      setFocused(false);
      onPosted?.();
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className={`rounded-xl bg-white border transition-all duration-200 ${
      focused ? "border-brand/30 shadow-md ring-4 ring-brand/5" : "border-line/50 shadow-sm"
    }`}>
      <div className="flex gap-3 p-4">
        <Avatar name={name} handle={handle} />
        <div className="min-w-0 flex-1">
          <textarea
            className="w-full resize-none bg-transparent text-sm text-ink placeholder-muted/40 outline-none min-h-[40px] leading-relaxed"
            placeholder={t("post.placeholder")}
            value={text}
            onChange={(e) => setText(e.target.value)}
            onFocus={() => setFocused(true)}
            onBlur={() => !text && !media.length && setFocused(false)}
          />

          {/* Media preview */}
          {media.length > 0 && (
            <div className="mt-3 grid grid-cols-3 gap-2">
              {media.map((m, i) => (
                <div key={i} className="relative overflow-hidden rounded-lg bg-navy-50 group">
                  {m.type === "image" ? (
                    <img src={m.url} alt={m.name} className="h-24 w-full object-cover" />
                  ) : (
                    <video src={m.url} className="h-24 w-full object-cover" muted />
                  )}
                  <button
                    className="absolute right-1.5 top-1.5 grid h-6 w-6 place-items-center rounded-full bg-black/50 text-white opacity-0 group-hover:opacity-100 transition-opacity duration-150 text-xs"
                    onClick={() => removeMedia(i)}
                  >
                    ×
                  </button>
                </div>
              ))}
            </div>
          )}

          {/* Impact fields */}
          {kind === "impact" && (
            <div className="mt-3 flex gap-2 animate-fade-down">
              <input
                className="glass-input !py-2 !text-sm flex-1"
                placeholder="Value (e.g. 1200)"
                value={impactValue}
                inputMode="numeric"
                onChange={(e) => setImpactValue(e.target.value)}
              />
              <input
                className="glass-input !py-2 !text-sm flex-1"
                placeholder="Label (e.g. trees planted)"
                value={impactLabel}
                onChange={(e) => setImpactLabel(e.target.value)}
              />
            </div>
          )}
        </div>
      </div>

      {/* Bottom toolbar */}
      <div className="flex items-center gap-1 border-t border-line/50 px-4 py-2.5">
        {KINDS.map((k) => (
          <button
            key={k.key}
            onClick={() => setKind(k.key)}
            className={`btn text-xs px-2.5 py-1.5 rounded-lg transition-all duration-150 ${
              kind === k.key
                ? "bg-brand-50 text-brand font-medium"
                : "text-muted hover:bg-navy-50"
            }`}
          >
            <k.icon size={15} className={kind === k.key ? k.accent : ""} /> {t(k.labelKey)}
          </button>
        ))}

        <div className="ms-auto flex items-center gap-1">
          <button
            className="icon-btn !h-8 !w-8"
            title={t("action.attachImage")}
            onClick={() => fileRef.current?.click()}
          >
            <IconImage size={18} />
          </button>
          <button
            className="icon-btn !h-8 !w-8"
            title={t("action.attachVideo")}
            onClick={() => fileRef.current?.click()}
          >
            <IconVideo size={18} />
          </button>
          <input ref={fileRef} type="file" accept="image/*,video/*" multiple hidden onChange={onFiles} />

          <button
            className="btn-primary ms-1 px-4 py-1.5 text-sm"
            onClick={submit}
            disabled={submitting || (!text.trim() && !media.length)}
          >
            {submitting ? (
              <span className="inline-flex items-center gap-1.5">
                <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-white border-t-transparent" />
                {t("action.posting")}
              </span>
            ) : (
              <><IconSend size={15} /> {t("action.post")}</>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
