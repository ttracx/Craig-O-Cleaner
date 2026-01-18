# Linux Packaging Guide

This document provides instructions for packaging and distributing Craig-O-Clean on Linux.

## Overview

Craig-O-Clean for Linux supports multiple packaging formats:

| Format | Distribution | Auto-Update |
|--------|--------------|-------------|
| Flatpak | Flathub | Yes |
| Snap | Snap Store | Yes |
| .deb | Debian/Ubuntu | Via apt |
| .rpm | Fedora/RHEL | Via dnf |
| Tarball | Universal | Manual |

## Prerequisites

### Development Dependencies

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libstdc++-12-dev \
  libsecret-1-dev libayatana-appindicator3-dev

# Fedora
sudo dnf install -y \
  clang cmake ninja-build pkgconfig \
  gtk3-devel xz-devel libstdc++-devel \
  libsecret-devel libayatana-appindicator3-devel
```

### Flutter SDK

```bash
# Install Flutter (stable channel)
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"
flutter doctor
```

## Building

### Release Build

```bash
cd linux
flutter pub get
flutter build linux --release
```

Output: `build/linux/x64/release/bundle/`

### Build Contents

```
bundle/
├── craig_o_clean           # Main executable
├── data/
│   ├── flutter_assets/     # Flutter assets
│   └── icudtl.dat          # ICU data
└── lib/
    ├── libflutter_linux_gtk.so
    └── ... (other libraries)
```

## Flatpak

### Flathub Submission

1. Fork https://github.com/flathub/flathub
2. Add manifest: `com.craigoclean.CraigOClean.yml`
3. Submit pull request

### Manifest

The Flatpak manifest is in `flatpak/com.craigoclean.CraigOClean.yml`:

```yaml
app-id: com.craigoclean.CraigOClean
runtime: org.freedesktop.Platform
runtime-version: '23.08'
sdk: org.freedesktop.Sdk
command: craig_o_clean

finish-args:
  - --share=ipc
  - --socket=fallback-x11
  - --socket=wayland
  - --device=dri
  - --share=network
  - --talk-name=org.freedesktop.secrets
  - --talk-name=org.kde.StatusNotifierWatcher
  - --filesystem=host:ro
  - --filesystem=/proc:ro

modules:
  - name: craig-o-clean
    buildsystem: simple
    build-commands:
      - install -Dm755 craig_o_clean /app/bin/craig_o_clean
      - cp -r data /app/bin/
      - cp -r lib /app/bin/
      - install -Dm644 com.craigoclean.CraigOClean.desktop /app/share/applications/
      - install -Dm644 com.craigoclean.CraigOClean.svg /app/share/icons/hicolor/scalable/apps/
    sources:
      - type: archive
        url: https://github.com/craigoclean/craig-o-clean-linux/releases/download/v1.0.0/craig-o-clean-linux-x64.tar.gz
        sha256: <sha256sum>
```

### Building Flatpak Locally

```bash
# Install flatpak-builder
sudo apt install flatpak-builder

# Add Flathub remote
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install SDK
flatpak install flathub org.freedesktop.Platform//23.08 org.freedesktop.Sdk//23.08

# Build
cd linux
flatpak-builder --user --install-deps-from=flathub --force-clean \
  build-dir flatpak/com.craigoclean.CraigOClean.yml

# Create bundle
flatpak build-bundle ~/.local/share/flatpak/repo \
  craig-o-clean.flatpak com.craigoclean.CraigOClean
```

### Installing Flatpak

```bash
flatpak install craig-o-clean.flatpak
flatpak run com.craigoclean.CraigOClean
```

## Snap

### Snapcraft Configuration

The Snap configuration is in `snap/snapcraft.yaml`:

```yaml
name: craig-o-clean
version: '1.0.0'
summary: System monitor and optimizer for Linux
description: |
  Craig-O-Clean provides real-time system monitoring,
  process management, and optimization tools.

base: core22
grade: stable
confinement: strict

apps:
  craig-o-clean:
    command: bin/craig_o_clean
    plugs:
      - desktop
      - desktop-legacy
      - wayland
      - x11
      - network
      - home
      - system-observe
      - process-control
    extensions:
      - gnome

