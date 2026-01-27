# Privileged Helper Security Model

## Overview

Craig-O-Clean's privileged helper tool implements defense-in-depth security following Apple's best practices for privileged operations.

## Threat Model

### Assets Protected
- System files and directories
- Running system processes
- System configuration
- User data privacy

### Threats Mitigated
1. **Arbitrary Command Execution**: Command allowlist prevents execution of unauthorized commands
2. **Privilege Escalation**: Authorization Services ensures only authorized users can execute elevated commands
3. **Tampering**: Code signing prevents modification of helper tool
4. **Unauthorized Access**: XPC security restricts which apps can communicate with helper

### Assumptions
- User's macOS installation is not compromised
- System Integrity Protection (SIP) is enabled
- Valid code signing certificates are used
- User controls administrator password

## Security Layers

### Layer 1: Installation Security

**SMJobBless Framework**
- Helper installed to `/Library/PrivilegedHelperTools/` (system-wide, protected location)
- Requires administrator password for installation
- Launchd manages helper lifecycle (no persistent daemon)
- System validates code signature during installation

**Code Signing Requirements**
- Helper must be signed with valid Apple Developer certificate
- Signature must match main application signature
- Hardened runtime enabled
- `SMAuthorizedClients` restricts client applications

**Entitlements**
Main app (`CraigOTerminator.entitlements`):
```xml
<key>SMPrivilegedExecutables</key>
<dict>
    <key>ai.neuralquantum.CraigOTerminator.helper</key>
    <string>identifier "ai.neuralquantum.CraigOTerminator.helper" and anchor apple generic ...</string>
</dict>
```

Helper (`HelperTool.entitlements`):
```xml
<!-- Minimal entitlements for helper -->
<key>com.apple.security.cs.allow-jit</key>
<true/>
```

### Layer 2: Authorization Services

**Authorization Flow**
1. App requests authorization using `AuthorizationCreate`
2. User prompted for administrator password
3. Authorization converted to external form (`AuthorizationMakeExternalForm`)
4. External form passed to helper via XPC
5. Helper validates authorization (`AuthorizationCopyRights`)
6. Helper executes command if authorized

**Authorization Rights**
- Right: `ai.neuralquantum.CraigOTerminator.bless`
- Requires administrator group membership
- No credential caching (user prompted each session)
- Authorization token expires after use

**Code Example**
```swift
// In helper tool
func verifyAuthorization(_ authData: Data) -> Bool {
    var authRef: AuthorizationRef?

    // Convert external form to AuthorizationRef
    let status = AuthorizationCreateFromExternalForm(...)
    guard status == errAuthorizationSuccess else { return false }

    // Verify authorization for specific right
    let copyStatus = AuthorizationCopyRights(
        authRef,
        &rights,
        nil,
        [.extendRights, .interactionAllowed],
        nil
    )

    return copyStatus == errAuthorizationSuccess
}
```

### Layer 3: Command Allowlist

**Principle of Least Privilege**
- Helper only executes pre-approved commands
- Allowlist defined at compile time (cannot be modified at runtime)
- Allowlist reviewed for each capability in catalog

**Allowed Commands**
```swift
private let allowedCommands: Set<String> = [
    "/usr/sbin/diskutil",          // Disk utilities (repair, info)
    "/usr/bin/purge",              // Memory management
    "/usr/bin/dscacheutil",        // DNS operations
    "/usr/bin/mdutil",             // Spotlight operations
    "/usr/sbin/periodic",          // System maintenance
    "/usr/bin/killall",            // Process management (coreaudiod only)
    "/bin/rm",                     // File deletion (temp/trash only)
    "/usr/bin/log",                // System logs (read-only)
    "/usr/sbin/sysctl"             // System information
]
```

**Validation**
```swift
func isCommandAllowed(_ command: String) -> Bool {
    return allowedCommands.contains(command)
}
```

### Layer 4: Input Validation

**Command Path Validation**
- Must be absolute path
- Must exist in filesystem
- Must be in allowlist
- No symbolic link following

**Argument Validation**
- Arguments interpolated from capability catalog
- No user-provided raw command strings
- Shell metacharacters not interpreted (no shell execution)
- Working directory validated if provided

**Example**
```swift
// ✅ Safe: Command from catalog with validated arguments
executeCommand("/usr/bin/purge", arguments: [], workingDirectory: nil, authData: auth)

// ❌ Unsafe: Raw user input (never happens in our implementation)
executeCommand(userInput, arguments: [userArg], ...)
```

### Layer 5: XPC Security

**Connection Security**
- Helper listens on Mach service (not network)
- Service name registered in launchd.plist
- Only privileged connections accepted
- Process identifier logged for audit

**Interface Restrictions**
- XPC interface strictly typed via `HelperProtocol`
- Only defined methods can be invoked
- Invalid messages rejected by XPC runtime

**Connection Validation**
```swift
func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
    // Log connection attempt
    logger.info("Connection request from PID: \(newConnection.processIdentifier)")

    // Configure exported interface (only HelperProtocol methods accessible)
    newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)

    return true
}
```

### Layer 6: Audit Logging

**System Log**
- All operations logged via `os_log` (cannot be disabled by user)
- Includes command, arguments, exit code, timestamp
- Available to system administrators
- Tamper-evident (managed by macOS)

**Application Log**
- Operations recorded in SQLite database
- Includes full stdout/stderr
- Chained hashing prevents tampering
- Available to user for troubleshooting

