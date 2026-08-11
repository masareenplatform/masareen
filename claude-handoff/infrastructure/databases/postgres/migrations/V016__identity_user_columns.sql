-- MASAREN Identity — reconcile users/user_profiles with the ORM model.
-- Migration V016
-- The SQLAlchemy ORM (UserORM / UserProfileORM) references several columns that
-- were never added to the live schema, causing GET /users/{id} to 500 with
-- "column users.email_verified does not exist" (and friends). This migration
-- adds every missing column idempotently so the running dev DB matches the code.

-- ── users ────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='hashed_password') THEN
    ALTER TABLE users ADD COLUMN hashed_password VARCHAR(255) NOT NULL DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='email_verified') THEN
    ALTER TABLE users ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='phone_verified') THEN
    ALTER TABLE users ADD COLUMN phone_verified BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pms_score') THEN
    ALTER TABLE users ADD COLUMN pms_score DOUBLE PRECISION NOT NULL DEFAULT 0.0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='certificate_count') THEN
    ALTER TABLE users ADD COLUMN certificate_count INTEGER NOT NULL DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='impact_asset_count') THEN
    ALTER TABLE users ADD COLUMN impact_asset_count INTEGER NOT NULL DEFAULT 0;
  END IF;
END $$;

-- ── user_profiles ────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_profiles' AND column_name='cover_url') THEN
    ALTER TABLE user_profiles ADD COLUMN cover_url VARCHAR(500);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_profiles' AND column_name='latitude') THEN
    ALTER TABLE user_profiles ADD COLUMN latitude DOUBLE PRECISION;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_profiles' AND column_name='longitude') THEN
    ALTER TABLE user_profiles ADD COLUMN longitude DOUBLE PRECISION;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_profiles' AND column_name='target_audience') THEN
    ALTER TABLE user_profiles ADD COLUMN target_audience VARCHAR(50);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_profiles' AND column_name='gallery_ids') THEN
    ALTER TABLE user_profiles ADD COLUMN gallery_ids UUID[] DEFAULT '{}';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_profiles' AND column_name='followers_count') THEN
    ALTER TABLE user_profiles ADD COLUMN followers_count INTEGER NOT NULL DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_profiles' AND column_name='following_count') THEN
    ALTER TABLE user_profiles ADD COLUMN following_count INTEGER NOT NULL DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_profiles' AND column_name='website') THEN
    ALTER TABLE user_profiles ADD COLUMN website VARCHAR(500);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_profiles' AND column_name='social_links') THEN
    ALTER TABLE user_profiles ADD COLUMN social_links JSONB DEFAULT '{}';
  END IF;
END $$;