parts:
  craig-o-clean:
    plugin: nil
    source: build/linux/x64/release/bundle
    override-build: |
      mkdir -p $SNAPCRAFT_PART_INSTALL/bin
      cp -r * $SNAPCRAFT_PART_INSTALL/bin/
```

### Building Snap

```bash
cd linux

# Build Flutter release first
flutter build linux --release

# Build Snap
snapcraft

# Output: craig-o-clean_1.0.0_amd64.snap
```

### Publishing to Snap Store

```bash
# Login to Snap Store
snapcraft login

# Register name (first time only)
snapcraft register craig-o-clean

# Upload
snapcraft upload craig-o-clean_1.0.0_amd64.snap --release=stable
```

### Installing Snap

```bash
sudo snap install craig-o-clean
```

## Debian Package (.deb)

### Using dpkg-deb

```bash
cd linux

# Create package structure
mkdir -p craig-o-clean_1.0.0_amd64/DEBIAN
mkdir -p craig-o-clean_1.0.0_amd64/usr/bin
mkdir -p craig-o-clean_1.0.0_amd64/usr/lib/craig-o-clean
mkdir -p craig-o-clean_1.0.0_amd64/usr/share/applications
mkdir -p craig-o-clean_1.0.0_amd64/usr/share/icons/hicolor/256x256/apps