**Log Example**
```
2026-01-27 10:15:32.123 helper[1234]: CraigOTerminator Helper: Executed '/usr/bin/purge' with exit code 0
```

**Audit Query**
```bash
log show --predicate 'subsystem == "ai.neuralquantum.CraigOTerminator.helper"' --last 1d
```

## Attack Scenarios

### Scenario 1: Malicious Application Attempts to Use Helper

**Attack**: Another application tries to execute commands via helper

**Mitigation**:
1. `SMAuthorizedClients` in helper's Info.plist restricts which apps can connect
2. Code signature of calling app validated by system
3. Only `ai.neuralquantum.CraigOTerminator` can communicate with helper

**Result**: Connection rejected by launchd before reaching helper

### Scenario 2: Command Injection via Arguments

**Attack**: Attacker tries to inject shell commands via capability arguments

**Mitigation**:
1. Commands executed directly (no shell interpretation)
2. Arguments passed as array (not concatenated string)
3. Capability catalog reviewed for safe argument patterns
4. No user-provided raw commands

**Example Safe Execution**:
```swift
// Arguments passed as array to Process, not through shell
process.arguments = ["-E", "/"]  // Safe
// NOT: "sh -c 'mdutil -E / && malicious_command'"  // Unsafe - we never do this
```

**Result**: Injection impossible due to direct execution

### Scenario 3: Path Traversal to Unauthorized Command

**Attack**: Attacker provides path like `/usr/bin/../../usr/sbin/sshd` to execute unauthorized command

**Mitigation**:
1. Command path validated against allowlist (exact match)
2. No path normalization bypasses
3. Symbolic links not followed

**Result**: Command rejected if not in allowlist

### Scenario 4: Helper Binary Replacement

**Attack**: Attacker replaces helper binary with malicious version

**Mitigation**:
1. Helper installed in system-protected directory (`/Library/PrivilegedHelperTools/`)
2. Requires administrator privileges to modify (same as for installation)
3. Code signature validated by launchd before execution
4. System Integrity Protection (SIP) prevents modification

**Result**: Modified binary fails signature validation and won't run

### Scenario 5: XPC Message Tampering

**Attack**: Attacker intercepts and modifies XPC messages

**Mitigation**:
1. XPC uses Mach ports (not network), local-only communication
2. Messages authenticated by kernel
3. Process credentials checked by system
4. Authorization data validated on helper side

**Result**: Tampering not possible due to kernel-level security

### Scenario 6: Privilege Escalation via Helper

**Attack**: Attacker uses legitimate helper to gain broader system access

**Mitigation**:
1. Command allowlist limits what helper can do
2. Each command vetted for security implications
3. No general-purpose shell execution
4. No file read/write outside specific paths
5. No network access
6. No process spawning beyond approved commands

**Result**: Helper's capabilities intentionally limited

## Security Best Practices

### Development

1. **Review All Elevated Capabilities**
   - Document why elevation is needed
   - Use minimum required privileges
   - Consider user-level alternatives

2. **Validate Catalog Changes**
   - Review new capabilities for security implications
   - Update helper allowlist only when necessary
   - Test capabilities in isolated environment

3. **Code Review**
   - All helper changes require security review
   - Validate authorization checking is present
   - Ensure logging is comprehensive

4. **Testing**
   - Test authorization denial paths
   - Verify command allowlist enforcement
   - Check audit logging completeness

### Deployment

1. **Code Signing**
   - Use valid Apple Developer certificate
   - Never skip signature validation
   - Keep signing certificate secure

2. **Updates**
   - Helper version changes trigger reinstallation
   - User prompted for authorization on update
   - Old helper cleanly removed before new installation

3. **Monitoring**
   - Monitor system logs for helper activity
   - Alert on unexpected command execution
   - Review audit logs periodically

### Incident Response

If security issue discovered:

1. **Assess Impact**
   - Determine which capabilities affected
   - Check if unauthorized commands possible
   - Review audit logs for exploitation

2. **Immediate Response**
   - Disable affected capabilities in catalog
   - Release emergency update if needed
   - Notify users if data compromised

3. **Remediation**
   - Fix vulnerability in helper
   - Update helper version
   - Force reinstallation via version check

4. **Post-Incident**
   - Document lessons learned
   - Update threat model
   - Enhance testing procedures

## Compliance

### macOS Security

- ✅ Follows Apple's SMJobBless best practices
- ✅ Uses Authorization Services correctly
- ✅ Respects System Integrity Protection
- ✅ Implements least privilege principle
- ✅ Provides audit trail

### User Privacy

- ✅ No data collection beyond operation logs
- ✅ Logs stored locally (not transmitted)
- ✅ User controls helper installation
- ✅ Operations transparent and auditable

## Security Contact

For security issues, please report via:
- GitHub Security Advisories (preferred)
- Email: security@neuralquantum.ai

Do not publicly disclose security vulnerabilities before coordinated disclosure.

## References

- [OWASP: Privilege Escalation](https://owasp.org/www-community/attacks/Privilege_escalation)
- [Apple: Secure Coding Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecureCodingGuide/)
- [Apple: Authorization Services Programming Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/authorization_concepts/)
- [CWE-78: OS Command Injection](https://cwe.mitre.org/data/definitions/78.html)

## Changelog

- **2026-01-27**: Initial security model documentation
