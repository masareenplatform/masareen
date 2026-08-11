import { Navigate, Outlet } from "react-router-dom";
import { useAuth } from "../../store/authStore";
import type { User } from "../../types";

interface RequireRoleProps {
  roles: Array<User["role"]>;
}

/**
 * Nested-route guard for role-restricted sections (e.g. /admin).
 * Assumes it renders under <Layout /> (via <Route element={<Layout />}>),
 * so authentication itself is already guaranteed by the time this runs —
 * this only adds the role check on top.
 */
export default function RequireRole({ roles }: RequireRoleProps) {
  const { user } = useAuth();
  if (!user || !roles.includes(user.role)) {
    return <Navigate to="/dashboard" replace />;
  }
  return <Outlet />;
}
