import { Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider } from "./store/authStore";
import Layout from "./components/layout/Layout";
import RequireRole from "./components/layout/RequireRole";
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
import AdminPage from "./pages/AdminPage";
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

export default function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <Routes>
          <Route path="/" element={<LandingPage />} />
          <Route path="/landing" element={<LandingPage />} />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route element={<Layout />}>
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="/programs" element={<ProgramsPage />} />
            <Route path="/tasks" element={<TasksPage />} />
            <Route path="/evidence" element={<EvidencePage />} />
            <Route path="/passport" element={<PassportPage />} />
            <Route path="/opportunities" element={<OpportunitiesPage />} />
            <Route path="/portfolio" element={<PortfolioPage />} />
            <Route path="/profile" element={<ProfilePage />} />
            <Route element={<RequireRole roles={["ADMIN", "SUPER_ADMIN"]} />}>
              <Route path="/admin" element={<AdminPage />} />
            </Route>
            <Route path="/notifications" element={<NotificationsPage />} />
            <Route path="/reports" element={<ReportsPage />} />
            <Route path="/billing" element={<BillingPage />} />
            <Route path="/chat" element={<ChatPage />} />
            <Route path="/feed" element={<FeedPage />} />
            <Route path="/collaborate" element={<CollaboratePage />} />
            <Route path="/wallet" element={<WalletPage />} />
            <Route path="/ads" element={<AdsPage />} />
            <Route path="/payments" element={<PaymentsPage />} />
            <Route path="/revenue" element={<RevenuePage />} />
          </Route>
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </AuthProvider>
    </ErrorBoundary>
  );
}
