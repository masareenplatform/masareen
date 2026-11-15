# MASAREEN - Current Platform Genome
Date: 2026-11-15
Working Dir: C:\Users\sherifrashwan\Downloads\masareen-cloudflare-pack

## Credentials
- GitHub: masareenplatform / <REDACTED — stored in GitHub/local secrets>
- Cloudflare: account f26ea50caf66866347631895dbab9d02, token <REDACTED — stored in GitHub Actions secret CLOUDFLARE_API_TOKEN>
- Resend: <REDACTED — stored in Cloudflare Worker secret RESEND_API_KEY> (send-only)
- R2: bucket masareen-landing

## Infrastructure
- Domain: masareen.com (CF zone 439b8b71f566af540131584d046f2e0d)
- Routes: masareen.com/api/*, www.masareen.com/api/*
- Worker: masareen deployed, version 8ac276fa-71c4-4822-b287-b2806fadbe28
- Cron: daily recognition sweep at 06:00 UTC
- D1: masareen a14a1b7c-a93e-4030-b58a-eaa908e61e37, migrations 001-040 in source
  (024�029 must be applied to remote before deploying this Worker)
- Static site: R2 masareen-landing (index, admin, mobile-auth, privacy, terms)
- APK: https://masareen.com/downloads/masareen.apk (99,350,022 bytes)
- Update manifest: GET /api/app/version (currently Android 0.4.4 build 9; source 0.4.6 build 11 pending publish, iOS 0.4.2 build 7); admin/agent publish via POST /api/v1/admin/ota

## Admin
- masareen.platform@gmail.com and sherif.moh.rashwan@gmail.com in ADMIN_EMAILS
- /admin rewrites to /admin.html
- Admin entity review: /api/v1/admin/entities (+ verdict endpoint)

## Mobile
- Source of truth: this package (`apps/mobile`)
- API base: https://masareen.com (override with --dart-define=API_BASE_URL=...)
- Flutter 3.44.5, Dart 3.12.2, Android SDK C:\Android\sdk, Java 17
- Version 0.4.13+18 (source); published OTA APK 0.4.13+18, SHA-256
  8F7E809BF183DE7257C6094FA9E5DDE38485913EDDA6774DFAC1E178D609746C
- Persistent floating bottom bar, per-tab nested navigators, sliding drawer
- Video: autoplay when 60% visible, one active video, global persisted mute
- Feed: infinite scroll fixed, role badges, calculators, intro cards
- Entity creation: priced, PENDING review, owner chips, admin queue
- Daily reward: default 10 MRC (capped at 500)
- OTA: Android in-app APK updater, force support, admin/agent publish, Shorebird config
- Courses: lessons, free/paid enrollment, author payout, locked previews
- Voice notes in composer + inline audio playback; feedback screen and admin review
- Event announcements, covers, member previews, double-tap heart, inline comments
- Live/VOD tooling: tools/media (mediaMTX + tunnel + NVENC HLS to R2)
- Live TV screen + admin operations center (moderation, AI/video, behavior, Live TV settings)
- Analytics: feed impressions, post dwell, video watch; admin CSV exports and behavior lookup
- Deep links via AppLinkRouter (conversation, post, user, admin tools, messages, opportunities)
- University discovery + rich institution profiles: linked courses, events (funding),
  capstone projects, opportunities, research stages, entity connections, follow
- Research hub: researchers share stages that publish to the feed and institution profile\n- Event hubs: participants, host verification, evidence, MRC rewards, interactive booths, leads, ratings, organizer reputation and enterprise dashboard\n- Podcast shows/episodes + VOD videos as first-class entities linked to events, programmes and institutions\n- Verified-only external sharing enforced in UI and backend (posts, events, booths, profiles, shows, videos)\n- Motion system: entrance/press/progress animations across events, TIYE hubs/booths/dashboard and sports\n- TIYE � ACU demo seed (migration 026): portfolio, booths, leads, podcast/VOD, programme, capstones, research, MRC
- Flutter analyze: clean; flutter test: 9 passing; Worker tests: 68 passing

## Production checks (2026-10-31)
- /api/health 200; /api/config 200; protected routes 401
- /privacy.html and /terms.html 200
- /downloads/masareen.apk 98,775,666 bytes
- /api/app/version reports android 0.4.3 build 8, size matches
- Emulator: feed pagination, video autoplay/global mute, role badges,
  calculators, intro cards, pending course creation with 50 MRC fee,
  OTA prompt (temporarily served build 9 then reverted to 8), wallet,
  courses, opportunities, profile, drawer, login
- 2026-10-31: 0.4.4 E2E OTA verified (installed 0.4.4+9, temporary
  manifest build 10 -> prompt -> R2 download -> package installer -> app
  reopened); manifest reset to build 9. /api/app/version reports 0.4.4/9
  and size 99,350,022. Feedback, paid lessons, event announcements and
  voice uploads covered by 57 Worker tests.
- 2026-11-15: Source at 0.4.13+18. Migrations 001-040 applied remotely (001-023 baselined; 024,025,027,028,029,030,031 applied). Worker deployed version 8ac276fa-71c4-4822-b287-b2806fadbe28 with entity impact market, verified newsroom, camera provenance, discovery feed, real TIYE galleries, structured evidence targets and deepfake/NSFW scanning. Android 0.4.13+18 and unsigned iOS 0.4.13+18 published in OTA (CodeMagic build 6afa090b3bf5092557048012, IPA at /downloads/masareen.ipa). Worker tests 68, Flutter analyze clean, Flutter tests 9.
- 2026-11-15: Live HLS verified at masareen.com/live/tv/index.m3u8. New 0.4.9+14 APK and OTA publish still pending.

## Pricing and verification
- Course 50, Event 25, Program 100, Project 75, Opportunity 30 MRC
- Pro free: Course, Event, Program
- Admin-created and test-mode entities auto-approve
- Rejected entities refund the creation fee and notify the owner

## Recognition
- Milestones 50/100/250/500/1000 impact points
- One official RECOGNITION post per member per new milestone
- Daily cron + POST /api/v1/admin/recognition/sweep
- Member receives a recognition notification

## GitHub
- Remote main is 2aae529 (FCM/Codemagic commits) and does NOT contain this
  work. Push is still pending user approval.

## To continue
1. Push these changes to GitHub (masareenplatform/masareen, main).
2. Replace the Shorebird placeholder app id and run a release/patch.
3. Configure Paymob secrets and verify the payment lifecycle.
4. Create a release keystore and Play Store AAB; complete Apple signing.
5. Run physical-device QA and add store screenshots/data-safety disclosures.
