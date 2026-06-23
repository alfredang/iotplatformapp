---
name: mobile-ios-design
description: Master iOS Human Interface Guidelines and SwiftUI patterns for building polished, native iOS apps. Use when designing iOS interfaces, implementing SwiftUI views, applying a custom brand theme, or ensuring screens follow Apple's design principles.
license: MIT
metadata:
  version: "1.0.0"
---

# iOS Mobile Design (HIG + SwiftUI)

Master iOS Human Interface Guidelines (HIG) and SwiftUI patterns to build polished, native iOS
applications that feel at home on Apple platforms. The reference files in [references/](references/)
hold deeper, copy-pasteable examples for HIG layout, navigation, and the component library.

## Project: IoTFlow (this app)

This skill is customized for the **IoTFlow** SwiftUI app in this repo (an IoT device
monitoring client for the platform at `iot.tertiaryinfotech.com`). Match these existing
conventions when adding or editing screens — don't introduce a second style.

**Targets & constraints**
- iOS **17.0+**, SwiftUI lifecycle (`@main struct IoTFlowApp`), **portrait only**.
- Source lives in [IoTFlow/](../../IoTFlow/); views in [IoTFlow/Views/](../../IoTFlow/Views/).

**Brand / color**
- Brand accent is **blue `rgb(0.20, 0.45, 0.95)` ≈ `#3373F2`**, defined in the asset catalog as
  `AccentColor` and applied app-wide via `.tint(.accentColor)` in `IoTFlowApp`.
- The app uses **system semantic colors** (`.primary`, `.secondary`, `.tint`, grouped-list
  backgrounds) rather than a custom `Theme.swift` — so Dark Mode and contrast come for free.
  Reference `Color.accentColor` / `.tint` for brand color; do **not** hardcode the hex.
- If the palette ever grows beyond the single accent, introduce a `Theme.swift` tokens file
  (see "Applying a custom brand theme" below) rather than scattering literals.

**Navigation architecture** (`Views/RootView.swift`)
- `RootView` switches on `SessionStore.state`: `.loading` → `ProgressView`; `.signedOut` →
  `LoginView`; `.signedIn` → `MainTabView`.
- `MainTabView` is a 3-tab `TabView`: **Dashboard** (`square.grid.2x2.fill`), **Devices**
  (`cpu.fill`), **Settings** (`gearshape.fill`). Add new top-level areas as tabs here.
- Detail screens use `NavigationStack` + `NavigationLink` (e.g. `DevicesView` →
  `DeviceDetailView`); modals like `AddDeviceView` are presented as sheets.

**Component conventions already in use**
- Settings/forms use `List` / `Form` with `Section`, `LabeledContent`, and `Label(_, systemImage:)`.
- Destructive actions use `Button(role: .destructive)` (e.g. Sign out in `SettingsView`).
- SF Symbols throughout; prefer filled variants for the tab bar, outline for inline actions.
- Inline navigation titles on secondary screens (`.navigationBarTitleDisplayMode(.inline)`).

**HIG gaps worth closing in this app** (good first design tasks)
- The Settings screen has **Sign out** but no **Delete Account** — App Review Guideline
  5.1.1(v) requires in-app account deletion for any app with registration. Add a destructive
  "Delete Account" row with a `confirmationDialog` (needs a backend endpoint; see the
  `app-store-submission` skill).
- Add empty-state and error views (see [references/hig-patterns.md](references/hig-patterns.md))
  for the Devices list and Dashboard when the backend is unreachable or returns no devices.

## Applying a custom brand theme

Keep your app's palette in a single **`Theme.swift`** tokens file and always reference those
tokens, never hardcoded `Color` literals. This is what keeps screens consistent and makes a
re-theme a one-file change. A typical token set:

| Token | Use |
|-------|-----|
| `Theme.primary` | primary accent, key buttons, active states |
| `Theme.secondary` | secondary accent, links, selected tabs |
| `Theme.highlight` | highlights, ratings, badges |
| `Theme.background` | app background |
| `Theme.surface` | subtle fills, chips, card surfaces |
| `Theme.ink` / `Theme.mutedInk` | primary / secondary text |

```swift
// Use the brand tokens, not raw Color literals.
Text("Order now")
    .foregroundStyle(.white)
    .padding()
    .background(Theme.primary, in: Capsule())

// A reusable card surface modifier (defined in Theme.swift):
ItemCard(item: item).appCard(padding: 16)
```

Lessons that apply to any custom-themed app:
- **If you use a non-system background** (e.g. a warm off-white), system semantic text colors can
  fail contrast. Use an explicit dark `Theme.ink` (not `.primary`) for body text and verify **AA
  contrast** against your actual background color.
- **Large navigation titles can flicker or disappear** against a custom background color. Switching
  to **inline navigation titles** (`.navigationBarTitleDisplayMode(.inline)`) keeps the title
  reliably visible.
- Define a **single card modifier** (white/elevated surface, ~18pt continuous corner radius, soft
  shadow) and reuse it everywhere instead of re-styling each card.
- **Design for iPhone and iPad** if you ship a universal app — the iPad layout must launch and look
  right (it is part of App Review). Use adaptive grids / `NavigationSplitView` where it helps on iPad.
- Where this guide's generic examples show `.blue`, substitute your own `Theme.primary` /
  `Theme.secondary` tokens.

## When to Use This Skill

- Designing iOS app interfaces following Apple HIG
- Building SwiftUI views and layouts
- Implementing iOS navigation patterns (NavigationStack, TabView, sheets)
- Creating adaptive layouts for iPhone and iPad
- Using SF Symbols and system typography
- Building accessible iOS interfaces
- Implementing iOS-specific gestures and interactions
- Designing for Dynamic Type and Dark Mode

