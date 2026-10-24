import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import {
  IconShield, IconGlobe, IconSparkles,
  IconWallet, IconProgram, IconTask, IconCompass,
  IconReports, IconAdmin, IconUsers, IconFlag, IconTrophy,
  IconArrowRight, IconBookmark, IconHandshake,
} from "../components/icons/Icons";
import MarketingNav from "../components/marketing/MarketingNav";
import MarketingFooter from "../components/marketing/MarketingFooter";
import { useI18n } from "../i18n";

/* ── types ───────────────────────────────────────────────────────────────── */

type Section = {
  id: string;
  title: string;
  icon: (p: { className?: string; size?: number }) => JSX.Element;
};

const SECTIONS: Section[] = [
  { id: "overview", title: "Overview", icon: IconSparkles },
  { id: "getting-started", title: "Getting Started", icon: IconArrowRight },
  { id: "feed", title: "The Feed", icon: IconBookmark },
  { id: "verification", title: "Verification Pipeline", icon: IconShield },
  { id: "coin", title: "MASAREEN Coin", icon: IconWallet },
  { id: "programs", title: "Programs & Tasks", icon: IconProgram },
  { id: "opportunities", title: "Opportunities", icon: IconCompass },
  { id: "profiles", title: "Profiles", icon: IconUsers },
  { id: "admin", title: "Admin Panel", icon: IconAdmin },
  { id: "api", title: "API Reference", icon: IconReports },
  { id: "architecture", title: "Architecture", icon: IconTask },
];

/* ── collapsible ─────────────────────────────────────────────────────────── */

function Collapsible({ title, children, defaultOpen = false }: { title: string; children: React.ReactNode; defaultOpen?: boolean }) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div className="rounded-xl border border-line overflow-hidden">
      <button onClick={() => setOpen(!open)} className="flex w-full items-center justify-between gap-3 px-5 py-3 text-left bg-canvas hover:bg-brand-50 transition">
        <span className="text-sm font-semibold text-ink">{title}</span>
        <span className={`grid h-6 w-6 place-items-center rounded-full transition text-xs ${open ? "bg-brand text-white rotate-180" : "bg-white text-muted"}`}>▾</span>
      </button>
      {open && <div className="px-5 py-4 text-sm text-muted leading-relaxed">{children}</div>}
    </div>
  );
}

/* ── code block ──────────────────────────────────────────────────────────── */

function CodeBlock({ code, language = "json" }: { code: string; language?: string }) {
  return (
    <pre className="overflow-x-auto rounded-xl bg-[#0D1B2A] p-4 text-xs leading-relaxed text-emerald-300 ring-1 ring-white/10">
      <code>{code}</code>
    </pre>
  );
}

/* ── sidebar ─────────────────────────────────────────────────────────────── */

function Sidebar({ active, onSelect }: { active: string; onSelect: (id: string) => void }) {
  return (
    <nav className="sticky top-24 hidden w-56 shrink-0 lg:block">
      <p className="mb-3 px-3 text-xs font-bold uppercase tracking-wider text-muted">Documentation</p>
      <ul className="space-y-0.5">
        {SECTIONS.map((s) => (
          <li key={s.id}>
            <button
              onClick={() => onSelect(s.id)}
              className={`flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-left text-sm transition ${active === s.id ? "bg-brand-50 font-semibold text-brand-700" : "text-muted hover:bg-canvas hover:text-ink"}`}
            >
              <s.icon size={16} /> {s.title}
            </button>
          </li>
        ))}
      </ul>
    </nav>
  );
}

/* ── content sections ────────────────────────────────────────────────────── */

