---
name: app-store-submission
description: End-to-end submission of a native iOS/iPadOS app to the App Store, driven almost entirely by the App Store Connect (ASC) API + Xcode CLI (no manual portal clicking where avoidable). Use when archiving, uploading a build, setting metadata/screenshots/pricing, and submitting an app for review. Covers the hard-won gotchas plus a field-tested App Review rejection checklist (real-app screenshots, in-app account deletion, working demo account).
license: MIT
metadata:
  version: "2.1.0"
---

# App Store Submission (API-first)

Submit a native iOS/iPadOS app to the App Store with the **App Store Connect (ASC) API**
and the **Xcode command line**, doing as much as possible programmatically. This skill
captures a complete, repeatable workflow plus the non-obvious blockers that waste hours.

Use the bundled scripts in [scripts/](scripts/). Per-project values and the metadata copy
go in the project's `.env` (see [.env.example](.env.example)) and the template at the end of
this doc. Placeholders below use `<ANGLE_BRACKETS>` — replace them with your own values.

## What the API CAN and CANNOT do

**API can:** create/read the app record, set category & pricing, set version metadata
(description, keywords, subtitle, promo text, support/marketing URLs, copyright,
**privacyPolicyUrl**), create the **App Review contact**, upload builds (via `altool`),
attach a build, upload screenshots, create a review submission, and **submit for review**.

**API CANNOT (must be done once in the web UI):**
- **App Privacy "nutrition label"** (`appDataUsages`). There is **no public API** — the
  app resource exposes no `appDataUsages` relationship; every path 404s. Set it in the UI:
  *App Privacy → Get Started → declare what you collect (or "No, we do not collect data") → Publish*.
- **Age rating / content rights** declarations are also effectively UI-only.
- **Deleting an empty draft review submission** returns 403 — harmless, leave or delete in UI.

Plan for one short UI visit per app for the App Privacy publish. Everything else is scriptable.

## Prerequisites (one-time per Apple account)

1. **Paid Apple Developer Program** membership (accept the latest PLA in the portal).
2. **Generate the App Store Connect API key — the ONE unavoidable portal step.**
   An ASC API key **cannot be created via API** (chicken-and-egg); the account holder must
   generate it once in the web UI. After that, this skill drives everything else without
   touching the portal. The exact clicks:

   > 1. Sign in at <https://appstoreconnect.apple.com> as the **Account Holder / Admin**.
   > 2. **Users and Access** → top tab **Integrations** → **App Store Connect API** →
   >    **Team Keys**.
   > 3. Click **+** (Generate API Key). Name it (e.g. "automation"), set **Access = Admin**
   >    (or at least **App Manager**), **Generate**.
   > 4. **Download** the **`AuthKey_<ASC_KEY_ID>.p8`** — this is offered **only once**. Save it to
   >    `~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8` then `chmod 600` it.
   > 5. Copy the **Key ID** (the 10-char id in the row) and the **Issuer ID** (UUID shown
   >    above the keys list).

   These three values are all the skill needs. If a key is ever lost/leaked, **Revoke** it
   in the same screen and generate a new one.
3. Put the **Key ID** and **Issuer ID** in a local **`.env`** (gitignored) and point
   `ASC_PRIVATE_KEY_PATH` at the `.p8`. See [.env.example](.env.example). The `.p8` lives
   outside the repo and is **never** committed (`.gitignore` excludes `.env` and `*.p8`).

```bash
# .env  (gitignored)
ASC_KEY_ID=<ASC_KEY_ID>
ASC_ISSUER_ID=<ASC_ISSUER_ID>            # xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ASC_PRIVATE_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8
```

Load it before running scripts: `set -a; source .env; set +a`

## The workflow

### 0. Pre-flight code checklist (in the repo)
- App icon **1024×1024, no alpha** in the asset catalog.
- `CFBundleShortVersionString` (marketing, e.g. `1.0`) and `CFBundleVersion` (build, integer,
  **bump on every upload**).
- `ITSAppUsesNonExemptEncryption = false` in Info.plist (skips the export-compliance prompt)
  — only if you use no non-exempt crypto.
