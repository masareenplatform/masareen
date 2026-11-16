# Google Play closed testing runbook

## What is already ready
- Public tester waitlist at `https://masareen.com/#testers`.
- D1 `testers` table with name, email, country, device, Android version, source, status and invite timestamp.
- Admin page: `https://masareen.com/admin.html` → **Play testers**.
- Admin can mark testers `pending`, `invited`, `active` or `declined`.
- Tester CSV export for Play Console: `https://masareen.com/api/admin/testers.csv`.
- Registered-user CSV export: `https://masareen.com/api/admin/export/users.csv`.
- New admin action: **Email testing link** sends the Play closed-test opt-in URL to pending/invited testers and marks them invited.
- Email delivery uses Resend (`RESEND_API_KEY`, `MAIL_FROM`).

## When the Google Play developer account is purchased
1. Create the app in Play Console.
2. Upload the signed Android App Bundle (`.aab`) to **Closed testing**.
3. Add the 20+ tester Google accounts under **Testers**.
   - Use the emails from **Play testers** or the users CSV.
   - Each tester must use the same Google account on the Play Store.
4. Copy the **opt-in URL** (`https://play.google.com/apps/testing/...`).
5. Open `https://masareen.com/admin.html`, go to **Play testers**, click **Email testing link**, paste the URL.
6. Ask testers to install, open the app, and keep it installed for at least 14 days.
7. Track **invited → active** in the admin testers tab.
8. After the required testing period, apply for production access in Play Console.

## Tester instructions to send
- Open the Play closed-test link from the email.
- Accept the test, then install MASAREEN from Google Play.
- Sign in with the same Google account and use the app for 14 days.
- Post one update, rate one impact item, follow one profile, and send feedback.

## App Store phase (later, on request)
- Build/upload the signed iOS archive through Codemagic/Transporter.
- Complete App Store privacy nutrition labels, screenshots and review notes.
- Add TestFlight testers before App Store review.
- Do not start this phase until explicitly requested.
