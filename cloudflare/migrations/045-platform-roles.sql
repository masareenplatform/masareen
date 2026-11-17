-- Platform-level roles assigned by existing admins.
ALTER TABLE users ADD COLUMN platform_role TEXT;
CREATE INDEX IF NOT EXISTS idx_users_platform_role ON users(platform_role);
