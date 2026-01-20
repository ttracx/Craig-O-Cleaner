# Export Compliance Documentation
## Craig-O-Clean

**App Name:** Craig-O-Clean
**Bundle Identifier:** com.craigoclean.app
**Version:** 3.0
**Developer:** Tommy Xaypanya / Phamy Xaypanya
**Date:** January 20, 2026

---

## Export Compliance Declaration

Craig-O-Clean **uses encryption**, but qualifies for **Category 5 Part 2 exemption** under U.S. Export Administration Regulations (15 CFR 740.17(b)(1)).

### Info.plist Configuration

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

This declaration indicates that the app:
- ✅ Uses encryption (HTTPS, StoreKit, Keychain)
- ✅ Does NOT use non-exempt encryption
- ✅ Qualifies for Category 5 Part 2 exemption

---

## Encryption Technologies Used

Craig-O-Clean uses **only** standard encryption provided by Apple's operating system:

### 1. HTTPS/TLS Communication
- **Purpose:** Secure network communication with servers
- **Implementation:** Apple URLSession with TLS 1.3
- **Type:** Standard encryption (AES-256-GCM, ChaCha20-Poly1305)
- **Provider:** Apple iOS/macOS networking stack
- **Modification:** None - uses Apple's built-in encryption as-is

### 2. StoreKit (In-App Purchases)
- **Purpose:** Process subscription transactions
- **Implementation:** Apple StoreKit framework
- **Type:** Standard encryption for payment processing
- **Provider:** Apple StoreKit
- **Modification:** None - uses Apple's payment encryption as-is

### 3. Keychain Services
- **Purpose:** Secure storage of authentication tokens and user credentials
- **Implementation:** Apple Keychain Services
- **Type:** Standard encryption (AES-256 hardware-accelerated)
- **Provider:** Apple Security framework
- **Modification:** None - uses Apple's secure storage as-is

---

## What Craig-O-Clean Does NOT Use

The app does **NOT** implement:

❌ Proprietary encryption algorithms
❌ Custom cryptographic code
❌ Third-party encryption libraries
❌ Additional encryption beyond Apple's OS
❌ Non-standard encryption protocols
❌ Modified or extended encryption algorithms
❌ Encryption for data at rest (beyond Keychain)
❌ Custom key exchange mechanisms

---

## Exemption Justification

### Category 5 Part 2 Exemption (15 CFR 740.17(b)(1))

Craig-O-Clean qualifies for this exemption because:

1. **Uses Standard Encryption Only**
   - All encryption is provided by Apple's iOS/macOS operating systems
   - No additional cryptographic functionality has been implemented
   - No modifications to Apple's encryption implementations

2. **No Proprietary Algorithms**
   - Does not contain any encryption algorithms developed by the app developer
   - Uses only well-established, publicly documented encryption standards

3. **Mass Market Software**
   - Available on the public App Store
   - Not customized for specific users or organizations
   - Uses only encryption capabilities available in standard Apple operating systems

### Legal Basis

Under U.S. Export Administration Regulations:

> **15 CFR 740.17(b)(1):** Software that uses, accesses, maintains, or establishes encryption that is standard in commercial products and is not modified or extended by the software developer.

Craig-O-Clean meets this definition as it:
- Uses only standard encryption provided by Apple
- Does not modify or extend Apple's encryption capabilities
- Contains no additional cryptographic functionality

---

## Technical Implementation Details

### Network Communication
```swift
// Uses Apple URLSession with default TLS configuration
URLSession.shared.dataTask(with: url) { data, response, error in
    // Standard HTTPS/TLS 1.3 encryption handled by iOS/macOS
}
```

**Encryption Details:**
- Protocol: TLS 1.3
- Cipher Suites: Apple's default (AES-256-GCM, ChaCha20-Poly1305)
- Certificate Validation: Apple's default trust store
- No custom TLS configuration

### In-App Purchase Security
```swift
// Uses Apple StoreKit for payment processing
import StoreKit

// All payment encryption handled by Apple StoreKit framework
```

**Encryption Details:**
- Payment processing: Apple StoreKit end-to-end encryption
- Receipt validation: Apple's cryptographic signatures
- Transaction security: Apple's payment infrastructure
- No custom payment encryption

### Secure Storage
```swift
// Uses Apple Keychain for credential storage
import Security

// Store credentials using Apple's Keychain Services
SecItemAdd(query as CFDictionary, nil)
```

**Encryption Details:**
- Storage: AES-256 hardware-accelerated encryption
- Access Control: iOS/macOS Keychain access policies
- Key Management: Apple Secure Enclave
- No custom encryption layers

---

## Third-Party Dependencies

Craig-O-Clean does **NOT** use any third-party encryption libraries or frameworks.

All cryptographic operations are performed exclusively by:
- Apple Foundation framework
- Apple Security framework
- Apple StoreKit framework
- Apple's operating system networking stack

---

## Compliance Verification

### Export Control Classification Number (ECCN)
- **ECCN:** 5D992 (Mass market encryption software)
- **Reason for Control:** None (publicly available, standard encryption)

### Self-Classification
Based on the above information, Craig-O-Clean:
- ✅ Qualifies for Category 5 Part 2 exemption
- ✅ Does not require individual export authorization
- ✅ Uses only encryption exempt under 15 CFR 740.17(b)(1)
- ✅ Contains no encryption subject to BIS review

---

## Supporting Documentation

### Code Review Summary
A comprehensive code review confirms:
- No cryptographic libraries imported beyond Apple's frameworks
- No custom encryption/decryption functions
- No key generation beyond Apple's APIs
- No cryptographic algorithm implementations
- No encryption-related dependencies in package manifests

### Info.plist Declaration
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

This declaration in the app's Info.plist file confirms that the app uses only exempt encryption.

---

## Developer Statement

I, Tommy Xaypanya, developer of Craig-O-Clean, hereby declare that:

1. Craig-O-Clean uses encryption only through Apple's provided frameworks
2. No proprietary or non-standard encryption has been implemented
3. No modifications have been made to Apple's encryption capabilities
4. The app qualifies for Category 5 Part 2 exemption under 15 CFR 740.17(b)(1)
5. This declaration is accurate to the best of my knowledge

**Developer Name:** Tommy Xaypanya / Phamy Xaypanya
**Date:** January 20, 2026
**Contact:** support@craigoclean.com

---

## Conclusion

Craig-O-Clean uses **only** standard encryption provided by Apple's iOS and macOS operating systems. The app does not implement, modify, or extend any encryption capabilities beyond what is provided by Apple's frameworks.

**Therefore, Craig-O-Clean qualifies for Category 5 Part 2 exemption and does not require individual export authorization.**

---

## References

1. **U.S. Export Administration Regulations (EAR):**
   - 15 CFR 740.17(b)(1) - Category 5 Part 2 Exemption
   - Bureau of Industry and Security (BIS)

2. **Apple Documentation:**
   - App Store Connect Export Compliance Guidelines
   - URLSession and TLS Documentation
   - Keychain Services Documentation
   - StoreKit Security Overview

3. **Standards Bodies:**
   - IETF TLS 1.3 (RFC 8446)
   - NIST AES-256 (FIPS 197)
   - NIST ChaCha20-Poly1305 (RFC 7539)

---

**Document Version:** 1.0
**Last Updated:** January 20, 2026
**App Version:** 3.0
**Bundle ID:** com.craigoclean.app
