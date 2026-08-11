// Modern, minimal line icons (Instagram/Lucide-style) as inline SVG components.
// All inherit `currentColor` so they adapt to the surrounding text colour.
import React from "react";

type P = { className?: string; size?: number };

const base = (size = 22): React.SVGProps<SVGSVGElement> => ({
  width: size,
  height: size,
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.8,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
});

export const IconHome = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M3 10.5 12 3l9 7.5" /><path d="M5 9.5V21h14V9.5" /><path d="M9.5 21v-6h5v6" /></svg>
);
export const IconCompass = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><circle cx="12" cy="12" r="9" /><path d="m15.5 8.5-2 5-5 2 2-5 5-2z" /></svg>
);
export const IconBell = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M6 9a6 6 0 0 1 12 0c0 5 2 6 2 6H4s2-1 2-6" /><path d="M10 20a2 2 0 0 0 4 0" /></svg>
);
export const IconUser = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><circle cx="12" cy="8" r="4" /><path d="M4 20c0-4 4-6 8-6s8 2 8 6" /></svg>
);
export const IconUsers = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><circle cx="9" cy="8" r="3.5" /><path d="M3 20c0-3.5 3-5.5 6-5.5s6 2 6 5.5" /><path d="M16 5a3.5 3.5 0 0 1 0 7" /><path d="M21 20c0-3-2-5-5-5" /></svg>
);
export const IconMessage = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M21 12a8 8 0 0 1-11.5 7.2L4 20l1-4.5A8 8 0 1 1 21 12z" /></svg>
);
export const IconSearch = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><circle cx="11" cy="11" r="7" /><path d="m20 20-3.2-3.2" /></svg>
);
export const IconPlus = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M12 5v14M5 12h14" /></svg>
);
export const IconImage = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><rect x="3" y="4" width="18" height="16" rx="3" /><circle cx="9" cy="9.5" r="1.6" /><path d="m4 18 5-5 4 4 3-3 4 4" /></svg>
);
export const IconVideo = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><rect x="3" y="6" width="13" height="12" rx="3" /><path d="m16 10 5-3v10l-5-3" /></svg>
);
export const IconTask = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><rect x="4" y="4" width="16" height="16" rx="3" /><path d="m8.5 12 2.5 2.5 4.5-5" /></svg>
);
export const IconProgram = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M12 3 3 8l9 5 9-5-9-5z" /><path d="m3 13 9 5 9-5" /></svg>
);
export const IconEvidence = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M3 8 12 3l9 5v8l-9 5-9-5V8z" /><circle cx="12" cy="12" r="2.4" /></svg>
);
export const IconImpact = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M11 20A7 7 0 0 1 4 13c0-4 3-7 9-9 1 6-2 9-6 9a4 4 0 0 0 4 7z" /></svg>
);
export const IconMenu = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M4 7h16M4 12h16M4 17h16" /></svg>
);
export const IconSend = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M22 2 11 13" /><path d="M22 2 15 22l-4-9-9-4 20-7z" /></svg>
);
export const IconHeart = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M12 20s-7-4.5-9.5-9C1 8 2.5 4.5 6 4.5c2 0 3.2 1.2 4 2.5.8-1.3 2-2.5 4-2.5 3.5 0 5 3.5 3.5 6.5C19 15.5 12 20 12 20z" /></svg>
);
export const IconComment = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M21 12a8 8 0 0 1-11.5 7.2L4 20l1-4.5A8 8 0 1 1 21 12z" /><path d="M8.5 11h7M8.5 14h4" /></svg>
);
export const IconShare = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><circle cx="6" cy="12" r="2.4" /><circle cx="18" cy="6" r="2.4" /><circle cx="18" cy="18" r="2.4" /><path d="m8.2 10.8 7.6-3.6M8.2 13.2l7.6 3.6" /></svg>
);
export const IconTrophy = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M7 4h10v4a5 5 0 0 1-10 0V4z" /><path d="M7 5H4v2a3 3 0 0 0 3 3M17 5h3v2a3 3 0 0 1-3 3M9 14h6M10 14v3h4v-3M8 20h8" /></svg>
);
export const IconFlag = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M5 21V4M5 4h12l-2 4 2 4H5" /></svg>
);
export const IconStar = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="m12 3 2.6 5.5 6 .8-4.4 4.2 1.1 6L12 17l-5.3 2.5 1.1-6L3.4 9.3l6-.8L12 3z" /></svg>
);
export const IconBookmark = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M6 4h12v16l-6-4-6 4V4z" /></svg>
);
export const IconCover = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><rect x="3" y="4" width="18" height="16" rx="3" /><path d="m3 16 5-5 4 4 3-3 6 6" /><circle cx="9" cy="9" r="1.6" /></svg>
);
export const IconSettings = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><circle cx="12" cy="12" r="3" /><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2" /></svg>
);
export const IconWallet = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><rect x="3" y="6" width="18" height="13" rx="3" /><path d="M3 10h18" /><circle cx="17" cy="14.5" r="1.3" /></svg>
);
export const IconAds = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="m4 10 8-5 8 5-8 9-8-9z" /><path d="M4 10h16" /></svg>
);
export const IconAdmin = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M12 3 5 6v5c0 4 3 7 7 8 4-1 7-4 7-8V6l-7-3z" /><path d="m9 12 2 2 4-4" /></svg>
);
export const IconReports = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M4 20V4" /><path d="M4 20h16" /><path d="M8 16v-5M12 16V8M16 16v-9" /></svg>
);
export const IconBilling = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><rect x="5" y="3" width="14" height="18" rx="3" /><path d="M5 8h14M9 13h6" /></svg>
);
export const IconLogout = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M14 4h4v16h-4" /><path d="M10 12h9M16 9l3 3-3 3" /></svg>
);
export const IconClose = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M6 6l12 12M18 6 6 18" /></svg>
);
export const IconCamera = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M4 8h3l1.5-2h7L17 8h3v12H4z" /><circle cx="12" cy="13" r="3.2" /></svg>
);
export const IconTrending = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M3 17 9 11l4 4 8-8" /><path d="M21 7h-5M21 7v5" /></svg>
);
export const IconSparkles = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M12 3l1.5 4.5L18 9l-4.5 1.5L12 15l-1.5-4.5L6 9l4.5-1.5L12 3z" /><path d="M18 14l.8 2.2L21 17l-2.2.8L18 20l-.8-2.2L15 17l2.2-.8L18 14z" /></svg>
);
export const IconCheck = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="m5 12 5 5 9-11" /></svg>
);
export const IconGlobe = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><circle cx="12" cy="12" r="9" /><path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18" /></svg>
);
export const IconShield = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M12 3 5 6v5c0 4 3 7 7 8 4-1 7-4 7-8V6l-7-3z" /><path d="m9 12 2 2 4-4" /></svg>
);
export const IconArrowRight = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M5 12h14M13 6l6 6-6 6" /></svg>
);
export const IconDownload = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M12 4v10m0 0 4-4m-4 4-4-4" /><path d="M5 19h14" /></svg>
);
export const IconBadge = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M12 2 4 5v6c0 5 3.5 8.5 8 9 4.5-.5 8-4 8-9V5l-8-3z" /><path d="m9 12 2 2 4-4" /></svg>
);
export const IconHandshake = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M3 11 8 7l4 3 4-3 5 4" /><path d="m3 13 3 3 3-3 3 3 3-3 3 3" /><path d="M3 11v6h6M21 11v6h-6" /></svg>
);
export const IconMoney = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><rect x="2" y="6" width="20" height="12" rx="3" /><circle cx="12" cy="12" r="2.4" /><path d="M14.5 10.2c-.6-.5-1.5-.7-2.5-.7s-1.9.2-2.5.7M9.5 13.8c.6.5 1.5.7 2.5.7s1.9-.2 2.5-.7" /></svg>
);
export const IconChat = ({ className, size }: P) => (
  <svg {...base(size)} className={className}><path d="M21 12a8 8 0 0 1-11.5 7.2L4 20l1-4.5A8 8 0 1 1 21 12z" /><path d="M8.5 11h7M8.5 14h4" /></svg>
);
export const IconGoogle = ({ className, size = 18 }: P) => (
  <svg width={size} height={size} viewBox="0 0 24 24" className={className} aria-hidden>
    <path fill="#4285F4" d="M22.5 12.2c0-.7-.06-1.4-.18-2.06H12v3.9h5.9a5.05 5.05 0 0 1-2.19 3.32v2.76h3.54C21.04 18.3 22.5 15.55 22.5 12.2z"/>
    <path fill="#34A853" d="M12 23c2.95 0 5.43-.98 7.24-2.66l-3.54-2.76c-.98.66-2.24 1.05-3.7 1.05-2.85 0-5.26-1.92-6.12-4.5H2.24v2.83A11 11 0 0 0 12 23z"/>
    <path fill="#FBBC05" d="M5.88 14.13a6.6 6.6 0 0 1 0-4.26V7.04H2.24a11 11 0 0 0 0 9.92l3.64-2.83z"/>
    <path fill="#EA4335" d="M12 4.76c1.6 0 3.04.55 4.18 1.63l3.13-3.13A11 11 0 0 0 12 1 11 11 0 0 0 2.24 7.04l3.64 2.83C6.74 6.68 9.15 4.76 12 4.76z"/>
  </svg>
);
export const IconGroup = IconUsers;