# Copy files
cp -r build/linux/x64/release/bundle/* craig-o-clean_1.0.0_amd64/usr/lib/craig-o-clean/

# Create launcher script
cat > craig-o-clean_1.0.0_amd64/usr/bin/craig-o-clean << 'EOF'
#!/bin/bash
exec /usr/lib/craig-o-clean/craig_o_clean "$@"
EOF
chmod +x craig-o-clean_1.0.0_amd64/usr/bin/craig-o-clean

# Copy desktop file and icon
cp assets/craig-o-clean.desktop craig-o-clean_1.0.0_amd64/usr/share/applications/
cp assets/icon-256.png craig-o-clean_1.0.0_amd64/usr/share/icons/hicolor/256x256/apps/craig-o-clean.png

# Create control file
cat > craig-o-clean_1.0.0_amd64/DEBIAN/control << 'EOF'
Package: craig-o-clean
Version: 1.0.0
Section: utils
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libsecret-1-0
Maintainer: Craig-O-Clean Team <support@craigoclean.com>
Description: System monitor and optimizer for Linux
 Craig-O-Clean provides real-time CPU and memory monitoring,
 process management, and system optimization tools.
EOF

# Build package
dpkg-deb --build craig-o-clean_1.0.0_amd64
```

### Installing .deb

```bash
sudo dpkg -i craig-o-clean_1.0.0_amd64.deb
sudo apt-get install -f  # Install dependencies if needed
```

## RPM Package

### Using rpmbuild

Create spec file `craig-o-clean.spec`:

```spec
Name:           craig-o-clean
Version:        1.0.0
Release:        1%{?dist}
Summary:        System monitor and optimizer for Linux

License:        Proprietary
URL:            https://craigoclean.com
Source0:        craig-o-clean-linux-x64.tar.gz

Requires:       gtk3
Requires:       libsecret

%description
Craig-O-Clean provides real-time CPU and memory monitoring,
process management, and system optimization tools.

%prep
%setup -q -n bundle

%install
mkdir -p %{buildroot}/usr/lib/craig-o-clean
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/applications
mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps

cp -r * %{buildroot}/usr/lib/craig-o-clean/

cat > %{buildroot}/usr/bin/craig-o-clean << 'EOF'
#!/bin/bash
exec /usr/lib/craig-o-clean/craig_o_clean "$@"
EOF
chmod +x %{buildroot}/usr/bin/craig-o-clean

%files
/usr/lib/craig-o-clean
/usr/bin/craig-o-clean
/usr/share/applications/craig-o-clean.desktop
/usr/share/icons/hicolor/256x256/apps/craig-o-clean.png

%changelog
* Mon Jan 01 2024 Craig-O-Clean Team <support@craigoclean.com> - 1.0.0-1
- Initial release
```

Build with:
```bash
rpmbuild -ba craig-o-clean.spec
```

## Desktop Entry

Create `com.craigoclean.CraigOClean.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Craig-O-Clean
Comment=System monitor and optimizer
Exec=craig-o-clean
Icon=com.craigoclean.CraigOClean
Categories=System;Monitor;Utility;
Keywords=system;monitor;cpu;memory;process;
Terminal=false
StartupNotify=true
```

## AppStream Metadata

Create `com.craigoclean.CraigOClean.metainfo.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>com.craigoclean.CraigOClean</id>
  <name>Craig-O-Clean</name>
  <summary>System monitor and optimizer for Linux</summary>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>Proprietary</project_license>

  <description>
    <p>
      Craig-O-Clean provides comprehensive system monitoring and
      optimization tools for Linux desktops.
    </p>
    <p>Features:</p>
    <ul>
      <li>Real-time CPU and memory monitoring</li>
      <li>Process management with end/kill functionality</li>
      <li>System tray integration</li>
      <li>Memory optimization recommendations</li>
    </ul>
  </description>

  <launchable type="desktop-id">com.craigoclean.CraigOClean.desktop</launchable>

  <screenshots>
    <screenshot type="default">
      <image>https://craigoclean.com/screenshots/linux-dashboard.png</image>
      <caption>Dashboard showing system metrics</caption>
    </screenshot>
  </screenshots>

  <url type="homepage">https://craigoclean.com</url>
  <url type="bugtracker">https://github.com/craigoclean/issues</url>

  <releases>
    <release version="1.0.0" date="2024-01-01">
      <description>
        <p>Initial release</p>
      </description>
    </release>
  </releases>

  <content_rating type="oars-1.1" />
</component>
```

## Billing (Stripe)

Linux uses Stripe for subscription billing via browser-based checkout.

### Flow

1. User clicks "Subscribe" in app
2. App opens Stripe Checkout in browser
3. User completes payment
4. Stripe redirects to `craigoclean://billing/success`
5. App handles deep link and stores entitlement token

### Deep Link Handler

Register the `craigoclean://` URL scheme in desktop entry:

```ini
MimeType=x-scheme-handler/craigoclean;
```

### Secure Token Storage

Tokens are stored using:
- **GNOME**: libsecret (GNOME Keyring)
- **KDE**: KWallet via libsecret

```dart
// Uses flutter_secure_storage with libsecret backend
final storage = FlutterSecureStorage();
await storage.write(key: 'entitlement_token', value: token);
```

## Testing

### Unit Tests

```bash
cd linux
flutter test
```

### Integration Tests

```bash
cd linux
flutter test integration_test
```

### Testing on Different Distros

Test on at least:
- Ubuntu (LTS versions)
- Fedora (current)
- Debian (stable)
- Arch Linux

Use VMs or containers for testing.

## CI/CD

See `.github/workflows/linux.yml` for automated builds.

### Build Matrix

```yaml
strategy:
  matrix:
    format: [flatpak, snap, deb]
```

## Distribution Channels

1. **Flathub** (recommended)
   - Widest compatibility
   - Auto-updates
   - Sandboxed

2. **Snap Store**
   - Ubuntu integration
   - Auto-updates
   - Confinement options

3. **Direct Downloads**
   - .deb for Debian/Ubuntu
   - .rpm for Fedora/RHEL
   - Tarball for others

## Troubleshooting

### Common Issues

1. **Tray icon not showing**
   - Ensure StatusNotifier extension is installed
   - Check AppIndicator support in DE

2. **Permission denied for /proc**
   - Flatpak: Add `--filesystem=/proc:ro`
   - Snap: Add `system-observe` plug

3. **libsecret not found**
   - Install `libsecret-1-dev` / `libsecret-devel`

4. **GTK theme issues**
   - Set `GTK_THEME` environment variable
   - Ensure theme is accessible in sandbox

### Debug Mode

```bash
FLUTTER_DEBUG=1 craig-o-clean
```

## Support

For packaging questions, contact the development team or open an issue.
