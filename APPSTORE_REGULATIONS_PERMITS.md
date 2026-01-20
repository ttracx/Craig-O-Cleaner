# App Store Regulations & Permits Guide

## Craig-O-Clean - Compliance Requirements

**App**: Craig-O-Clean
**Bundle ID**: com.craigoclean.app
**Category**: Utilities
**Type**: System Utility (Non-Game)

---

## 📋 Overview

This guide covers three regulatory requirements in App Store Connect:

1. **Digital Services Act (DSA)** - EU compliance for trader status
2. **Vietnam Game License** - Required for games in Vietnam
3. **China Mainland ICP Filing Number** - Required for apps in China

---

## 🇪🇺 Digital Services Act (DSA)

### What is the Digital Services Act?

The DSA is an EU regulation requiring online platforms to identify whether app developers are "traders" (businesses) or "non-traders" (individuals/hobbyists).

### Trader vs. Non-Trader

**Trader** (Business):
- You sell apps commercially as a business activity
- You're registered as a company or business entity
- App development is your primary or significant income source
- You have employees or contractors working on apps
- You advertise yourself as a business

**Non-Trader** (Individual/Hobbyist):
- You're an individual developer
- App development is a side project or hobby
- Not registered as a business
- No employees/contractors
- App revenue is supplemental income

### Craig-O-Clean Status

**Recommended**: ✅ **Non-Trader**

**Justification**:
- Individual developer (Tommy Xaypanya / Phamy Xaypanya)
- Utility app as a personal project
- No business entity registration required
- Side project or personal development

**However, if you have registered business entities** (NeuralQuantum.ai LLC, Tunaas.ai, etc.), you may need to declare as **Trader**.

---

## How to Configure DSA Status

### Option 1: Non-Trader (Current Status)

**Status**: ✅ Already set (as shown in your message)

**What This Means**:
- You don't need to provide business information
- Simpler compliance requirements
- Suitable for individual developers
- No additional documentation needed

**No action required** - you're already configured as Non-Trader.

---

### Option 2: Change to Trader (If Applicable)

If you need to change to Trader status:

1. **Go to App Store Connect**
   - Navigate to: https://appstoreconnect.apple.com
   - Select "My Apps" → "Craig-O-Clean"

2. **Click "Get Started" on DSA Notice**
   - Under "App Information" → "Digital Services Act"
   - Click "Get Started" to begin compliance requirements

3. **Complete Trader Information**

   **Required Information**:

   **Business Name**:
   ```
   NeuralQuantum.ai LLC
   (or your registered business name)
   ```

   **Business Address**:
   ```
   [Your registered business address]
   Street Address Line 1
   Street Address Line 2 (optional)
   City, State/Province, ZIP/Postal Code
   Country
   ```

   **Business Registration Number**:
   ```
   [Your company registration number, EIN, or VAT number]
   ```

   **Contact Email**:
   ```
   support@neuralquantum.ai
   (or your business email)
   ```

   **Contact Phone**:
   ```
   [Your business phone number]
   ```

4. **Submit for Review**
   - Apple will review your trader information
   - Approval typically takes 24-48 hours

---

## When to Use Trader vs. Non-Trader

### Choose **Non-Trader** if:
- ✅ You're an individual developer
- ✅ App is a side project or hobby
- ✅ No formal business registration
- ✅ Revenue is supplemental/occasional
- ✅ No employees working on the app

### Choose **Trader** if:
- ✅ Registered business entity (LLC, Corp, etc.)
- ✅ App development is primary business activity
- ✅ You have a tax ID/VAT number
- ✅ You employ others for development
- ✅ You advertise as a business

**For Craig-O-Clean**: If you're publishing under **NeuralQuantum.ai LLC** or other business entities, you should likely declare as **Trader**.

---

## 🇻🇳 Vietnam Game License

### What is Vietnam Game License?

Vietnam requires all games available on the App Store to have a **Game Publishing License** issued by Vietnamese regulators.

### Does Craig-O-Clean Need This?

**❌ NO** - Craig-O-Clean is **NOT a game**.

**Applies to**:
- Games (any genre)
- Apps with significant game-like elements
- Apps categorized as "Games" in App Store

**Does NOT apply to**:
- Utilities (like Craig-O-Clean)
- Productivity apps
- Social networking apps
- Education apps (unless game-based)

