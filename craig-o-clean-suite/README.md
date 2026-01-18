# Craig-O-Clean Suite

A cross-platform system utility suite for monitoring and managing system resources. Available for **Android**, **Windows 11**, **Linux**, and **macOS**.

## Overview

Craig-O-Clean Suite provides a consistent experience across platforms for:

- **System Monitoring**: Real-time CPU, RAM, and swap usage metrics
- **Process Management**: View and manage running processes (platform-appropriate actions)
- **Quick Access**: System tray/notification panel for instant metrics and actions
- **Memory Optimization**: Guided cleanup actions to free system resources

## Platforms

| Platform | Technology | Store |
|----------|------------|-------|
| Android | Kotlin + Jetpack Compose | Google Play Store |
| Windows 11 | .NET 8 + WinUI 3 | Microsoft Store |
| Linux | Flutter Desktop | Flathub / Snap Store |
| macOS | Swift + SwiftUI | Mac App Store |

## Monorepo Structure

```
craig-o-clean-suite/
├── shared/                    # Cross-platform shared code
│   ├── schemas/               # JSON schemas for data models
│   ├── branding/              # Brand assets and design tokens
│   ├── entitlement/           # Subscription/trial logic specs
│   └── telemetry/             # Analytics event definitions
├── android/                   # Android app (Kotlin)
├── windows/                   # Windows 11 app (C#)
├── linux/                     # Linux app (Flutter)
├── backend/                   # Stripe billing backend (Node.js)
└── README.md
```

## Business Model

All platforms share the same pricing structure:

- **Free Mode**: View-only metrics and process lists
- **7-Day Trial**: Full feature access
- **Monthly**: $0.99/month
- **Yearly**: $9.99/year (2 months free)

### Feature Gating

| Feature | Free | Trial/Paid |
|---------|------|------------|
| View system metrics | Yes | Yes |
| View process list | Yes | Yes |
| End/kill processes | No | Yes |
| Quick actions (tray/notification) | No | Yes |
| Bulk cleanup actions | No | Yes |
| Advanced cleanup tools | No | Yes |

## Branding (VibeCaaS)

### Colors

| Name | Hex | Usage |
|------|-----|-------|
| Vibe Purple | `#6D4AFF` | Primary accent, CTAs |
| Aqua Teal | `#14B8A6` | Secondary, success states |
| Signal Amber | `#FF8C00` | Warnings, alerts |

### Design Principles

1. **Technical but Approachable**: Accurate terminology, friendly tone
2. **Flow Metaphors**: Subtle rhythm and flow language
3. **Platform Native**: Respect each platform's design guidelines
4. **Accessibility First**: WCAG compliant, screen reader support

## Getting Started

### Android

```bash
cd android
./gradlew assembleDebug
```

### Windows

```bash
cd windows
dotnet build
```

### Linux

```bash
cd linux
flutter pub get
flutter run -d linux
```

### Backend

```bash
cd backend
npm install
npm run dev
```

## Documentation

- [Architecture](./ARCHITECTURE.md)
- [Billing](./BILLING.md)
- [Android Play Store](./android/PLAY_STORE.md)
- [Windows Microsoft Store](./windows/MICROSOFT_STORE.md)
- [Linux Packaging](./linux/PACKAGING.md)

## License

Proprietary - All rights reserved.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for development guidelines.