## Core Concepts

### 1. Human Interface Guidelines Principles

**Clarity**: Content is legible, icons are precise, adornments are subtle
**Deference**: UI helps users understand content without competing with it
**Depth**: Visual layers and motion convey hierarchy and enable navigation

**Platform Considerations:**

- **iOS**: Touch-first, compact displays, portrait orientation
- **iPadOS**: Larger canvas, multitasking, pointer support
- **visionOS**: Spatial computing, eye/hand input

### 2. SwiftUI Layout System

**Stack-Based Layouts:**

```swift
// Vertical stack with alignment
VStack(alignment: .leading, spacing: 12) {
    Text("Title")
        .font(.headline)
    Text("Subtitle")
        .font(.subheadline)
        .foregroundStyle(.secondary)
}

// Horizontal stack with flexible spacing
HStack {
    Image(systemName: "star.fill")
    Text("Featured")
    Spacer()
    Text("View All")
        .foregroundStyle(.blue)
}
```

**Grid Layouts:**

```swift
// Adaptive grid that fills available width
LazyVGrid(columns: [
    GridItem(.adaptive(minimum: 150, maximum: 200))
], spacing: 16) {
    ForEach(items) { item in
        ItemCard(item: item)
    }
}

// Fixed column grid
LazyVGrid(columns: [
    GridItem(.flexible()),
    GridItem(.flexible()),
    GridItem(.flexible())
], spacing: 12) {
    ForEach(items) { item in
        ItemThumbnail(item: item)
    }
}
```

### 3. Navigation Patterns

**NavigationStack (iOS 16+):**

```swift
struct ContentView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List(items) { item in
                NavigationLink(value: item) {
                    ItemRow(item: item)
                }
            }
            .navigationTitle("Items")
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item)
            }
        }
    }
}
```

**TabView (iOS 18+):**

```swift
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: 0) {
                HomeView()
            }

            Tab("Search", systemImage: "magnifyingglass", value: 1) {
                SearchView()
            }

            Tab("Profile", systemImage: "person", value: 2) {
                ProfileView()
            }
        }
    }
}
```

### 4. System Integration

**SF Symbols:**

```swift
// Basic symbol
Image(systemName: "heart.fill")
    .foregroundStyle(.red)

// Symbol with rendering mode
Image(systemName: "cloud.sun.fill")
    .symbolRenderingMode(.multicolor)

// Variable symbol (iOS 16+)
Image(systemName: "speaker.wave.3.fill", variableValue: volume)

// Symbol effect (iOS 17+)
Image(systemName: "bell.fill")
    .symbolEffect(.bounce, value: notificationCount)
```

**Dynamic Type:**

```swift
// Use semantic fonts
Text("Headline")
    .font(.headline)

Text("Body text that scales with user preferences")
    .font(.body)

// Custom font that respects Dynamic Type
Text("Custom")
    .font(.custom("Avenir", size: 17, relativeTo: .body))
```

### 5. Visual Design

**Colors and Materials:**

```swift
// Semantic colors that adapt to light/dark mode
Text("Primary")
    .foregroundStyle(.primary)
Text("Secondary")
    .foregroundStyle(.secondary)

// System materials for blur effects
Rectangle()
    .fill(.ultraThinMaterial)
    .frame(height: 100)

// Vibrant materials for overlays
Text("Overlay")
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
```

**Shadows and Depth:**

```swift
// Standard card shadow
RoundedRectangle(cornerRadius: 16)
    .fill(.background)
    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

// Elevated appearance
.shadow(radius: 2, y: 1)
.shadow(radius: 8, y: 4)
```

## Quick Start Component

```swift
import SwiftUI

struct FeatureCard: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(.blue.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}
```

## Best Practices

1. **Use Semantic Colors**: Always use `.primary`, `.secondary`, `.background` for automatic light/dark mode support
2. **Embrace SF Symbols**: Use system symbols for consistency and automatic accessibility
3. **Support Dynamic Type**: Use semantic fonts (`.body`, `.headline`) instead of fixed sizes
4. **Add Accessibility**: Include `.accessibilityLabel()` and `.accessibilityHint()` modifiers
5. **Use Safe Areas**: Respect `safeAreaInset` and avoid hardcoded padding at screen edges
6. **Implement State Restoration**: Use `@SceneStorage` for preserving user state
7. **Support iPad Multitasking**: Design for split view and slide over
8. **Test on Device**: Simulator doesn't capture full haptic and performance experience

## Common Issues

- **Layout Breaking**: Use `.fixedSize()` sparingly; prefer flexible layouts
- **Performance Issues**: Use `LazyVStack`/`LazyHStack` for long scrolling lists
- **Navigation Bugs**: Ensure `NavigationLink` values are `Hashable`
- **Dark Mode Problems**: Avoid hardcoded colors; use semantic or asset catalog colors
- **Accessibility Failures**: Test with VoiceOver enabled
- **Memory Leaks**: Watch for strong reference cycles in closures

## Reference Files

- [references/hig-patterns.md](references/hig-patterns.md) — HIG layout/spacing, typography scale,
  color system, toolbars, search, haptics, accessibility, error/empty states.
- [references/ios-navigation.md](references/ios-navigation.md) — NavigationStack, NavigationSplitView,
  sheets/detents, tabs, deep linking, coordinator pattern, zoom/hero transitions.
- [references/swiftui-components.md](references/swiftui-components.md) — lists, forms, buttons/menus,
  sheets, loading/skeletons, AsyncImage, animations, gestures.
