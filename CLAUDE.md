# CLAUDE.md

Guidance for working in this repository.

## What this is

**IoTFlow** — a native **SwiftUI iOS app** (iOS 17.0+, portrait only) that is a mobile client
for the IoTFlow IoT platform. It connects to a **Next.js + Auth.js (NextAuth v5) backend** at
`https://iot.tertiaryinfotech.com` to manage devices and view real-time telemetry, alerts and
dashboards. The backend lives in a separate repo (`alfredang/iotplatform`,
`~/projects/tertiary/iotplatform`). This repo is **only the iOS client** — there is no CloudKit;
all data comes from the backend REST/Auth API.

- Bundle ID: `com.tertiaryinfotech.iotflow` · Team: `GU9WTSTX9M` (Apple Distribution: Alfred Ang)
- Default server: `AppConfig.defaultServer` (overridable at runtime via Settings → Server,
  stored in `UserDefaults` key `serverURL`).

## Build & run

The Xcode project is generated from **`project.yml` via XcodeGen** (source of truth). If you
change targets/settings, edit `project.yml` and regenerate — don't hand-edit the `.pbxproj`.
`xcodegen` is not always installed; the committed `IoTFlow.xcodeproj` builds directly too.

```bash
xcodegen generate            # only if project.yml changed and xcodegen is installed
# Build for simulator:
xcodebuild -project IoTFlow.xcodeproj -scheme IoTFlow -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
# Release archive (for App Store):
xcodebuild -project IoTFlow.xcodeproj -scheme IoTFlow -configuration Release \
  -archivePath /tmp/IoTFlow.xcarchive -destination 'generic/platform=iOS' archive
```

Scheme/target are both `IoTFlow`. Marketing version `MARKETING_VERSION`, build
`CURRENT_PROJECT_VERSION` (bump on every App Store upload) live in `project.yml`.

## Architecture

All Swift source is under [IoTFlow/](IoTFlow/):

- **`IoTFlowApp.swift`** — `@main` App entry; owns a single `SessionStore`, applies
  `.tint(.accentColor)`.
- **`SessionStore.swift`** — `@MainActor ObservableObject`, the app-wide auth state machine
  (`.loading` / `.signedOut` / `.signedIn(SessionUser)`). Also drives demo mode (`enterDemo()`).
- **`APIClient.swift`** — `actor`, the networking layer. Replicates the browser Auth.js
  credentials flow: `GET /api/auth/csrf` → `POST /api/auth/callback/credentials`, then relies on
  `HTTPCookieStorage.shared` to carry the NextAuth session cookie on every request. Endpoints:
  login, register, currentUser, logout, dashboardSummary, devices, createDevice, deleteDevice.
- **`Models.swift`** — `Decodable` DTOs (`SessionUser`, `Device`, `DashboardSummary`, telemetry,
  alerts) plus enums (`DeviceProtocol`, `DeviceStatus`) and `APIError`.
- **`DemoData.swift`** — canned data so the whole UI works with **no backend**; toggled by
  `DemoData.isEnabled` (UserDefaults `demoMode`). Powers the **"Explore demo"** entry on the
  login screen and is the path App Review uses (no account needed).
- **`Views/`** — `RootView` (top-level switch), `MainTabView` (3 tabs: Dashboard / Devices /
  Settings), `LoginView`, `DashboardView`, `DevicesView`, `DeviceDetailView`, `AddDeviceView`,
  `SettingsView` (+ `ServerSettingsView`).

### Conventions
- SwiftUI + `async/await`; networking isolated in the `APIClient` actor, UI state on `@MainActor`.
- System **semantic colors** and SF Symbols throughout; brand accent is the asset-catalog
  `AccentColor` (blue ≈ `#3373F2`) applied via `.tint`. No `Theme.swift` — don't hardcode colors.
- `List`/`Form` + `Section` + `LabeledContent` for settings/forms; `NavigationStack` +
  `NavigationLink` for drill-down; sheets for create flows.
- The design language is documented in the project skill **`mobile-ios-design`** — follow it.

## App Store submission

Submission is automated via the project skill **`app-store-submission`**
([.claude/skills/app-store-submission/](.claude/skills/app-store-submission/)), driven by the
App Store Connect API + Xcode CLI. Per-project config (bundle id, team, ASC key, metadata, URLs)
is in the gitignored **`.env`** at the repo root; the `.p8` key lives at
`~/.appstoreconnect/private_keys/AuthKey_YQHNLVGDWK.p8`. `ExportOptions.plist` (method
`app-store-connect`, team `GU9WTSTX9M`, automatic signing) is gitignored.

Known **App Review** considerations:
- The app has registration/login → Guideline **5.1.1(v)** requires an in-app **Delete Account**
  flow. Not yet implemented (backend has no delete endpoint); needed for *approval*.
- Use real in-app screenshots (Dashboard/Devices/Add-Device/Settings) — never the login screen.
- Reviewers evaluate via **"Explore demo"** (no credentials required).

## Secrets

Never commit secrets. `.gitignore` excludes `.env`, `*.p8`, `*.mobileprovision`,
`ExportOptions.plist`. The privacy policy is hosted by the backend at
`https://iot.tertiaryinfotech.com/privacy`.
