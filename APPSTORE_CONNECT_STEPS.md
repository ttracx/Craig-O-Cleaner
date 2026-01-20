# App Store Connect Submission Steps
## Craig-O-Clean - Complete Checklist

---

## ✅ STEP 1: App Encryption Documentation

### What You're Seeing in App Store Connect:

```
App Encryption Documentation

Specify your use of encryption in Xcode by adding the App Uses Non-Exempt
Encryption key to your app's Info.plist file with a Boolean value that
indicates whether your app uses encryption.

You're required to provide documentation if your app contains...
[Upload]
```

### ✅ Already Done!

Your `Info.plist` already contains:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

### What This Means:

✅ **Your app uses encryption** (HTTPS, StoreKit, Keychain)
✅ **But it's EXEMPT encryption** (standard Apple OS encryption only)
✅ **No upload required** in most cases!

---

## 📋 During Build Upload - Export Compliance Questions

When you upload your archive to App Store Connect, you'll see these questions:

### Question 1:
```
Is your app designed to use cryptography or does it contain or incorporate cryptography?
```

**Your Answer:** ✅ **YES**

---

### Question 2:
```
Does your app qualify for any of the available exemptions?
```

**Your Answer:** ✅ **YES**

---

### Question 3:
```
Which exemption does your app qualify for?
```

**Your Answer:** ✅ **"Your app uses encryption that qualifies for Category 5 Part 2 of the U.S. Export Administration Regulations"**

(This is the FIRST option in the list)

---

## 🎯 Most Likely Scenario

Apple will **auto-approve** your export compliance based on your Info.plist setting.

**You will NOT need to upload any documentation.**

The build will be available for TestFlight/App Review within minutes.

---

## 📄 If Apple Requests Documentation (Rare)

**Only if Apple specifically asks**, follow these steps:

### 1. Convert Document to PDF

Open `APP_STORE_ENCRYPTION_DOCUMENTATION.md` and convert to PDF:

**Option A - Using Preview (Mac):**
1. Open the .md file in a text editor
2. Print (⌘P)
3. Click "PDF" → "Save as PDF"
4. Name it: `Craig-O-Clean-Encryption-Documentation.pdf`

**Option B - Using Online Tool:**
1. Go to https://www.markdowntopdf.com
2. Upload `APP_STORE_ENCRYPTION_DOCUMENTATION.md`
3. Download the PDF

### 2. Upload to App Store Connect

1. Go to App Store Connect
2. Select "Craig-O-Clean"
3. Go to "App Information"
4. Scroll to "App Encryption Documentation"
5. Click "Upload"
6. Select your PDF file
7. Click "Save"

### 3. Wait for Review

- Apple typically reviews within 24-48 hours
- You'll receive an email when approved
- Then you can proceed with app submission

---

## ✅ STEP 2: Digital Services Act (DSA)

### What You're Seeing:

```
Digital Services Act

This developer has identified itself as a non-trader for this app.
In order to update your app level trader status, you need to complete
compliance requirements. Get Started
```

### ✅ Already Configured!

**Current Status:** Non-Trader ✅

### What This Means:

You're registered as an **individual developer** (not a business entity).

### Should You Change It?

**Keep as Non-Trader if:**
- ✅ You're an individual developer
- ✅ App development is a side project/hobby
- ✅ No formal business registration

**Change to Trader if:**
- You have a registered business (NeuralQuantum.ai LLC, etc.)
- You employ others for app development
- App development is your primary business

### To Change to Trader (If Needed):

1. Click "Get Started"
2. Enter business information:
   - Business Name: `NeuralQuantum.ai LLC` (or your entity)
   - Business Address: [Your registered address]
   - Business Registration Number: [Your EIN/Tax ID]
   - Contact Email: `support@neuralquantum.ai`
   - Contact Phone: [Your business phone]
3. Submit for review
4. Wait 24-48 hours for approval

### Recommended Action:

✅ **Keep as Non-Trader** (no action needed)

---

## ✅ STEP 3: Vietnam Game License

### What You're Seeing:

```
Vietnam Game License

If your game is available on the App Store in Vietnam, you can add a game
license as required by Vietnamese regulators. Learn More
[Add]
```

### ✅ Not Applicable!

Craig-O-Clean is a **utility app**, not a game.

### Recommended Action:

❌ **No action needed** - this doesn't apply to you

---

## ✅ STEP 4: China Mainland ICP Filing Number

### What You're Seeing:

```
China Mainland ICP Filing Number

An Internet Content Provider (ICP) Filing Number is an app registration number
from China's Ministry of Industry and Information Technology (MIIT). If you
have an ICP Filing Number, provide it here. Learn More
[Set Up]
```

### ✅ Not Applicable (Unless Targeting China)