### If You Had a Game App

**Requirements**:
1. Obtain a Game Publishing License from Vietnam's Ministry of Information and Communications
2. License number format: G1/XXX/BTTTT or G2/XXX/BTTTT
3. Add license number in App Store Connect

**How to Add** (if needed):
1. App Store Connect → App Information
2. Scroll to "Vietnam Game License"
3. Click "Add"
4. Enter license number
5. Save

**No action needed for Craig-O-Clean** - it's a utility, not a game.

---

## 🇨🇳 China Mainland ICP Filing Number

### What is ICP Filing Number?

An **Internet Content Provider (ICP) Filing Number** is a registration number issued by China's Ministry of Industry and Information Technology (MIIT) for apps distributed in mainland China.

### Does Craig-O-Clean Need This?

**Only if** you want to distribute Craig-O-Clean in **mainland China**.

**Required for**:
- Apps available on the China App Store
- Apps with servers or content hosted in China
- Apps targeting Chinese users

**Not required if**:
- You're not distributing in China
- You're only targeting US, EU, and other international markets

---

## When to Get ICP Filing Number

### If You Want to Distribute in China

**Requirements**:
1. **Legal Entity in China** - You need a Chinese business entity or partner
2. **Chinese Business License** - Valid business registration
3. **Chinese Server Hosting** - Content must be hosted in China
4. **MIIT Registration** - Apply through Chinese hosting provider

**Process**:
1. Establish legal presence in China (or partner with Chinese entity)
2. Register with Chinese hosting provider (Aliyun, Tencent Cloud, etc.)
3. Submit ICP filing application through hosting provider
4. Wait 20-30 days for approval
5. Receive ICP number (format: 京ICP备12345678号)

**Complexity**: ⚠️ Very high - requires Chinese legal entity and compliance

---

## How to Add ICP Filing Number (If You Have One)

1. **Go to App Store Connect**
   - Navigate to: https://appstoreconnect.apple.com
   - Select "My Apps" → "Craig-O-Clean"

2. **Navigate to App Information**
   - Click "App Information" in left sidebar
   - Scroll to "China Mainland ICP Filing Number"

3. **Click "Set Up"**
   - Enter your ICP filing number
   - Format: 京ICP备12345678号 (example)
   - Example: 沪ICP备19012345号

4. **Save Changes**

---

## Craig-O-Clean Recommendations

### ✅ Digital Services Act (DSA)

**Current Status**: Non-Trader ✅

**Recommendation**:
- If you're an individual developer: **Keep as Non-Trader** (no action needed)
- If you're publishing under a business entity: **Change to Trader** and provide business details

**Action Required**:
- **None** if keeping Non-Trader status
- **Complete trader information** if changing to Trader

---

### ❌ Vietnam Game License

**Status**: Not Applicable

**Reason**: Craig-O-Clean is a utility app, not a game

**Action Required**: **None**

---

### ⚠️ China Mainland ICP Filing Number

**Status**: Not Set Up

**Recommendation**: **Do NOT set up** unless you specifically want to distribute in China

**Reasons to Skip**:
- Complex regulatory requirements
- Requires Chinese business entity
- Significant compliance overhead
- Craig-O-Clean is a macOS utility (limited China market)

**Action Required**: **None** (unless targeting China market)

**If Targeting China**:
1. Consult with Chinese legal counsel
2. Establish business presence in China
3. Register with MIIT through hosting provider
4. Obtain ICP filing number
5. Add to App Store Connect

---

## Summary: What You Need to Do

### For Craig-O-Clean Submission

| Requirement | Status | Action Needed |
|-------------|--------|---------------|
| **Digital Services Act** | ✅ Set (Non-Trader) | ✅ None (or change to Trader if applicable) |
| **Vietnam Game License** | ❌ Not Applicable | ✅ None |
| **China ICP Filing** | ⚠️ Not Set | ✅ None (unless targeting China) |

### Recommended Configuration

**1. Digital Services Act**:
```
Status: Non-Trader
Rationale: Individual developer, utility app
Action: Keep current status (or update to Trader if business entity)
```

**2. Vietnam Game License**:
```
Status: Not Applicable
Rationale: Not a game
Action: None
```

