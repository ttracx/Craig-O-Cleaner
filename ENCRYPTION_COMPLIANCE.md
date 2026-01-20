# App Encryption Compliance Documentation

## Craig-O-Clean - Export Compliance Information

**Bundle ID**: com.craigoclean.app
**App Name**: Craig-O-Clean
**Version**: 3
**Build**: 1
**Date**: January 20, 2026

---

## Encryption Usage Declaration

**ITSAppUsesNonExemptEncryption**: `NO` (false)

Craig-O-Clean **does NOT use non-exempt encryption** and qualifies for encryption exemptions under U.S. Export Administration Regulations (EAR).

---

## Encryption Technologies Used

Craig-O-Clean uses **only standard, exempt encryption** provided by Apple and industry-standard protocols:

### 1. HTTPS/TLS Communication
- **Purpose**: Secure communication for in-app purchases and backend services
- **Implementation**: Standard iOS/macOS URLSession with TLS 1.2+
- **Exemption**: Qualified under Section 740.17(b)(1) - Standard cryptographic functionality

### 2. StoreKit & App Store Receipts
- **Purpose**: In-app purchase validation and subscription management
- **Implementation**: Apple's StoreKit framework
- **Exemption**: Qualified under Section 740.17(b)(1) - Apple's built-in encryption

### 3. Keychain Services
- **Purpose**: Secure storage of user credentials and tokens
- **Implementation**: Apple's Keychain Services API
- **Exemption**: Qualified under Section 740.17(b)(1) - Operating system encryption

### 4. UserDefaults & Local Storage
- **Purpose**: App preferences and trial management
- **Implementation**: Standard iOS/macOS APIs with no additional encryption
- **Exemption**: No encryption beyond what's provided by the operating system

---

## Exemption Justification

Craig-O-Clean qualifies for **Category 5 Part 2 exemption** under EAR:

1. ✅ **No proprietary or non-standard encryption algorithms**
   - Only uses encryption provided by Apple's operating system
   - No custom cryptographic implementations

2. ✅ **No encryption export/import functionality**
   - App does not provide, export, or re-export encryption tools
   - No cryptographic libraries bundled

3. ✅ **Standard authentication only**
   - Uses Apple Sign In and standard authentication protocols
   - No custom authentication encryption

4. ✅ **Consumer software exemption**
   - App is designed for general consumer use
   - Available for public download from the App Store
   - Not specialized for military, government, or enterprise encryption needs

---

## Technical Implementation Details

### Network Communication
```
Protocol: HTTPS (TLS 1.2+)
Certificate Validation: Standard system trust store
Pinning: None (uses system defaults)
Implementation: URLSession with default configuration
```

### Data Storage
```
Keychain: Standard Keychain Services API
UserDefaults: Standard NSUserDefaults/UserDefaults
File System: Standard FileManager with no additional encryption
```

### Third-Party Dependencies
```
Stripe SDK: Uses standard HTTPS for payment processing
No other networking or encryption libraries
```

---

## Compliance Statements

### U.S. Export Control (EAR)
- **Classification**: ECCN 5D992 (not subject to EAR)
- **License Exception**: TSU (Technology and Software - Unrestricted)
- **Exemption**: Section 740.17(b)(1) - Mass market encryption

### International Regulations
- **European Union**: No encryption reporting required (standard encryption)
- **Other Jurisdictions**: App uses only standard commercial encryption

---

## Supporting Documentation

### App Store Declaration
In the App Store Connect submission:
- **Uses Encryption**: YES
- **Uses Non-Exempt Encryption**: NO
- **Export Compliance Required**: NO

### Info.plist Key
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

## Verification Checklist

- [x] Info.plist contains ITSAppUsesNonExemptEncryption = false
- [x] Only uses Apple-provided encryption APIs
- [x] No custom encryption algorithms implemented
- [x] No encryption libraries bundled
- [x] HTTPS/TLS used for network communication only
- [x] StoreKit used for in-app purchases only
- [x] Keychain used for secure storage only
- [x] App is consumer-focused general utility software
- [x] No military, government, or specialized encryption use

---

## Contact Information

**Developer**: NeuralQuantum.ai LLC
**Email**: support@craigoclean.com
**Website**: https://craigoclean.com

---

## Legal Disclaimer

This documentation is provided for informational purposes regarding export compliance. The developer has made a good-faith determination that the app qualifies for encryption exemptions. Users and regulators should refer to official U.S. government resources and legal counsel for definitive export control guidance.

**References**:
- U.S. Bureau of Industry and Security (BIS): https://www.bis.doc.gov
- Apple Export Compliance Guide: https://developer.apple.com/documentation/security/complying_with_encryption_export_regulations

---

**Document Version**: 1.0
**Last Updated**: January 20, 2026
**Next Review**: Before next App Store submission or when encryption usage changes