Craig-O-Clean is targeting international markets, not China mainland.

### Recommended Action:

❌ **No action needed** - don't set this up unless you specifically want to distribute in China

**Why Skip:**
- Requires Chinese business entity
- Complex regulatory compliance
- Craig-O-Clean is a macOS utility (limited China market)

---

## 🚀 Complete Upload Workflow

### 1. Upload Archive

```bash
# Your archive is ready:
~/Desktop/Craig-O-Clean-20260120-125153.xcarchive
```

**Steps:**
1. Open **Xcode**
2. Go to **Window** → **Organizer** (or press ⌘⌥⇧O)
3. Select **Archives** tab
4. Find `Craig-O-Clean 20260120-125153`
5. Click **"Distribute App"**

### 2. Choose Distribution Method

Select: **"App Store Connect"**

### 3. Export Compliance Questions

Answer the questions as shown above:
- Uses encryption? **YES**
- Exempt? **YES**
- Category 5 Part 2? **YES**

### 4. Upload Starts

Xcode will:
- Validate your app
- Upload to App Store Connect
- Process the build

This takes 5-10 minutes.

### 5. Build Processing

After upload:
- Build appears in App Store Connect
- Status: "Processing"
- Wait 10-30 minutes for processing to complete

### 6. Export Compliance Auto-Approved

Because your Info.plist has `ITSAppUsesNonExemptEncryption = false`:
- ✅ Apple auto-approves export compliance
- ✅ No documentation upload needed
- ✅ Build becomes available for TestFlight

### 7. Submit for Review

Once build is processed:
1. Go to App Store Connect
2. Select your app
3. Click **"+ Version or Platform"** → **"macOS"**
4. Enter version: `3.0`
5. Fill in metadata (use `APP_STORE_METADATA.md`)
6. Select your build
7. Click **"Submit for Review"**

---

## 📝 Summary: What You Need to Do NOW

### Required Actions:

1. ✅ **Upload Archive**
   - Use Xcode Organizer
   - Select `Craig-O-Clean-20260120-125153.xcarchive`
   - Answer export compliance questions (YES, YES, Category 5 Part 2)

2. ✅ **Wait for Processing**
   - Build will process in 10-30 minutes
   - Export compliance will auto-approve

3. ✅ **Fill in Metadata**
   - Use content from `APP_STORE_METADATA.md`
   - Add screenshots (guidelines in that file)
   - Set pricing and availability

4. ✅ **Submit for Review**
   - Select your processed build
   - Submit when ready

### Optional Actions (Only If Asked):

- 📄 **Upload encryption documentation** (only if Apple requests it)
- 🏢 **Update trader status** (only if you have a business entity)
- 🇨🇳 **Set up ICP filing** (only if targeting China)

### Not Needed:

- ❌ Vietnam Game License (not a game)
- ❌ Additional export compliance docs (Info.plist handles it)

---

## ❓ Troubleshooting

### "Build Rejected - Export Compliance Documentation Required"

**Very Rare** - but if it happens:

1. Convert `APP_STORE_ENCRYPTION_DOCUMENTATION.md` to PDF
2. Upload in App Store Connect → App Information → App Encryption Documentation
3. Wait 24-48 hours for review
4. Re-upload build

### "Export Compliance Questions Keep Appearing"

Make sure:
1. ✅ Info.plist contains `ITSAppUsesNonExemptEncryption = false`
2. ✅ You're uploading the NEW archive (with crash fix)
3. ✅ Archive was built AFTER Info.plist was updated

### "Can't Find Export Compliance Questions"

This is GOOD! It means:
- ✅ Apple detected your Info.plist setting
- ✅ Export compliance is auto-approved
- ✅ Build is ready for TestFlight/Review

---

## 📞 Support

**If You Get Stuck:**

1. **Apple Developer Support:**
   - Email: developer-support@apple.com
   - Phone: 1-800-MY-APPLE (Ask for Developer Support)

2. **Reference Your Files:**
   - `APP_STORE_ENCRYPTION_DOCUMENTATION.md` - Detailed encryption info
   - `ENCRYPTION_COMPLIANCE.md` - Technical details
   - `APP_STORE_METADATA.md` - App description and keywords
   - `APPSTORE_SUBMISSION_CHECKLIST.md` - Complete checklist

3. **Key Information to Provide:**
   - App: Craig-O-Clean
   - Bundle ID: com.craigoclean.app
   - Encryption: Category 5 Part 2 exempt (standard Apple OS encryption only)
   - Info.plist: ITSAppUsesNonExemptEncryption = false

---

**Good luck with your submission!** 🚀

Your app is properly configured and ready to upload. The export compliance should auto-approve based on your Info.plist setting.

---

**Last Updated:** January 20, 2026
**App Version:** 3.0
**Status:** Ready for Upload
