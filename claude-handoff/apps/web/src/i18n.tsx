import React, { createContext, useContext, useEffect, useState, useCallback } from "react";

export type Locale = "en" | "ar";

const DICT: Record<Locale, Record<string, string>> = {
  en: {
    "app.name": "MASAREN",
    "nav.feed": "Discover",
    "nav.dashboard": "Dashboard",
    "nav.programs": "Programs",
    "nav.tasks": "Tasks",
    "nav.evidence": "Evidence",
    "nav.passport": "Impact Passport",
    "nav.collaborate": "Collaborate",
    "nav.marketplace": "Marketplace",
    "nav.portfolio": "Portfolio",
    "nav.profile": "Profile",
    "nav.chat": "Assistant",
    "nav.admin": "Admin",
    "nav.notifications": "Notifications",
    "nav.reports": "Reports",
    "nav.billing": "Billing",
    "nav.wallet": "Wallet",
    "nav.ads": "Ads",
    "nav.payments": "Payments",
    "nav.revenue": "Profit & Fees",
    "action.signout": "Sign Out",
    "action.signin": "Sign In",
    "action.loadMore": "Load more impact",
    "action.apply": "Apply",
    "action.applied": "Applied",
    "feed.title": "Impact Discovery",
    "feed.empty": "No more impact stories right now.",
    "feed.loading": "Loading more impact…",
    "marketplace.title": "Opportunity Marketplace",
    "marketplace.empty": "No opportunities match your filters yet.",
    "marketplace.filter": "Filter by type",
    "common.all": "All",
    "lang.toggle": "العربية",
  },
  ar: {
    "app.name": "مَسَارِن",
    "nav.feed": "اكتشف",
    "nav.dashboard": "لوحة التحكم",
    "nav.programs": "البرامج",
    "nav.tasks": "المهام",
    "nav.evidence": "الأدلة",
    "nav.passport": "جواز الأثر",
    "nav.collaborate": "تعاون",
    "nav.marketplace": "السوق",
    "nav.portfolio": "المحفظة",
    "nav.profile": "الملف الشخصي",
    "nav.chat": "المساعد",
    "nav.admin": "الإدارة",
    "nav.notifications": "الإشعارات",
    "nav.reports": "التقارير",
    "nav.billing": "الفوترة",
    "nav.wallet": "المحفظة الرقمية",
    "nav.ads": "الإعلانات",
    "nav.payments": "المدفوعات",
    "nav.revenue": "الأرباح والرسوم",
    "action.signout": "تسجيل الخروج",
    "action.signin": "تسجيل الدخول",
    "action.loadMore": "تحميل المزيد من الأثر",
    "action.apply": "تقديم",
    "action.applied": "تم التقديم",
    "feed.title": "اكتشاف الأثر",
    "feed.empty": "لا مزيد من قصص الأثر حالياً.",
    "feed.loading": "جارٍ تحميل المزيد من الأثر…",
    "marketplace.title": "سوق الفرص",
    "marketplace.empty": "لا توجد فرص مطابقة لعوامل التصفية بعد.",
    "marketplace.filter": "تصفية حسب النوع",
    "common.all": "الكل",
    "lang.toggle": "English",
  },
};

interface I18nContextType {
  locale: Locale;
  dir: "ltr" | "rtl";
  t: (key: string) => string;
  setLocale: (l: Locale) => void;
  toggle: () => void;
}

const I18nContext = createContext<I18nContextType>({
  locale: "en",
  dir: "ltr",
  t: (k) => k,
  setLocale: () => {},
  toggle: () => {},
});

const STORAGE_KEY = "masaren_locale";

export const I18nProvider = ({ children }: { children: React.ReactNode }) => {
  const [locale, setLocaleState] = useState<Locale>(() => {
    const saved = localStorage.getItem(STORAGE_KEY) as Locale | null;
    return saved === "ar" || saved === "en" ? saved : "en";
  });

  const dir: "ltr" | "rtl" = locale === "ar" ? "rtl" : "ltr";

  useEffect(() => {
    document.documentElement.lang = locale;
    document.documentElement.dir = dir;
    localStorage.setItem(STORAGE_KEY, locale);
  }, [locale, dir]);

  const setLocale = useCallback((l: Locale) => setLocaleState(l), []);
  const toggle = useCallback(() => setLocaleState((p) => (p === "ar" ? "en" : "ar")), []);

  const t = useCallback((key: string) => DICT[locale][key] ?? DICT.en[key] ?? key, [locale]);

  return (
    <I18nContext.Provider value={{ locale, dir, t, setLocale, toggle }}>
      {children}
    </I18nContext.Provider>
  );
};

export const useI18n = () => useContext(I18nContext);
