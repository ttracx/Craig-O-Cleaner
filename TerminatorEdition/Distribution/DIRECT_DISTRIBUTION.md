# Direct Distribution Guide
## Craig-O Clean Terminator Edition

---

## Why Direct Distribution?

Craig-O Terminator Edition is a **system-level utility** that requires capabilities prohibited by the Mac App Store's sandbox requirements:

✅ **What we need**:
- Shell command execution (`pgrep`, `ps`, `pkill`, `rm`)
- Admin privilege requests via AppleScript
- Access to system directories (`~/Library/Caches`, `/var/tmp`)
- Process monitoring and management
- Browser tab control via AppleScript

❌ **App Store restrictions**:
- All apps must be sandboxed (`com.apple.security.app-sandbox = true`)
- No shell command execution
- Extremely limited file system access
- No privilege escalation

**Conclusion**: Like CleanMyMac X, AppCleaner, OnyX, and other professional system utilities, we distribute directly to maintain full functionality.

---

## Distribution Channels

### 1. **Website Download** (Primary)
- Host: `craigoterminator.com` or `vibecaas.com/craig-o-terminator`
- Format: Notarized DMG or PKG installer
- Users download → Gatekeeper verifies notarization → Safe install

### 2. **GitHub Releases** (Secondary)
```bash
# Release URL
https://github.com/vibecaas/craig-o-terminator/releases

# Download latest
curl -L https://github.com/vibecaas/craig-o-terminator/releases/latest/download/CraigOTerminator.dmg -o CraigOTerminator.dmg
```

### 3. **Homebrew Cask** (Power Users)
```bash
# Once submitted to Homebrew
brew install --cask craig-o-terminator
```

### 4. **Third-Party Stores** (Optional)
- Setapp (subscription marketplace)
- MacUpdate
- Download.com

---

## Notarization Process

### Prerequisites

1. **Apple Developer Account** (paid)
2. **Developer ID Application Certificate** installed in Keychain
3. **App-specific password** for notarization
   - Generate at: https://appleid.apple.com/account/manage
   - Account → Security → App-Specific Passwords

### Step 1: Build & Archive

```bash
cd /Volumes/VibeStore/Craig-O-Cleaner/TerminatorEdition/Xcode

# Clean build
xcodebuild clean -project CraigOTerminator.xcodeproj -scheme CraigOTerminator

# Archive for distribution
xcodebuild archive \
  -project CraigOTerminator.xcodeproj \
  -scheme CraigOTerminator \
  -configuration Release \
  -archivePath "build/CraigOTerminator.xcarchive"
```

### Step 2: Export for Developer ID

```bash
# Export with Developer ID signing
xcodebuild -exportArchive \
  -archivePath "build/CraigOTerminator.xcarchive" \
  -exportPath "build/export" \
  -exportOptionsPlist "ExportOptions.plist"
```

### Step 3: Create DMG

```bash
# Create a distributable DMG
hdiutil create -volname "Craig-O Terminator" \
  -srcfolder "build/export/CraigOTerminator.app" \
  -ov -format UDZO \
  "build/CraigOTerminator-v1.0.dmg"
```

### Step 4: Notarize with Apple

```bash
# Submit for notarization
xcrun notarytool submit "build/CraigOTerminator-v1.0.dmg" \
  --apple-id "your-apple-id@email.com" \
  --team-id "FVYG82RN3T" \
  --password "your-app-specific-password" \
  --wait

# Response will show:
#   id: submission-id-here
#   status: Accepted (or In Progress)
```

**Store credentials securely** (optional):
```bash
# Save credentials to keychain (one-time setup)
xcrun notarytool store-credentials "notary-profile" \
  --apple-id "your-apple-id@email.com" \
  --team-id "FVYG82RN3T" \
  --password "your-app-specific-password"

# Then use profile for future submissions
xcrun notarytool submit "build/CraigOTerminator-v1.0.dmg" \
  --keychain-profile "notary-profile" \
  --wait
```

### Step 5: Staple Notarization Ticket

```bash
# Attach the notarization ticket to the DMG
xcrun stapler staple "build/CraigOTerminator-v1.0.dmg"

# Verify stapling succeeded
xcrun stapler validate "build/CraigOTerminator-v1.0.dmg"

# Expected output:
# The validate action worked!
```

### Step 6: Verify Code Signing

```bash
# Verify the app is properly signed
codesign --verify --deep --strict --verbose=2 \
  "build/export/CraigOTerminator.app"

# Check signing details
codesign -dvv "build/export/CraigOTerminator.app"

# Should show:
# Authority=Developer ID Application: Your Name (FVYG82RN3T)
# Signed Time=...
# Info.plist entries=...
```

---

## Automated Release Script

Create `scripts/release.sh`:

```bash
#!/bin/bash
set -e

VERSION="$1"
if [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/release.sh <version>"
  echo "Example: ./scripts/release.sh 1.0.0"
  exit 1
fi

echo "🚀 Building Craig-O Terminator v$VERSION"

# Clean
xcodebuild clean -project CraigOTerminator.xcodeproj -scheme CraigOTerminator

# Archive
xcodebuild archive \
  -project CraigOTerminator.xcodeproj \
  -scheme CraigOTerminator \
  -configuration Release \
  -archivePath "build/CraigOTerminator.xcarchive"

# Export
xcodebuild -exportArchive \
  -archivePath "build/CraigOTerminator.xcarchive" \
  -exportPath "build/export" \
  -exportOptionsPlist "ExportOptions.plist"

# Create DMG
hdiutil create -volname "Craig-O Terminator v$VERSION" \
  -srcfolder "build/export/CraigOTerminator.app" \
  -ov -format UDZO \
  "build/CraigOTerminator-v$VERSION.dmg"

echo "✅ DMG created: build/CraigOTerminator-v$VERSION.dmg"
echo ""
echo "📝 Next steps:"
echo "1. Submit for notarization:"
echo "   xcrun notarytool submit build/CraigOTerminator-v$VERSION.dmg --keychain-profile notary-profile --wait"
echo ""
echo "2. Staple notarization ticket:"
echo "   xcrun stapler staple build/CraigOTerminator-v$VERSION.dmg"
echo ""
echo "3. Verify:"
echo "   xcrun stapler validate build/CraigOTerminator-v$VERSION.dmg"
echo ""
echo "4. Upload to distribution channels"
```

**Make executable**:
```bash
chmod +x scripts/release.sh
```

**Usage**:
```bash
./scripts/release.sh 1.0.0
```

---

## Distribution Checklist

### Pre-Release

- [ ] All features tested on clean macOS install
- [ ] Permissions dialogs work correctly
- [ ] No crashes or memory leaks
- [ ] Version number updated in Info.plist
- [ ] Release notes written
- [ ] Screenshots updated

### Build & Sign

- [ ] Clean build completed
- [ ] Exported with Developer ID certificate
- [ ] DMG created
- [ ] Submitted for notarization
- [ ] Notarization approved (status: Accepted)
- [ ] Notarization ticket stapled
- [ ] Code signing verified

### Distribution

- [ ] DMG uploaded to website
- [ ] GitHub release created with DMG attachment
- [ ] Release notes published
- [ ] Social media announcement
- [ ] Update documentation links

### Post-Release

- [ ] Monitor crash reports (via Sentry if configured)
- [ ] Track download metrics
- [ ] Monitor user feedback
- [ ] Plan next release

---

## Gatekeeper & User Experience

### First Launch Experience

1. **User downloads DMG** from your website
2. **User opens DMG** → macOS verifies notarization automatically
3. **User drags app to Applications**
4. **User double-clicks app**
5. **macOS shows dialog**: "Craig-O Terminator is an app downloaded from the internet. Are you sure you want to open it?"
6. **User clicks "Open"** → App launches
7. **App requests permissions** (Accessibility, Full Disk Access, Automation)
8. **User grants permissions** in System Settings
9. **App works fully** ✅

### If Notarization Fails

User sees: *"Craig-O Terminator cannot be opened because the developer cannot be verified."*

**Fix**: Right-click app → "Open" → Confirms opening

**Prevent**: Always notarize before distribution!

---

## Troubleshooting

### Issue: Notarization Rejected

**Check logs**:
```bash
xcrun notarytool log <submission-id> --keychain-profile notary-profile
```

**Common issues**:
- Hardened Runtime not enabled → **Fixed** (we have it enabled)
- Code signing issues → Verify with `codesign -dvv`
- Library validation issues → Check entitlements

### Issue: "App is damaged and can't be opened"

**Cause**: Quarantine attribute on downloaded file

**Fix** (for testing only, don't tell users):
```bash
xattr -cr /Applications/CraigOTerminator.app
```

**Prevention**: Proper notarization prevents this!

### Issue: Permissions Not Working

**Cause**: App not requesting permissions correctly

**Fix**: Verify entitlements and Info.plist usage descriptions

---

## Marketing & Distribution

### Landing Page Elements

Your website should include:

1. **Download button** (prominent, above fold)
2. **Security badges**:
   - ✅ Notarized by Apple
   - ✅ Code-signed with Developer ID
   - ✅ No malware, verified by Gatekeeper
3. **System requirements**: macOS 14.0+
4. **Screenshots** (before/after system cleanup)
5. **Feature list**
6. **FAQ** (especially about permissions)
7. **Support contact**

### Sample Download Page Copy

```markdown
# Download Craig-O Terminator Edition

**Version 1.0.0** — Released January 24, 2026

[⬇️ Download for macOS](https://vibecaas.com/downloads/CraigOTerminator-v1.0.0.dmg)

✅ **Notarized by Apple** — Safe to install
✅ **macOS 14 Sonoma or later**
✅ **Apple Silicon & Intel supported**

---

## Installation

1. Download the DMG file
2. Open the DMG
3. Drag Craig-O Terminator to Applications
4. Launch from Applications folder
5. Grant permissions when prompted

---

## Security

Craig-O Terminator is:
- **Notarized by Apple** for Gatekeeper approval
- **Code-signed** with Developer ID certificate
- **Open source** (view code on GitHub)
- **Privacy-focused** (all operations local, no tracking)

**Why not on the App Store?** This app requires system-level access to clean caches and manage processes — capabilities prohibited by App Store sandboxing. Like CleanMyMac and other professional utilities, we distribute directly.
```

---

## Next Steps

1. **Test the build process** with the commands above
2. **Set up notarization credentials** (app-specific password)
3. **Create first notarized build**
4. **Test on clean Mac** to verify Gatekeeper accepts it
5. **Set up distribution hosting** (website, GitHub releases)
6. **Launch!** 🚀

---

## References

- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Gatekeeper Overview](https://support.apple.com/guide/security/gatekeeper-and-runtime-protection-sec5599b66df)

---

**Questions?** Open an issue on GitHub or contact support@vibecaas.com
