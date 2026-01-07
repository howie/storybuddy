# Security & Privacy Requirements Quality Checklist: Flutter Mobile App

**Purpose**: Deep-dive security and privacy requirements validation - addresses gaps from full-feature checklist
**Created**: 2026-01-05
**Feature**: [spec.md](../spec.md) | [plan.md](../plan.md) | [constitution.md](../../../.specify/memory/constitution.md)
**Depth**: Standard (thorough domain-specific review)
**Audience**: Reviewer (security/privacy focused)
**Supplements**: [full-feature.md](./full-feature.md) - addresses CHK051-CHK057 gaps

---

## Voice Data Protection

- [ ] CHK001 - Is the voice sample classified as biometric/sensitive data in requirements? [Clarity, Gap]
- [ ] CHK002 - Are voice sample encryption requirements specified for at-rest storage (algorithm, key size)? [Gap, Spec §PS-001]
- [ ] CHK003 - Are voice sample encryption requirements specified for in-transit transmission? [Completeness, Spec §PS-002]
- [ ] CHK004 - Is the voice sample format (WAV 44.1kHz) validated against encryption compatibility? [Consistency, Spec §TR-003]
- [ ] CHK005 - Are requirements defined for voice sample integrity verification (checksums, signatures)? [Gap]
- [ ] CHK006 - Is temporary voice data (during recording) protection specified? [Gap]
- [ ] CHK007 - Are requirements defined for secure deletion of voice samples (not just file deletion)? [Gap, Spec §PS-004]
- [ ] CHK008 - Is voice sample access logging/auditing specified? [Gap, Constitution §IV]

## Children's Privacy (COPPA/GDPR-K Alignment)

