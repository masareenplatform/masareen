# App Store readiness (do not start until approved)

## Preconditions
- Final iOS build passes `flutter analyze` and device smoke tests.
- Google Play closed testing is complete (or running in parallel).
- Privacy policy and terms are current at `https://masareen.com/privacy.html` and `/terms.html`.
- Support email and review contact are monitored.

## Build and upload
1. Trigger the `ios-ipa` CodeMagic workflow from the final commit.
2. For App Store distribution, add Apple signing credentials in CodeMagic (not in this repo).
3. Upload the signed `.ipa` with Transporter or Xcode Organizer.
4. Fill App Store Connect metadata: name, subtitle, description, keywords, screenshots, privacy nutrition labels, age rating, review notes.
5. Add internal TestFlight testers; then external TestFlight review if required.
6. Submit for App Store review only after explicit approval.

## Required review notes
- Demo account credentials for the reviewer.
- Explanation of user-generated content moderation and reporting.
- Explanation of impact verification and evidence capture.
- Explanation of MRC virtual currency (no cash value).
- Support URL and contact.

## Deferred
- Do not submit the App Store build until the owner says the testing phase is finished.
- Do not change bundle identifiers or signing team without approval.
