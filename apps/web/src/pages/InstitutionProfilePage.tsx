import { useParams, Link } from "react-router-dom";
import { recognizedInstitutions } from "../services/postService";
import { IconBadge, IconUsers, IconGlobe, IconCheck } from "../components/icons/Icons";

const GOV_REGISTRY: Record<string, any> = {
  u_gov: {
    id: "u_gov", name: "Ministry of Environment", handle: "moenv",
    kind: "government", badge: "Government Partner",
    note: "Official SDG reporting channel",
    mandate: "Leads national environmental policy, climate adaptation and verified public-impact reporting across all governorates.",
    sectors: ["Climate", "Biodiversity", "Water", "Public Health"],
    contacts: ["press@moenv.gov", "+966 11 000 0000"],
    established: "1975",
    hq: "Capital District",
  },
};

function useInstitution(id?: string) {
  if (!id) return null;
  if (GOV_REGISTRY[id]) return { ...GOV_REGISTRY[id], recognized: false };
  const rec = recognizedInstitutions.find((r) => r.id === id);
  if (rec) return { ...rec, recognized: true };
  return null;
}

export default function InstitutionProfilePage() {
  const { id } = useParams();
  const inst = useInstitution(id);

  if (!inst) {
    return (
      <div className="mx-auto max-w-3xl">
        <div className="card p-10 text-center text-muted">Institution profile not found.</div>
      </div>
    );
  }

  const isGov = inst.kind === "government";

  return (
    <div className="mx-auto max-w-4xl">
      {/* Hero */}
      <div
        className={`relative overflow-hidden ${isGov ? "gov-hero" : "rounded-3xl bg-gradient-to-r from-brand to-azure text-white"}`}
      >
        <div className="relative flex flex-col gap-5 p-6 sm:flex-row sm:items-center sm:gap-6">
          <div className={`grid h-24 w-24 shrink-0 place-items-center rounded-2xl text-4xl font-black ${isGov ? "bg-white/15 ring-2 ring-white/40 text-white" : "bg-white text-brand"}`}>
            {inst.name[0]}
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <h1 className={`text-3xl font-black ${isGov ? "text-white" : "text-white"}`}>{inst.name}</h1>
              {inst.recognized && <IconBadge size={22} className="text-amber-200" />}
            </div>
            <p className={`text-sm ${isGov ? "text-white/70" : "text-white/80"}`}>@{inst.handle}</p>
            <div className="mt-2 flex flex-wrap gap-2">
              <span className={`rounded-full px-3 py-1 text-xs font-bold ${isGov ? "bg-white/15 text-white" : "bg-white/20 text-white"}`}>
                {inst.badge}
              </span>
              {inst.note && <span className={`rounded-full px-3 py-1 text-xs ${isGov ? "bg-white/10 text-white/80" : "bg-white/10 text-white/80"}`}>{inst.note}</span>}
            </div>
          </div>
          <div className="flex shrink-0 gap-2">
            <button className="rounded-full bg-white px-4 py-1.5 text-sm font-semibold text-brand">Follow</button>
            <button className="rounded-full border border-white/40 px-4 py-1.5 text-sm text-white hover:bg-white/10">Share</button>
          </div>
        </div>
      </div>

      {isGov ? (
        <GovBody inst={inst} />
      ) : (
        <MediaBody inst={inst} />
      )}
    </div>
  );
}

function GovBody({ inst }: { inst: any }) {
  return (
    <div className="mt-5 space-y-4">
      <div className="gov-card">
        <h2 className="gov-section-title">Official Mandate</h2>
        <p className="gov-lede">{inst.mandate}</p>
      </div>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="gov-card">
          <h3 className="gov-label">Established</h3>
          <p className="gov-value">{inst.established}</p>
        </div>
        <div className="gov-card">
          <h3 className="gov-label">Headquarters</h3>
          <p className="gov-value">{inst.hq}</p>
        </div>
        <div className="gov-card">
          <h3 className="gov-label">Status</h3>
          <p className="gov-value flex items-center gap-1"><IconCheck size={16} className="text-accent" /> Verified Partner</p>
        </div>
      </div>
      <div className="gov-card">
        <h2 className="gov-section-title">Sectors of Competence</h2>
        <div className="flex flex-wrap gap-2">
          {inst.sectors?.map((s: string, i: number) => (
            <span key={i} className="gov-tag">{s}</span>
          ))}
        </div>
      </div>
      <div className="gov-card">
        <h2 className="gov-section-title">Official Contacts</h2>
        <ul className="space-y-1 text-sm text-muted">
          {inst.contacts?.map((c: string, i: number) => (
            <li key={i} className="flex items-center gap-2"><IconGlobe size={16} className="text-brand" /> {c}</li>
          ))}
        </ul>
      </div>
      <div className="gov-card">
        <h2 className="gov-section-title">Public Impact Reporting</h2>
        <p className="text-sm text-muted">
          This ministry publishes verified, evidence-backed reports through the MASAREEN platform.
          All submissions are audited via POAI and carry an official government verification seal.
        </p>
      </div>
    </div>
  );
}

function MediaBody({ inst }: { inst: any }) {
  return (
    <div className="mt-5 space-y-4">
      <div className="card p-5">
        <h2 className="mb-2 text-sm font-bold uppercase tracking-wide text-muted">Why recognized</h2>
        <p className="text-sm text-ink">{inst.note}</p>
      </div>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="card p-4 text-center">
          <p className="text-2xl font-extrabold text-ink">96%</p>
          <p className="text-xs text-muted">Evidence accuracy</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-2xl font-extrabold text-ink">14</p>
          <p className="text-xs text-muted">Countries covered</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-2xl font-extrabold text-ink">A+</p>
          <p className="text-xs text-muted">Trust rating</p>
        </div>
      </div>
      <div className="card p-5">
        <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-muted">Latest from {inst.name}</h2>
        <p className="text-sm text-muted">Verified field reports and recognition posts appear in your feed. Follow to receive live updates.</p>
        <Link to="/feed" className="btn-brand mt-3 inline-block px-4 py-2 text-sm">View in feed</Link>
      </div>
    </div>
  );
}