- [ ] CHK009 - Are parental consent requirements specified before any child data collection? [Gap, Constitution §Children's Safety]
- [ ] CHK010 - Is the age verification mechanism for "child user" defined in requirements? [Gap]
- [ ] CHK011 - Are requirements defined for what constitutes "child data" vs "parent data"? [Clarity, Gap]
- [ ] CHK012 - Is the data minimization principle explicitly stated for child interactions? [Gap, Constitution §Privacy]
- [ ] CHK013 - Are requirements specified for child data retention limits? [Gap, Constitution §Privacy]
- [ ] CHK014 - Is parental access to child's Q&A history explicitly required? [Completeness, Spec §US7]
- [ ] CHK015 - Are requirements defined for preventing direct contact with children (no push notifications to child)? [Gap]
- [ ] CHK016 - Is the "pending questions" feature compliant with not storing excessive child data? [Consistency, Constitution §Privacy]

## Consent & Disclosure

- [ ] CHK017 - Are privacy consent dialog content requirements fully specified? [Gap, Spec §PS-003]
- [ ] CHK018 - Is the timing of consent collection specified (before recording, app launch)? [Clarity, Spec §PS-003]
- [ ] CHK019 - Are consent versioning requirements defined (re-consent on policy changes)? [Gap]
- [ ] CHK020 - Is consent revocation process specified in requirements? [Gap]
- [ ] CHK021 - Are third-party data sharing disclosures specified (ElevenLabs, Azure, Anthropic)? [Gap, Constitution §Privacy]
- [ ] CHK022 - Is the disclosure format for third-party sharing defined (in-app, legal docs)? [Clarity, Gap]
- [ ] CHK023 - Are requirements defined for consent audit trail/logging? [Gap]
- [ ] CHK024 - Is granular consent specified (voice cloning vs Q&A vs story generation separately)? [Gap]

## Data Encryption Specifications

- [ ] CHK025 - Is the encryption algorithm for local cache specified (AES-256, ChaCha20)? [Clarity, Spec §PS-001]
- [ ] CHK026 - Is encryption key derivation method specified (PBKDF2, Argon2)? [Gap]
- [ ] CHK027 - Is encryption key storage location specified (Keychain, EncryptedSharedPreferences)? [Clarity, Spec §TR-005]
- [ ] CHK028 - Are requirements defined for encryption key rotation? [Gap]
- [ ] CHK029 - Is the TLS version pinned (1.2 only, 1.2+, 1.3 preferred)? [Clarity, Spec §PS-002]
- [ ] CHK030 - Are certificate pinning requirements specified for API communication? [Gap]
- [ ] CHK031 - Is encrypted storage for tokens specified beyond "flutter_secure_storage"? [Clarity, Spec §TR-005]
- [ ] CHK032 - Are requirements defined for handling encryption failures (corrupted data)? [Gap, Exception Flow]

## Authentication & Authorization

- [ ] CHK033 - Are authentication requirements for parent accounts specified? [Gap]
- [ ] CHK034 - Is the authentication method defined (email/password, OAuth, biometric)? [Gap]
- [ ] CHK035 - Are session management requirements specified (timeout, refresh)? [Gap, Spec §TR-005]
- [ ] CHK036 - Is token expiration handling defined in requirements? [Gap]
- [ ] CHK037 - Are requirements defined for secure logout (token invalidation)? [Gap]
- [ ] CHK038 - Is re-authentication required for sensitive operations (delete data, change voice)? [Gap]
- [ ] CHK039 - Are requirements defined for preventing unauthorized voice profile access? [Gap]
- [ ] CHK040 - Is device binding/multi-device access specified? [Gap]

## API Security

- [ ] CHK041 - Are API authentication requirements consistent with backend contract? [Consistency, contracts/openapi.yaml]
- [ ] CHK042 - Are rate limiting requirements specified to prevent abuse? [Gap]
- [ ] CHK043 - Is input validation specified for all user-provided data to API? [Gap]
- [ ] CHK044 - Are requirements defined for handling API security errors (401, 403)? [Gap]
- [ ] CHK045 - Is request signing or HMAC verification specified? [Gap]
- [ ] CHK046 - Are requirements defined for preventing replay attacks? [Gap]
- [ ] CHK047 - Is API versioning security (deprecated version handling) specified? [Gap]

## Local Data Security

- [ ] CHK048 - Are requirements defined for preventing screenshot capture of sensitive screens? [Gap]
- [ ] CHK049 - Is clipboard security specified (no voice data in clipboard)? [Gap]
- [ ] CHK050 - Are requirements defined for app backgrounding security (hide content)? [Gap]
- [ ] CHK051 - Is debug logging security specified (no sensitive data in logs)? [Gap, Constitution §IV]
- [ ] CHK052 - Are requirements defined for secure data export/backup? [Gap]
- [ ] CHK053 - Is requirements defined for cache size limits (prevent DoS via cache)? [Gap, Spec §FR-014]
- [ ] CHK054 - Are requirements defined for database access protection (SQLCipher)? [Gap]

## Data Deletion & Retention

- [ ] CHK055 - Is the scope of "刪除本地資料" fully enumerated? [Clarity, Spec §PS-004]
- [ ] CHK056 - Are server-side deletion requirements specified (voice model, stories)? [Gap]
- [ ] CHK057 - Is the deletion confirmation flow specified? [Completeness, Spec §PS-004]
- [ ] CHK058 - Are data retention periods specified for each data type? [Gap, Constitution §Privacy]
- [ ] CHK059 - Is automatic data expiration/cleanup specified? [Gap]
- [ ] CHK060 - Are requirements defined for data export before deletion (GDPR right)? [Gap]
- [ ] CHK061 - Is cascade deletion specified (delete story → delete Q&A → delete pending questions)? [Gap]

## Threat Model Coverage

- [ ] CHK062 - Is a threat model documented for the mobile app? [Gap]
- [ ] CHK063 - Are requirements aligned to identified threats? [Traceability, Gap]
- [ ] CHK064 - Are requirements defined for device theft/loss scenarios? [Gap, Exception Flow]
- [ ] CHK065 - Are requirements defined for malicious app impersonation? [Gap]
- [ ] CHK066 - Are requirements defined for man-in-the-middle attack prevention? [Gap]
- [ ] CHK067 - Are requirements defined for reverse engineering protection? [Gap]
- [ ] CHK068 - Are requirements defined for jailbreak/root detection? [Gap]

## Incident Response

- [ ] CHK069 - Are requirements defined for security breach notification? [Gap]
- [ ] CHK070 - Are requirements defined for remote data wipe capability? [Gap]
- [ ] CHK071 - Are requirements defined for forced logout on security events? [Gap]
- [ ] CHK072 - Is security logging for incident investigation specified? [Gap, Constitution §IV]

---

## Gap Summary

| Category | Total Items | Gaps Identified |
|----------|-------------|-----------------|
| Voice Data Protection | 8 | 7 |
| Children's Privacy | 8 | 7 |
| Consent & Disclosure | 8 | 7 |
| Data Encryption | 8 | 5 |
| Authentication & Authorization | 8 | 8 |
| API Security | 7 | 6 |
| Local Data Security | 7 | 7 |
| Data Deletion & Retention | 7 | 5 |
| Threat Model Coverage | 7 | 7 |
| Incident Response | 4 | 4 |
| **Total** | **72** | **63** |

## Priority Recommendations

**Critical (Must address before implementation):**
1. CHK001-CHK008: Voice biometric data classification and protection
2. CHK009-CHK016: COPPA/GDPR-K compliance for children's data
3. CHK025-CHK032: Encryption specification details

**High (Should address before MVP):**
4. CHK017-CHK024: Consent mechanism completeness
5. CHK033-CHK040: Authentication flow specification
6. CHK055-CHK061: Data deletion scope

**Medium (Address before public release):**
7. CHK041-CHK047: API security hardening
8. CHK062-CHK068: Threat model documentation

---

## Notes

- This checklist supplements `full-feature.md` CHK051-CHK057
- Items marked `[Gap]` represent missing requirements that MUST be added
- Voice data requires special handling as biometric-adjacent data
- COPPA compliance is mandatory for US child users
- Consider security review before implementation begins