function Overview() {
  const { t } = useI18n();
  return (
    <div>
      <h2 className="font-display text-2xl font-extrabold text-ink">{t("app.name")} Overview</h2>
      <p className="mt-3 text-sm text-muted leading-relaxed">
        MASAREEN is a verified-impact platform that combines social networking, evidence-based verification and a token economy
        into a single infrastructure for proving real-world change. It is designed for NGOs, governments, sports institutions,
        media organizations and individual impact workers across Egypt and beyond.
      </p>
      <div className="mt-6 grid gap-4 sm:grid-cols-2">
        <div className="rounded-xl bg-canvas p-4">
          <h3 className="text-sm font-bold text-ink">Vision</h3>
          <p className="mt-1 text-xs text-muted">Make every unit of social impact provable, auditable and economically meaningful, so funders trust outcomes and workers earn from real change.</p>
        </div>
        <div className="rounded-xl bg-canvas p-4">
          <h3 className="text-sm font-bold text-ink">SDG Alignment</h3>
          <p className="mt-1 text-xs text-muted">Every verified action maps to one or more of the 17 UN Sustainable Development Goals and to Egypt Vision 2030 pillars.</p>
        </div>
      </div>
    </div>
  );
}

function GettingStarted() {
  return (
    <div>
      <h2 className="font-display text-2xl font-extrabold text-ink">Getting Started</h2>
      <div className="mt-4 space-y-4">
        {[
          { n: 1, title: "Sign up", desc: "Visit masaren.com/register or download the Android APK. Create an account with email or Google sign-in." },
          { n: 2, title: "Choose your role", desc: "Select Individual, NGO, Government, Media or Sports. This tailors your dashboard and available features." },
          { n: 3, title: "Complete your profile", desc: "Add a photo, bio, organization details and SDG focus areas. A complete profile earns a higher PMS score." },
          { n: 4, title: "Join or create a program", desc: "Browse the Opportunities marketplace or launch your own program with tasks and evidence requirements." },
          { n: 5, title: "Post your first impact", desc: "Share a story, attach evidence (photos, GPS) and submit for POAI verification." },
        ].map((s) => (
          <div key={s.n} className="flex gap-3">
            <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-brand text-xs font-bold text-white">{s.n}</span>
            <div>
              <p className="text-sm font-semibold text-ink">{s.title}</p>
              <p className="text-xs text-muted">{s.desc}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function FeedDocs() {
  return (
    <div>
      <h2 className="font-display text-2xl font-extrabold text-ink">The Feed</h2>
      <p className="mt-3 text-sm text-muted leading-relaxed">
        The MASAREEN feed is a social timeline of verified impact stories. Posts are ranked by a composite score combining
        recency, engagement and verification confidence, not just likes.
      </p>
      <h3 className="mt-6 text-base font-bold text-ink">Post Types</h3>
      <div className="mt-3 grid gap-3 sm:grid-cols-2">
        {[
          { type: "Story", desc: "A narrative impact post with rich text and media attachments." },
          { type: "Program", desc: "An announcement for a program with join links and task breakdown." },
          { type: "Task", desc: "A specific task within a program with deadlines and assignments." },
          { type: "Evidence", desc: "A dedicated evidence post with GPS, photos and sensor data." },
          { type: "Impact", desc: "A verified outcome post with POAI badge and metrics." },
        ].map((p) => (
          <div key={p.type} className="rounded-xl bg-canvas p-3">
            <p className="text-sm font-semibold text-brand-700">{p.type}</p>
            <p className="text-xs text-muted">{p.desc}</p>
          </div>
        ))}
      </div>
      <h3 className="mt-6 text-base font-bold text-ink">Verification Badges</h3>
      <p className="mt-2 text-sm text-muted">
        Every verified post displays a <span className="font-semibold text-brand">POAI ✓</span> badge.
        Confidence levels: <span className="font-semibold text-accent">High</span> (auto-verified),
        <span className="font-semibold text-amber-600"> Medium</span> (peer-reviewed),
        <span className="font-semibold text-muted"> Pending</span> (awaiting audit).
      </p>
    </div>
  );
}

function VerificationDocs() {
  return (
    <div>
      <h2 className="font-display text-2xl font-extrabold text-ink">Verification Pipeline</h2>
      <p className="mt-3 text-sm text-muted leading-relaxed">
        POAI (Proof of Actual Impact) is MASAREEN's core verification engine. Every claim moves through a five-step
        pipeline from raw input to a trusted, published outcome.
      </p>
      <div className="mt-6 space-y-3">
        {[
          { step: "Event Capture", desc: "An action fires, tree planted, clinic run, goal scored. It becomes an event in the stream." },
          { step: "Evidence Bundling", desc: "Photos, GPS coordinates, timestamps and sensor data are packaged into a tamper-evident bundle." },
          { step: "POAI Scoring", desc: "The algorithm evaluates plausibility, completeness, SDG alignment and consistency with historical data." },
          { step: "Audit Decision", desc: "High-confidence events auto-verify. Low-confidence events route to human or partner audit." },
          { step: "Publish & Amplify", desc: "Verified outcomes get the POAI badge, flow into dashboards and the coin economy." },
        ].map((s, i) => (
          <div key={i} className="flex gap-3">
            <span className="grid h-7 w-7 shrink-0 place-items-center rounded-lg bg-brand-50 text-xs font-bold text-brand">{i + 1}</span>
            <div>
              <p className="text-sm font-semibold text-ink">{s.step}</p>
              <p className="text-xs text-muted">{s.desc}</p>
            </div>
          </div>
        ))}
      </div>
      <h3 className="mt-6 text-base font-bold text-ink">Confidence Scores</h3>
      <p className="mt-2 text-sm text-muted">
        Claims receive a confidence score from 0 to 100. Scores above 85 auto-verify. Scores between 60–85 require
        peer review. Below 60 triggers a field audit or is rejected with feedback.
      </p>
      <CodeBlock code={`{
  "claim_id": "c_1847",
  "confidence": 92,
  "auto_verified": true,
  "evidence_count": 4,
  "sdg_alignment": ["SDG_13", "SDG_15"],
  "timestamp": "2026-07-15T14:30:00Z"
}`} />
    </div>
  );
}

function CoinDocs() {
  return (
    <div>
      <h2 className="font-display text-2xl font-extrabold text-ink">MASAREEN Coin</h2>
      <p className="mt-3 text-sm text-muted leading-relaxed">
        MASAREEN Coin is the platform's impact economy. It rewards verified outcomes, enables transparent transactions
        and funds platform operations through a brokerage model.
      </p>
      <div className="mt-6 grid gap-4 sm:grid-cols-2">
        <div className="rounded-xl bg-canvas p-4">
          <h3 className="text-sm font-bold text-ink">Earning Coin</h3>
          <ul className="mt-2 space-y-1 text-xs text-muted">
            <li>• Verified impact actions</li>
            <li>• Completing program tasks</li>
            <li>• Peer endorsements</li>
            <li>• Teaching courses</li>
          </ul>
        </div>
        <div className="rounded-xl bg-canvas p-4">
          <h3 className="text-sm font-bold text-ink">Spending Coin</h3>
          <ul className="mt-2 space-y-1 text-xs text-muted">
            <li>• Funding programs</li>
            <li>• Running impact ads</li>
            <li>• Accessing premium analytics</li>
            <li>• Donating to causes</li>
          </ul>
        </div>
      </div>
      <h3 className="mt-6 text-base font-bold text-ink">Wallet API</h3>
      <CodeBlock code={`GET /api/v1/wallet/balance
Response: {
  "balance": 12450,
  "pending": 320,
  "currency": "MSC",
  "usd_rate": 0.008
}

POST /api/v1/wallet/transfer
Body: {
  "to_user_id": "u_42",
  "amount": 500,
  "reason": "task_completion"
}`} />
      <h3 className="mt-6 text-base font-bold text-ink">Exchange Rate</h3>
      <p className="mt-2 text-sm text-muted">
        1 MASAREEN Coin (MSC) ≈ $0.008 USD during alpha. Rates are published transparently on the platform
        and adjusted quarterly based on platform revenue.
      </p>
    </div>
  );
}

function ProgramsDocs() {
  return (
    <div>
      <h2 className="font-display text-2xl font-extrabold text-ink">Programs & Tasks</h2>
      <p className="mt-3 text-sm text-muted leading-relaxed">
        Programs are structured initiatives with tasks, participants and verified outcomes. They are the primary
        organizational unit for impact work on MASAREEN.
      </p>
      <div className="mt-6 space-y-4">
        <Collapsible title="Creating a program">
          <p className="mb-2">Any verified user or organization can create a program. Programs include:</p>
          <ul className="list-disc pl-4 space-y-1">
            <li>Title, description and SDG alignment</li>
            <li>Task breakdown with deadlines and assignments</li>
            <li>Evidence requirements per task</li>
            <li>Participant management and progress tracking</li>
          </ul>
        </Collapsible>
        <Collapsible title="Task lifecycle">
          <p>Tasks move through: <strong>Draft → Assigned → In Progress → Evidence Submitted → Under Review → Verified/Rejected.</strong> Each transition is logged in the audit trail.</p>
        </Collapsible>
        <Collapsible title="Completion criteria">
          <p>A program is marked complete when all tasks reach Verified status and aggregate evidence meets the program's minimum POAI threshold (default: 80% confidence).</p>
        </Collapsible>
      </div>
    </div>
  );
}

function OpportunitiesDocs() {
  return (
    <div>
      <h2 className="font-display text-2xl font-extrabold text-ink">Opportunities</h2>
      <p className="mt-3 text-sm text-muted leading-relaxed">
        The Opportunity Marketplace connects impact workers with volunteering positions, jobs, grants and partnerships, all
        backed by verified impact credentials.
      </p>
      <h3 className="mt-6 text-base font-bold text-ink">Types</h3>
      <div className="mt-3 grid gap-2 sm:grid-cols-2">
        {["Volunteering", "Employment", "Grants & Funding", "Partnerships", "Mentorship", "Internships"].map((t) => (
          <div key={t} className="rounded-lg bg-canvas px-3 py-2 text-sm font-medium text-ink">{t}</div>
        ))}
      </div>
      <h3 className="mt-6 text-base font-bold text-ink">Matching</h3>
      <p className="mt-2 text-sm text-muted">
        Opportunities are matched to users based on SDG focus, verified skills, location, availability and impact score.
        Higher PMS scores receive priority matching.
      </p>
    </div>
  );
}

function ProfilesDocs() {
  return (
    <div>
      <h2 className="font-display text-2xl font-extrabold text-ink">Profiles</h2>
      <p className="mt-3 text-sm text-muted leading-relaxed">
        MASAREEN supports five distinct profile types, each with tailored features and dashboards.
      </p>
      <div className="mt-6 space-y-3">
        {[
          { name: "Individual", icon: IconUsers, desc: "Personal impact profile. Post stories, join programs, earn coin." },
          { name: "NGO / Organization", icon: IconHandshake, desc: "Launch programs, manage teams, track SDG progress with funders dashboard." },
          { name: "Government", icon: IconFlag, desc: "Public program transparency, citizen audit trails, Egypt Vision 2030 tracking." },
          { name: "Media", icon: IconBookmark, desc: "Publish verified stories with POAI proof, interview system, media analytics." },
          { name: "Sports", icon: IconTrophy, desc: "Player impact profiles, youth academy tracking, community clinic verification." },
        ].map((p) => (
          <div key={p.name} className="flex gap-3 rounded-xl bg-canvas p-3">
            <span className="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-brand-50 text-brand"><p.icon size={16} /></span>
            <div>
              <p className="text-sm font-semibold text-ink">{p.name}</p>
              <p className="text-xs text-muted">{p.desc}</p>
            </div>
          </div>
        ))}
      </div>
      <h3 className="mt-6 text-base font-bold text-ink">Profile Strength (PMS)</h3>
      <p className="mt-2 text-sm text-muted">
        The Profile Membership Score rates completeness from 0–100 based on: bio, photo, verified email, SDG focus,
        programs joined, tasks completed and evidence submitted. Higher PMS unlocks better matching and visibility.
      </p>
    </div>
  );
}

function AdminDocs() {
  return (
    <div>
      <h2 className="font-display text-2xl font-extrabold text-ink">Admin Panel</h2>
      <p className="mt-3 text-sm text-muted leading-relaxed">
        The admin panel is restricted to ADMIN and SUPER_ADMIN roles. It provides platform-wide analytics, report
        generation and management tools.
      </p>
      <div className="mt-6 space-y-4">
        <Collapsible title="Reports Tab" defaultOpen>
          <ul className="list-disc pl-4 space-y-1">
            <li>User growth and retention</li>
            <li>Impact action volume by SDG</li>
            <li>Verification pipeline throughput</li>
            <li>Coin economy flow analysis</li>
            <li>Program completion rates</li>
          </ul>
        </Collapsible>
        <Collapsible title="R-based Analytics">
          <p className="mb-2">The platform integrates R for advanced statistical analysis:</p>
          <CodeBlock language="r" code={"# Example: Impact trend analysis\nlibrary(ggplot2)\ndata <- read.csv(\"impact_actions.csv\")\nggplot(data, aes(x=date, y=count, color=sdg)) +\n  geom_line() +\n  labs(title=\"Verified Actions Over Time\")"} />
        </Collapsible>
        <Collapsible title="Revenue Tracking">
          <p>Track coin brokerage fees, ad revenue, program funding and platform costs. Revenue dashboards update in real time.</p>
        </Collapsible>
      </div>
    </div>
  );
}

function ApiDocs() {
  return (
    <div>
      <h2 className="font-display text-2xl font-extrabold text-ink">API Reference</h2>
      <p className="mt-3 text-sm text-muted leading-relaxed">
        MASAREEN exposes a RESTful API under <code className="rounded bg-canvas px-1.5 py-0.5 text-xs font-mono">/api/v1/</code> for all platform operations.
      </p>
      <div className="mt-6 space-y-4">
        <Collapsible title="Authentication" defaultOpen>
          <CodeBlock code={"POST /api/v1/users/register\nBody: { \"email\": \"user@example.com\", \"full_name\": \"Amira\", \"password\": \"secureP@ss1\", \"role\": \"INDIVIDUAL\" }\n\nPOST /api/v1/users/login\nBody: { \"email\": \"...\", \"password\": \"...\" }\nResponse: { \"token\": \"jwt...\", \"user\": {...} }"} />
        </Collapsible>
        <Collapsible title="Feed">
          <CodeBlock code={"GET  /api/v1/feed?page=1&limit=20\nGET  /api/v1/feed/:postId\nPOST /api/v1/feed  (create post)\nPOST /api/v1/feed/:postId/like\nPOST /api/v1/feed/:postId/comment"} />
        </Collapsible>
        <Collapsible title="Verification">
          <CodeBlock code={"POST /api/v1/evidence/submit\nBody: { \"claim_text\": \"Planted 500 mangrove saplings\", \"evidence_urls\": [...], \"gps_lat\": 29.97 }\nResponse: { \"claim_id\": \"c_1847\", \"status\": \"VERIFYING\" }"} />
        </Collapsible>
        <Collapsible title="Wallet">
          <CodeBlock code={"GET  /api/v1/wallet/balance\nGET  /api/v1/wallet/history?page=1\nPOST /api/v1/wallet/transfer\nBody: { \"to_user_id\": \"u_42\", \"amount\": 500 }"} />
        </Collapsible>
        <Collapsible title="Programs">
          <CodeBlock code={"GET    /api/v1/programs\nPOST   /api/v1/programs\nGET    /api/v1/programs/:id\nPOST   /api/v1/programs/:id/join\nGET    /api/v1/programs/:id/tasks\nPOST   /api/v1/programs/:id/tasks"} />
        </Collapsible>
      </div>
    </div>
  );
}

function ArchitectureDocs() {
  return (
    <div>
      <h2 className="font-display text-2xl font-extrabold text-ink">Architecture</h2>
      <p className="mt-3 text-sm text-muted leading-relaxed">
        MASAREEN is built on a distributed microservice architecture designed for scalability, resilience and independent deployment.
      </p>
      <div className="mt-6 grid gap-3 sm:grid-cols-2">
        {[
          { name: "Gateway Service", tech: "Spring Cloud Gateway", role: "Auth, routing, rate limiting" },
          { name: "User Service", tech: "Spring Boot + PostgreSQL", role: "Registration, profiles, PMS scoring" },
          { name: "Feed Service", tech: "Spring Boot + Redis", role: "Posts, social graph, ranking" },
          { name: "Verification Service", tech: "Spring Boot + R", role: "POAI scoring, audit pipeline" },
          { name: "Coin Ledger", tech: "Spring Boot + PostgreSQL", role: "Wallets, transfers, brokerage" },
          { name: "Evidence Store", tech: "MinIO + PostgreSQL", role: "GPS, photos, tamper-evident bundles" },
          { name: "Programs Service", tech: "Spring Boot", role: "Program & task lifecycle" },
          { name: "Analytics Service", tech: "R + Plumber API", role: "Reports, dashboards, stats" },
        ].map((s) => (
          <div key={s.name} className="rounded-xl border border-line bg-white p-3">
            <p className="text-sm font-bold text-ink">{s.name}</p>
            <p className="text-[10px] font-semibold text-brand">{s.tech}</p>
            <p className="mt-1 text-xs text-muted">{s.role}</p>
          </div>
        ))}
      </div>
      <h3 className="mt-6 text-base font-bold text-ink">Tech Stack</h3>
      <div className="mt-3 flex flex-wrap gap-2">
        {["Java 21", "Spring Boot 3", "Spring Cloud", "PostgreSQL", "Redis", "Kafka", "MinIO", "R / Plumber", "Flutter", "React + Tailwind", "Docker", "Kubernetes"].map((t) => (
          <span key={t} className="rounded-full bg-brand-50 px-3 py-1 text-xs font-semibold text-brand-700">{t}</span>
        ))}
      </div>
    </div>
  );
}

/* ── map section id → component ──────────────────────────────────────────── */

const SECTION_MAP: Record<string, () => JSX.Element> = {
  overview: Overview,
  "getting-started": GettingStarted,
  feed: FeedDocs,
  verification: VerificationDocs,
  coin: CoinDocs,
  programs: ProgramsDocs,
  opportunities: OpportunitiesDocs,
  profiles: ProfilesDocs,
  admin: AdminDocs,
  api: ApiDocs,
  architecture: ArchitectureDocs,
};

/* ── page ────────────────────────────────────────────────────────────────── */

export default function DocsPage() {
  const [active, setActive] = useState("overview");
  const { t } = useI18n();

  useEffect(() => {
    const el = document.getElementById(`doc-section-${active}`);
    if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
  }, [active]);

  const Content = SECTION_MAP[active] ?? Overview;

  return (
    <div className="min-h-screen bg-white text-ink">
      <MarketingNav />

      <div className="mx-auto flex max-w-6xl gap-8 px-4 pt-28 pb-16">
        <Sidebar active={active} onSelect={setActive} />

        {/* Mobile nav */}
        <div className="lg:hidden fixed bottom-0 left-0 right-0 z-40 border-t border-line bg-white px-2 py-2 flex gap-1 overflow-x-auto">
          {SECTIONS.map((s) => (
            <button key={s.id} onClick={() => setActive(s.id)} className={`flex shrink-0 items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-semibold transition ${active === s.id ? "bg-brand text-white" : "bg-canvas text-muted"}`}>
              <s.icon size={14} /> {s.title}
            </button>
          ))}
        </div>

        <main className="min-w-0 flex-1">
          {SECTIONS.map((s) => {
            const Comp = SECTION_MAP[s.id] ?? Overview;
            return (
              <section key={s.id} id={`doc-section-${s.id}`} className="mb-12 scroll-mt-28">
                <Comp />
              </section>
            );
          })}
        </main>
      </div>

      <MarketingFooter />
    </div>
  );
}
