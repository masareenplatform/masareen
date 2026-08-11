import React, { createContext, useContext, useEffect, useState, useCallback } from "react";

export type Locale = "en" | "ar";

const DICT: Record<Locale, Record<string, string>> = {
  en: {
    "app.name": "MASAREEN",
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
    "feed.emptySaved": "No saved posts yet — tap the bookmark on any post to save it here.",
    "feed.loading": "Loading more impact…",
    "feed.search": "Search impact, people, programs…",
    "search.people": "People",
    "search.programs": "Programs",
    "search.opportunities": "Opportunities",
    "search.noResults": "No matches found",
    "search.viewProfile": "View profile",
    "rail.people": "People to follow",
    "rail.trending": "Trending in impact",
    "rail.viewAll": "View all",
    "profile.card": "Profile",
    "profile.strength": "Profile strength",
    "profile.score": "PMS",
    "action.follow": "Follow",
    "action.following": "Following",
    "action.saved": "Saved",
    "action.save": "Save",
    "action.unfollow": "Unfollow",
    "marketplace.title": "Opportunity Marketplace",
    "marketplace.empty": "No opportunities match your filters yet.",
    "marketplace.filter": "Filter by type",
    "common.all": "All",
    "action.like": "Like",
    "action.comment": "Comment",
    "action.share": "Share",
    "action.send": "Send",
    "action.post": "Post",
    "action.posting": "Posting…",
    "action.writeComment": "Write a comment…",
    "action.noComments": "No comments yet.",
    "action.compose": "Create post",
    "action.attachImage": "Attach image",
    "action.attachVideo": "Attach video",
    "action.markAllRead": "Mark all as read",
    "post.placeholder": "Share an impact story, program, or evidence…",
    "post.kind.story": "Story",
    "post.kind.program": "Program",
    "post.kind.task": "Task",
    "post.kind.evidence": "Evidence",
    "post.kind.impact": "Impact",
    "profile.editCover": "Edit cover",
    "profile.changePhoto": "Change photo",
    "profile.edit": "Edit profile",
    "profile.noPosts": "No posts yet. Share your first impact story!",
    "feed.forYou": "For You",
    "feed.impact": "Impact",
    "feed.programs": "Programs",
    "feed.evidence": "Evidence",
    "feed.saved": "Saved",
    "feed.verified": "POAI · Verified",
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
    "feed.emptySaved": "لا توجد منشورات محفوظة بعد — اضغط على أيقونة الحفظ في أي منشور لحفظه هنا.",
    "feed.loading": "جارٍ تحميل المزيد من الأثر…",
    "feed.search": "ابحث عن الأثر، الأشخاص، البرامج…",
    "search.people": "الأشخاص",
    "search.programs": "البرامج",
    "search.opportunities": "الفرص",
    "search.noResults": "لا توجد نتائج مطابقة",
    "search.viewProfile": "عرض الملف الشخصي",
    "rail.people": "أشخاص لتتابعهم",
    "rail.trending": "رائج في الأثر",
    "rail.viewAll": "عرض الكل",
    "profile.card": "الملف الشخصي",
    "profile.strength": "قوة الملف",
    "profile.score": "نقاط التأثير",
    "action.follow": "متابعة",
    "action.following": "تتابع",
    "action.saved": "محفوظ",
    "action.save": "حفظ",
    "action.unfollow": "إلغاء المتابعة",
    "marketplace.title": "سوق الفرص",
    "marketplace.empty": "لا توجد فرص مطابقة لعوامل التصفية بعد.",
    "marketplace.filter": "تصفية حسب النوع",
    "common.all": "الكل",
    "action.like": "أعجبني",
    "action.comment": "تعليق",
    "action.share": "مشاركة",
    "action.send": "إرسال",
    "action.post": "نشر",
    "action.posting": "جارٍ النشر…",
    "action.writeComment": "اكتب تعليقاً…",
    "action.noComments": "لا تعليقات بعد.",
    "action.compose": "إنشاء منشور",
    "action.attachImage": "إرفاق صورة",
    "action.attachVideo": "إرفاق فيديو",
    "action.markAllRead": "تعيين الكل كمقروء",
    "post.placeholder": "شارك قصة أثر أو برنامجاً أو دليلاً…",
    "post.kind.story": "قصة",
    "post.kind.program": "برنامج",
    "post.kind.task": "مهمة",
    "post.kind.evidence": "دليل",
    "post.kind.impact": "أثر",
    "profile.editCover": "تعديل الغلاف",
    "profile.changePhoto": "تغيير الصورة",
    "profile.edit": "تعديل الملف",
    "profile.noPosts": "لا منشورات بعد. شارك أول قصة أثر لك!",
    "feed.forYou": "لك",
    "feed.impact": "الأثر",
    "feed.programs": "البرامج",
    "feed.evidence": "الأدلة",
    "feed.saved": "المحفوظ",
    "feed.verified": "POAI · موثق",
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
