import { Routes, Route, Navigate, Link } from "react-router-dom";
import type { ReactElement } from "react";
import { AuthProvider, useAuth } from "./store/authStore";
import Layout from "./components/layout/Layout";
import ErrorBoundary from "./components/common/ErrorBoundary";
import LoginPage from "./pages/LoginPage";
import RegisterPage from "./pages/RegisterPage";
import LandingPage from "./pages/LandingPage";
import DashboardPage from "./pages/DashboardPage";
import ProgramsPage from "./pages/ProgramsPage";
import TasksPage from "./pages/TasksPage";
import EvidencePage from "./pages/EvidencePage";
import PassportPage from "./pages/PassportPage";
import OpportunitiesPage from "./pages/OpportunitiesPage";
import PortfolioPage from "./pages/PortfolioPage";
import ProfilePage from "./pages/ProfilePage";
import PersonnelProfilePage from "./pages/PersonnelProfilePage";
import InstitutionProfilePage from "./pages/InstitutionProfilePage";
import AdminPage from "./pages/AdminPage";
import HowItWorksPage from "./pages/HowItWorksPage";
import PricingPage from "./pages/PricingPage";
import AboutPage from "./pages/AboutPage";
import ResourcesPage from "./pages/ResourcesPage";
import SolutionsPage from "./pages/SolutionsPage";
import VerificationPage from "./pages/VerificationPage";
import NotificationsPage from "./pages/NotificationsPage";
import ReportsPage from "./pages/ReportsPage";
import BillingPage from "./pages/BillingPage";
import ChatPage from "./pages/ChatPage";
import FeedPage from "./pages/FeedPage";
import CollaboratePage from "./pages/CollaboratePage";
import WalletPage from "./pages/WalletPage";
import AdsPage from "./pages/AdsPage";
import PaymentsPage from "./pages/PaymentsPage";
import RevenuePage from "./pages/RevenuePage";
import ChallengesPage from "./pages/ChallengesPage";
import GoogleAuthCallback from "./pages/GoogleAuthCallback";
import OnboardingPage from "./pages/OnboardingPage";
import PresentationPage from "./pages/PresentationPage";
import DocsPage from "./pages/DocsPage";
import FinancialReportPage from "./pages/FinancialReportPage";

export default function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <Routes>
          {/* Public routes */}
          <Route path="/" element={<LandingPage />} />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/oauth/google/callback" element={<GoogleAuthCallback />} />
          <Route path="/onboarding" element={<OnboardingPage />} />
          <Route path="/how-it-works" element={<HowItWorksPage />} />
          <Route path="/pricing" element={<PricingPage />} />
          <Route path="/about" element={<AboutPage />} />
          <Route path="/resources" element={<ResourcesPage />} />
          <Route path="/solutions/:segment" element={<SolutionsPage />} />
          <Route path="/verification" element={<VerificationPage />} />
          <Route path="/presentation" element={<PresentationPage />} />
          <Route path="/docs" element={<DocsPage />} />
          <Route path="/financialreport" element={<FinancialReportPage />} />

          {/* Authenticated app shell, RequireAuth wraps all children */}
          <Route element={<RequireAuth><Layout /></RequireAuth>}>
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="/feed" element={<FeedPage />} />
            <Route path="/programs" element={<ProgramsPage />} />
            <Route path="/tasks" element={<TasksPage />} />
            <Route path="/evidence" element={<EvidencePage />} />
            <Route path="/passport" element={<PassportPage />} />
            <Route path="/opportunities" element={<OpportunitiesPage />} />
            <Route path="/portfolio" element={<PortfolioPage />} />
            <Route path="/profile" element={<ProfilePage />} />
            <Route path="/people" element={<PeopleRedirect />} />
            <Route path="/personnel/:id" element={<PersonnelProfilePage />} />
            <Route path="/institution/:id" element={<InstitutionProfilePage />} />
            <Route path="/admin" element={<RequireRole roles={["ADMIN", "SUPER_ADMIN"]}><AdminPage /></RequireRole>} />
            <Route path="/notifications" element={<NotificationsPage />} />
            <Route path="/reports" element={<ReportsPage />} />
            <Route path="/billing" element={<BillingPage />} />
            <Route path="/chat" element={<ChatPage />} />
            <Route path="/collaborate" element={<CollaboratePage />} />
            <Route path="/wallet" element={<WalletPage />} />
            <Route path="/ads" element={<AdsPage />} />
            <Route path="/payments" element={<PaymentsPage />} />
            <Route path="/revenue" element={<RequireRole roles={["ADMIN", "SUPER_ADMIN"]}><RevenuePage /></RequireRole>} />
            <Route path="/challenges" element={<ChallengesPage />} />
          </Route>

          {/* 404 catch-all */}
          <Route path="*" element={<NotFoundPage />} />
        </Routes>
      </AuthProvider>
    </ErrorBoundary>
  );
}

function RequireAuth({ children }: { children: ReactElement }) {
  const { isAuthenticated, loading } = useAuth();
  if (loading) return (
    <div className="grid h-screen place-items-center bg-aurora">
      <div className="flex flex-col items-center gap-4 animate-fade-in">
        <div className="relative h-10 w-10">
          <div className="absolute inset-0 rounded-full border-4 border-navy-200" />
          <div className="absolute inset-0 rounded-full border-4 border-brand border-t-transparent animate-spin" />
        </div>
        <p className="text-sm font-medium text-muted animate-pulse-soft">Loading…</p>
      </div>
    </div>
  );
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  return children;
}

function RequireRole({ roles, children }: { roles: string[]; children: ReactElement }) {
  const { user, isAuthenticated } = useAuth();
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  if (user && !roles.includes(user.role)) return <Navigate to="/feed" replace />;
  return children;
}

function PeopleRedirect() {
  const { user, isAuthenticated } = useAuth();
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  if (!user?.id) return <Navigate to="/feed" replace />;
  return <Navigate to={`/personnel/${user.id}`} replace />;
}

function NotFoundPage() {
  return (
    <div className="grid min-h-screen place-items-center bg-aurora px-4 text-center">
      <div className="animate-fade-up">
        <div className="relative mb-6">
          <p className="text-[120px] font-bold text-brand/8 leading-none select-none">404</p>
          <div className="absolute inset-0 grid place-items-center">
            <span className="text-6xl">🔍</span>
          </div>
        </div>
        <h1 className="text-display-sm text-ink mb-2">Page not found</h1>
        <p className="text-body-md text-muted max-w-md mx-auto">
          The page you're looking for doesn't exist or has been moved. Let's get you back on track.
        </p>
        <div className="mt-8 flex items-center justify-center gap-3">
          <Link to="/feed" className="btn-primary">Go to Feed</Link>
          <button onClick={() => window.history.back()} className="btn-ghost">Go Back</button>
        </div>
      </div>
    </div>
  );
}