**3. China ICP Filing**:
```
Status: Not Required
Rationale: Not targeting China market
Action: None
```

---

## Availability & Distribution

### Recommended Territories

Based on Craig-O-Clean being a macOS utility:

**Primary Markets**:
- 🇺🇸 United States
- 🇨🇦 Canada
- 🇬🇧 United Kingdom
- 🇦🇺 Australia
- 🇩🇪 Germany
- 🇫🇷 France
- 🇪🇸 Spain
- 🇮🇹 Italy
- 🇯🇵 Japan
- 🇰🇷 South Korea
- 🇳🇱 Netherlands
- 🇸🇪 Sweden
- 🇳🇴 Norway
- 🇩🇰 Denmark
- 🇫🇮 Finland

**Consider Excluding**:
- 🇨🇳 China (requires ICP filing, complex compliance)
- 🇻🇳 Vietnam (if it were a game, would need license)

### How to Set Availability

1. **Go to Pricing and Availability**
   - App Store Connect → Craig-O-Clean → Pricing and Availability

2. **Select Territories**
   - Choose "Select All" or individually select territories
   - Deselect countries you want to exclude

3. **Save**

---

## Compliance Checklist

### Before Submission

- [x] **DSA Status Determined**
  - Currently: Non-Trader ✅
  - Update to Trader if applicable

- [x] **Vietnam Game License**
  - Not applicable (not a game) ✅

- [x] **China ICP Filing**
  - Not targeting China market ✅

- [ ] **Territory Selection**
  - Select target markets
  - Consider excluding China (unless ICP filed)

- [ ] **Pricing Set**
  - Free or paid tier
  - In-app purchase pricing configured

---

## When to Revisit These Requirements

### Digital Services Act
- ✅ Review annually
- ✅ Update if business status changes (individual → business entity)
- ✅ Required if you transfer app to another developer

### Vietnam Game License
- ✅ Only if you publish a game in the future
- ✅ Required before distributing games in Vietnam

### China ICP Filing
- ✅ Only if you decide to target China market
- ✅ Must renew annually with MIIT

---

## Additional Resources

### Digital Services Act (DSA)
- **Apple Documentation**: https://developer.apple.com/support/digital-services-act/
- **EU DSA Official Site**: https://digital-strategy.ec.europa.eu/en/policies/digital-services-act-package

### Vietnam Game License
- **Apple Guidelines**: https://developer.apple.com/support/vietnam-game-license/
- **Vietnam MOET**: https://moet.gov.vn (Vietnamese Ministry)

### China ICP Filing
- **Apple Requirements**: https://developer.apple.com/cn/support/icp/
- **MIIT Portal**: https://beian.miit.gov.cn (Chinese language)
- **Hosting Providers**:
  - Aliyun (Alibaba Cloud): https://www.aliyun.com
  - Tencent Cloud: https://cloud.tencent.com

---

## Support & Questions

### If You Need Help

**Digital Services Act**:
- Review Apple's DSA guidelines
- Consult with legal counsel if unsure about trader status
- Email: developer-support@apple.com

**Vietnam Game License**:
- Not applicable for Craig-O-Clean
- For future game apps, consult Vietnamese legal counsel

**China ICP Filing**:
- Consult with Chinese legal counsel
- Work with Chinese hosting provider for registration
- Consider partnering with Chinese distributor

---

## Decision Summary for Craig-O-Clean

### ✅ Recommended Configuration

1. **Digital Services Act**:
   - **Keep as Non-Trader** (if individual developer)
   - **OR Update to Trader** (if business entity)

2. **Vietnam Game License**:
   - **No action needed** (not a game)

3. **China ICP Filing**:
   - **No action needed** (not targeting China)

4. **Availability**:
   - **Distribute worldwide** (except China)
   - **OR Select specific territories** (US, EU, etc.)

### Total Action Items

- [ ] **Confirm DSA status** (Non-Trader vs. Trader)
- [ ] **If Trader**: Complete business information in App Store Connect
- [ ] **Set territory availability** (recommend excluding China)
- [ ] **Proceed with submission** (all other requirements met)

---

**Document Version**: 1.0
**Last Updated**: January 20, 2026
**App**: Craig-O-Clean (com.craigoclean.app)
**Status**: Ready for Submission