- Usage-description strings for every permission (`NSMicrophoneUsageDescription`, etc.).
- `UIRequiredDeviceCapabilities = arm64` (never the legacy `armv7`).
- **`PrivacyInfo.xcprivacy`** privacy manifest (tracking false, collected types, required-reason APIs).
- For **iPad-only**: `TARGETED_DEVICE_FAMILY = 2`. For iPhone-only: `1`. Universal: `1,2`.
- **Per-config entitlements** if using CloudKit/push: Debug → `aps-environment=development`,
  Release → `production`.

### 1. Archive + upload the build (Xcode CLI)
Replace `<YourApp>.xcodeproj` and scheme `<YourApp>` with your project's names.

> **Optional pattern — XcodeGen.** If you generate the Xcode project with
> [XcodeGen](https://github.com/yonaskolb/XcodeGen) from a `project.yml`, regenerate it first
> (`xcodegen generate`) so version/build/bundle id/device family live in one source of truth,
> and edit `project.yml` instead of the `.pbxproj`. This is entirely optional — a hand-managed
> `.xcodeproj` works the same way for everything below.

```bash
# xcodegen generate          # only if you use XcodeGen (produces <YourApp>.xcodeproj)
xcodebuild -project <YourApp>.xcodeproj -scheme <YourApp> -configuration Release \
  -archivePath /tmp/<YourApp>.xcarchive archive
xcodebuild -exportArchive -archivePath /tmp/<YourApp>.xcarchive \
  -exportPath /tmp/export -exportOptionsPlist ExportOptions.plist   # method: app-store
xcrun altool --validate-app -f /tmp/export/<YourApp>.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
xcrun altool --upload-app   -f /tmp/export/<YourApp>.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
```
`altool` reads the `.p8` from `~/.appstoreconnect/private_keys/` automatically (the file is
`AuthKey_<ASC_KEY_ID>.p8`). Manual signing: set the **`<DISTRIBUTION_IDENTITY>`** signing
identity (e.g. "Apple Distribution: <Your Name>") and the **`<PROVISIONING_PROFILE>`** profile
in `ExportOptions.plist`. Build processing takes ~5–30 min; poll until state is `VALID`.

### 2. Everything else (ASC API)
Use [scripts/asc_submit.py](scripts/asc_submit.py) — it loads `.env`, mints a JWT via
[scripts/asc_jwt.swift](scripts/asc_jwt.swift), and exposes subcommands:

```bash
python3 scripts/asc_submit.py status                 # app id, version, build, blockers
python3 scripts/asc_submit.py set-metadata           # copyright, privacyPolicyUrl, URLs
python3 scripts/asc_submit.py review-contact         # App Review contact (required)
python3 scripts/asc_submit.py attach-build  --build 2
python3 scripts/asc_submit.py screenshots   --type APP_IPAD_PRO_3GEN_129 a.png b.png
python3 scripts/asc_submit.py submit                 # create review submission + submit
```

### 3. Submit for review
`submit` creates a `reviewSubmission`, adds the version as a `reviewSubmissionItem`, then
PATCHes `submitted=true`. On success the version state becomes `WAITING_FOR_REVIEW`. The
command prints any blocker codes returned in `associatedErrors`.

### 4. CloudKit Production schema deploy (if the app uses CloudKit/SwiftData+CloudKit)
**Not a review blocker, but ships broken sync if skipped.** App Store builds use the
**Production** CloudKit environment; the schema you developed against is in **Development**.
In **CloudKit Console → your container → Schema → Record Types → Deploy Schema Changes…**,
review the Development→Production diff and **Deploy**.
- A record type only exists in the schema **after a record of that type was created** in the
  Development environment. Production **cannot auto-create** new record types. So if a model
  was never exercised in dev (e.g. a rarely-used record type), its type is **absent** and
  that data won't sync until you create one record in a Debug build and **re-deploy**.
- **If your app has no CloudKit** (e.g. data lives on a backend REST API), skip this step.

## Submission blockers cheat-sheet (the 409 `associatedErrors`)

| Blocker code / message | Fix |
|---|---|
| `appInfoLocalizations … privacyPolicyUrl` required | PATCH `appInfoLocalizations/{id}` `privacyPolicyUrl` |
| `appStoreVersions … copyright` required | PATCH `appStoreVersions/{id}` `copyright` (e.g. `2026 <Your Org>`) |
| `appStoreReviewDetail … was not found` | POST `appStoreReviewDetails` with contact name/phone/email, `demoAccountRequired` |
| `APP_DATA_USAGES_REQUIRED` | **UI-only**: App Privacy → publish "Data Not Collected" (or fill labels) |
| `SCREENSHOT_REQUIRED.APP_IPHONE_65` | See the iPhone-screenshot quirk below |

## Gotchas (the time-savers)

- **iPhone 6.5" screenshot demanded for an iPad-only app.** The API submission validator
  spuriously requires an `APP_IPHONE_65` screenshot even when the binary is `UIDeviceFamily=2`.
  The **web UI** usually won't ask, but the **API** will. Fastest unblock: generate valid
  1242×2688 (or 1284×2778) images and upload them to an `APP_IPHONE_65` set —
  [scripts/make_iphone_screenshot.swift](scripts/make_iphone_screenshot.swift) frames an
  existing iPad capture on a branded gradient so it looks intentional, not letterboxed.
  Harmless for an iPad-only listing (the binary still determines device compatibility).
- **A stale earlier build keeps the app "universal."** If build 1 was uploaded universal
  (before you set `TARGETED_DEVICE_FAMILY=2`) and is still `VALID`, expire it
  (`PATCH /v1/builds/{id}` `expired=true`) so it stops influencing device support.
- **Screenshot upload is a 3-step dance**, not a single PUT: (1) `POST /v1/appScreenshots`
  reserve with `fileSize`+`fileName` → returns `uploadOperations`; (2) PUT the bytes to each
  operation's `url` with its `requestHeaders`; (3) `PATCH /v1/appScreenshots/{id}`
  `uploaded=true` + `sourceFileChecksum` = **MD5 hex** of the file. Then poll
  `assetDeliveryState.state == COMPLETE`.
- **Bundle ID already taken** → pick a namespaced reverse-DNS id you control
  (`com.yourorg.appname`); update the project (and the iCloud container, if any) to match.
- **Device not registered / iCloud container mismatch** when test-installing on hardware →
  register the device UDID in the portal and ensure the iCloud container is created and
  assigned to the App ID.
- **JWT lifetime** ≤ 20 min (`exp = iat + 1200`), `aud = "appstoreconnect-v1"`, ES256.
  Regenerate per script run; don't cache.
- **Empty draft review submissions** created during testing can't be deleted via API (403).
  Ignore them or remove in the UI.
- **Replacing screenshots = DELETE then upload** (the API *appends*). To swap a bad set, first
  `GET /v1/appScreenshotSets/{setid}/appScreenshots`, `DELETE /v1/appScreenshots/{id}` each,
  then run the 3-step upload. Otherwise you end up with 6 screenshots (3 stale + 3 new).
- **Resubmitting a REJECTED version → `STATE_ERROR.ITEM_PART_OF_ANOTHER_SUBMISSION`.** The
  rejected `reviewSubmission` still "holds" the version. Free it with
  `PATCH /v1/reviewSubmissions/{id}` `{"canceled": true}`, then create a fresh submission, add
  the version as a `reviewSubmissionItem`, and `PATCH submitted=true`. A stray *empty*
  submission left over from a failed attempt may 409 on cancel — just **reuse** it (add the
  item + submit it) instead of creating another.
- **Attach a reviewer screen recording via the API** (works even while `WAITING_FOR_REVIEW`):
  3-step like screenshots — `POST /v1/appStoreReviewAttachments` (attrs `fileName`+`fileSize`,
  relationship → `appStoreReviewDetails/{id}`) → PUT bytes to `uploadOperations` → `PATCH`
  `uploaded=true` + `sourceFileChecksum` (MD5). Poll `assetDeliveryState.state == COMPLETE`.
- **`releaseType: AFTER_APPROVAL`** on the version means **approval auto-publishes** it — no
  manual "Release" click needed. Confirm via `GET appStoreVersions/{id}` before submitting.
- **Build must be `processingState == VALID`** before `attach-build`; list with
  `GET /v1/builds?filter[app]={aid}&sort=-uploadedDate`. Processing takes ~5–15 min after `altool`.

## Screenshot display types (common)

| Device | `screenshotDisplayType` | Required size (px) |
|---|---|---|
| iPad 13" / 12.9" | `APP_IPAD_PRO_3GEN_129` | 2064×2752 or 2048×2732 (portrait) |
| iPhone 6.9" | `APP_IPHONE_67` | 1290×2796 |
| iPhone 6.5" (legacy, the quirk) | `APP_IPHONE_65` | 1242×2688 or 1284×2778 |

Only the **first 3** screenshots per set appear on the install sheet.

## Project: IoTFlow (this app)

Customized for the **IoTFlow** iOS app in this repo. Credentials/URLs/contact live in the
gitignored `.env` at the repo root (see [.env.example](.env.example)); the `.p8` lives outside
the repo and is never committed.

```
App name:        IoTFlow
App ID (ASC):    (created on first submission — write back into .env as ASC_APP_ID)
Bundle ID:       com.tertiaryinfotech.iotflow
iCloud container: none  (data lives on the IoTFlow backend REST/Auth.js API — NO CloudKit)
Team ID:         GU9WTSTX9M   (Apple Distribution: Alfred Ang)
Platform:        iOS 17.0+, SwiftUI. Built UIDeviceFamily = 1,2 (universal), Portrait only.
                 ⚠️ Recommended: set TARGETED_DEVICE_FAMILY = 1 (iPhone-only) before archiving —
                 the app is portrait-only and iPhone-shaped, and iPhone-only avoids iPad
                 screenshots AND the iPad "all orientations / requires full screen" warning.
Category:        Utilities  (secondary: Developer Tools)
Price:           Free
Version / Build: 1.0.0 / 1               # bump CURRENT_PROJECT_VERSION on every upload
Backend:         https://iot.tertiaryinfotech.com   (Next.js + Auth.js v5, NextAuth JWT cookie)
Marketing site:  https://www.tertiaryinfotech.com   Support: https://www.tertiaryinfotech.com/contact
Privacy:         https://iot.tertiaryinfotech.com/privacy   Delete account: see note below
```

> IoTFlow-specific notes:
> - **Build system**: plain `.xcodeproj` committed, but a `project.yml` (XcodeGen) is the source
>   of truth. If XcodeGen is installed, edit `project.yml` then `xcodegen generate`; otherwise
>   edit `IoTFlow.xcodeproj/project.pbxproj` directly. Scheme/target = `IoTFlow`.
> - **Archive + export**: `xcodebuild -project IoTFlow.xcodeproj -scheme IoTFlow -configuration
>   Release -archivePath /tmp/IoTFlow.xcarchive -destination 'generic/platform=iOS' archive`,
>   then `-exportArchive` with the repo's [ExportOptions.plist](../../ExportOptions.plist)
>   (method `app-store-connect`, team `GU9WTSTX9M`, automatic signing).
> - **Screenshots**: if shipping universal, you need `APP_IPHONE_67` (1290×2796), `APP_IPHONE_65`
>   (1242×2688) and `APP_IPAD_PRO_3GEN_129`. If iPhone-only, just the two iPhone sets. Capture
>   the real Dashboard / Devices / Add-Device / Settings screens — NOT the login screen. The
>   `screenshots/` folder has captures but verify they match the required pixel sizes.
> - **CloudKit**: NONE — all data is served from the backend REST API. Skip the CloudKit step.
> - **Account deletion (Guideline 5.1.1(v))**: the app has register/login, so an in-app Delete
>   Account flow is mandatory for *approval*. As of this writing the backend exposes **no**
>   delete endpoint (`DELETE /api/account` → 404), so a working flow needs a backend endpoint
>   first (e.g. `DELETE /api/account` that deactivates + anonymizes the user), then a destructive
>   "Delete Account" button in `SettingsView` → confirm → call endpoint → `session.logout()`.
>   Reaching WAITING_FOR_REVIEW does not require it; passing review does.
> - **Demo for reviewers**: the login screen has a **"Explore demo"** path (`SessionStore.enterDemo()`,
>   `DemoData`) that shows the full app with sample data and needs no account — put this in the
>   App Review notes so a reviewer can evaluate without credentials.
> - **Export compliance**: app uses only standard HTTPS/TLS → answer "no non-exempt encryption"
>   (set `ITSAppUsesNonExemptEncryption = NO`, or answer once in ASC).
> - **Signing**: identity **Apple Distribution: Alfred Ang (GU9WTSTX9M)**, automatic signing.
>   ASC automation key: Key ID **YQHNLVGDWK**, Issuer **(in `.env` as `ASC_ISSUER_ID`)**,
>   p8 at `~/.appstoreconnect/private_keys/AuthKey_YQHNLVGDWK.p8`.
> - **App Privacy (UI-only)**: declare account email/name (App Functionality, linked to user),
>   plus device/telemetry user content; tracking = No. Mirror `/privacy`.

Marketing copy for the version localization (subtitle ≤30, keywords ≤100, promo ≤170, desc ≤4000):

```
Subtitle:    Your IoT devices, on the go
Keywords:    IoT,sensors,telemetry,dashboard,MQTT,monitoring,ESP32,Arduino,alerts,devices,smart
Promo text:  Monitor and manage all your IoT devices in real time — live dashboards, telemetry charts, instant alerts and a guided device setup wizard.
Description: IoTFlow is a lightweight, self-hostable platform for connecting and monitoring your IoT devices — now on iPhone.

Connect ESP32, Arduino, Raspberry Pi and any MQTT- or HTTP-capable device, then watch your data live from anywhere.

KEY FEATURES
• Real-time dashboard — live telemetry, status cards and recent activity at a glance.
• Device management — add, organize and remove devices with a guided setup wizard.
• Telemetry charts — visualize sensor readings and metrics over time.
• Smart alerts — get notified the moment a device goes offline or a threshold is crossed.
• Multiple protocols — MQTT and HTTP ingestion out of the box.
• Self-hosted friendly — point the app at the public platform or your own IoTFlow server.

Try it instantly with the built-in demo — no account required. Sign in to connect to the public
IoTFlow platform, or enter your own self-hosted server URL in Settings.

IoTFlow is built by Tertiary Infotech. Privacy policy: https://iot.tertiaryinfotech.com/privacy
```

## Lessons learned / rejection checklist (field-tested)

These items each map to a **real App Review rejection** on a shipping app. They are written
generically — they apply to any app with the matching characteristics. Run this checklist
**before every `submit`**.

### Guideline 2.3.3 — Accurate Metadata (screenshots)

A submission was rejected with "the 6.5-inch iPhone screenshots do not show the current
version of the app in use."
- [ ] Every App Store screenshot is a **real capture of the actual current app's working
      screens** (your home / list / detail / main-feature views), taken from the simulator or a device.
- [ ] **Never** reuse another store's assets (e.g. Google Play graphics), marketing mockups, or
      promotional graphics as screenshots — materials that don't reflect the real app UI are not acceptable.
- [ ] **No splash screens, no login screens, and no marketing-only graphics** in the screenshot
      set — Apple does not count these as "the app in use."
- [ ] The **majority** of screenshots show the app's **main features/functionality**.
- [ ] Re-capture for **every** display size you upload (`APP_IPHONE_67`, `APP_IPHONE_65`,
      `APP_IPAD_PRO_3GEN_129`) — don't let a stale set ship.

### Guideline 5.1.1(v) — Data Collection and Storage (account deletion)

A submission was rejected with "the app supports account creation but does not include an
option to initiate account deletion." **Any app with login/registration must ship account deletion.**
- [ ] Ship a **working in-app Delete Account flow** (e.g. Profile → confirmation → backend
      `DELETE` request → sign out) **before** submitting.
- [ ] Temporary deactivate/disable is **not** sufficient; it must actually delete the account.
- [ ] If a website is needed to finish deletion, **deep-link directly** to your
      `<DELETE_ACCOUNT_URL>` (not just the homepage). Only highly-regulated apps may require
      email/phone/customer-service to delete — most apps don't qualify.
- [ ] Attach a **screen recording of the deletion flow** in the App Review Notes.

### Guideline 2.1 — App Completeness (demo account)

An earlier submission was rejected because the demo review account **did not exist on the
live backend** / the app crashed on the reviewer's device.
- [ ] Verify **`<REVIEW_ACCOUNT_EMAIL>` / `<REVIEW_ACCOUNT_PASSWORD>`** actually logs in against
      your live backend right before submitting (don't assume).
- [ ] Confirm a **demo/TestFlight build launches without crashing on every device family you
      support** — for a universal app, reviewers test on iPad too.

## Resubmission recipe — clearing "screenshots + account-deletion" (2.3.3 + 5.1.1(v))

The full end-to-end fix, in order. Reuse this for any "screenshots + account-deletion" rejection.

**1. Real screenshots from the Simulator.**
- Build + run for the simulator: `xcodebuild ... -sdk iphonesimulator -destination
  'platform=iOS Simulator,name=<Simulator Device>'`, then `xcrun simctl install booted <App>.app`
  + `xcrun simctl launch booted <BUNDLE_ID>`.
- Capture: `xcrun simctl io booted screenshot out.png` (a 6.9" Pro Max renders 1320×2868).
- Drive between tabs/screens with **`cliclick`** using the Simulator window geometry
  (`osascript ... get {position, size} of window 1`). Map screen-fraction → window point and
  **allow ~28 pt for the title bar** (bottom-of-screen tab taps are insensitive to it; mid-screen
  taps are not). After each shell call the Simulator can lose focus — `activate` + one throwaway
  click before the real tap.
- Resize to the exact slot size with `sips -z <h> <w> in.png --out out.png`
  (e.g. 6.5" = 1284×2778).
- Upload by **deleting the old set first, then the 3-step reserve/PUT/PATCH** (see Gotchas).

**2. In-app account deletion (the 5.1.1(v) fix).**
- Backend: add an authenticated `DELETE /account` (or equivalent) that **deactivates +
  anonymizes** — set `isActive=false`, rewrite the email to a tombstone
  (`deleted+<id>@…`), and null out `passwordHash`/name/phone/avatar/OAuth ids. Keep the row
  (don't hard-delete) so legally-required transaction records stay linkable. The login route
  must already reject inactive accounts so the deleted user **cannot sign back in**.
- App: a clearly-labelled destructive **Delete Account** button on the Profile screen →
  `confirmationDialog` → call the endpoint → `signOut()`. Show progress + error states.
- **Verify the endpoint is actually LIVE before submitting**: register a throwaway account via
  the API, call the delete route with its token (expect 200), then try to log in again (expect
  401). Don't trust "deploy finished" — `curl` the real route.

**3. ⚠️ Deploying the backend can expose LATENT crashes.** Adding a new endpoint may force the
**first rebuild of the API container in months**, which compiles the *current* source and surfaces
bugs that were committed but never deployed (e.g. a stray top-level route handler registered
outside its plugin → `ReferenceError` crash-loop; or ESM `ERR_MODULE_NOT_FOUND` from extensionless
relative imports). Symptoms: container `exited:unhealthy`, "Stopped after reaching restart limit",
site 503 — while the *build* shows green "Success" (**build success ≠ runtime success**). To
diagnose, **reproduce the container's exact start command locally** (read the start command from
your Dockerfile/process config) and read the **runtime** logs, not the build log. Keep the hotfix
minimal; verify the route is live before resubmitting.

**4. The reviewer screen recording (do everything but the typing).**
- **Synthetic keystrokes do NOT enter text into SwiftUI `TextField`s** — `cliclick t:` and
  System Events `keystroke` both silently fail to focus/fill the field. Two reliable options:
  (a) **have a human type** the credentials while you drive everything else, or (b) inject a
  pre-authenticated session. Pre-create a **simple, easy-to-type throwaway account**
  (`<TEST_ACCOUNT>` / short password) so whoever types it isn't fighting a long string — and so
  the real demo account is never deleted in the recording.
- Record: `xcrun simctl io booted recordVideo --codec=h264 --force out.mp4` (runs until SIGINT;
  stop with `pkill -INT -f "simctl io booted recordVideo"` so the file finalizes).
- Trim with `ffmpeg -ss <start> -i out.mp4 -c:v libx264 -crf 23 -pix_fmt yuv420p clip.mp4`;
  sanity-check with a `tile=8x4` contact sheet (remember `tile` only covers `fps×tiles` seconds).
- Attach via the **`appStoreReviewAttachments` API** (works while `WAITING_FOR_REVIEW`).

**5. Submit + auto-publish.** Cancel the old rejected `reviewSubmission`, add the version to a
fresh one, `PATCH submitted=true`. With `releaseType=AFTER_APPROVAL`, **approval publishes it
automatically** — no further action.
