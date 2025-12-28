# Security Policy

## Supported Versions

Only the latest version of Ratchet Chat is currently supported with security updates.

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1.0 | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability within Ratchet Chat, please report it privately. Do **NOT** open a public GitHub issue.

### Process

1.  **Email:** Send an email to `security@ratchet.chat` (replace with actual security contact if available, otherwise use project maintainer).
2.  **Details:** Please include as much detail as possible:
    *   Type of vulnerability (e.g., XSS, SQLi, E2EE bypass).
    *   Steps to reproduce.
    *   Impact assessment.
    *   Proof of Concept (PoC) code or screenshots.
3.  **Response:** We will acknowledge your report within 48 hours and provide an estimated timeline for a fix.

## Security Architecture

Ratchet Chat is designed with a "privacy-by-design" philosophy.

### End-to-End Encryption (E2EE)
*   **Protocol:** Messages are encrypted on the client device using a hybrid scheme (ML-KEM-768 for transport key exchange + AES-GCM for payload encryption).
*   **Identity & Signing:** Users publish ML-DSA-65 public keys. Message and control events are signed with ML-DSA-65 and verified by recipients.
*   **Zero Knowledge:** The server stores only encrypted blobs (`encrypted_blob`) and initialization vectors (`iv`). It does not possess the private keys required to decrypt user messages.
*   **Key Management:** Private keys are stored locally in the browser (IndexedDB), encrypted with a master key derived from the user's password (PBKDF2).

### Authentication
*   **OPAQUE:** We use the OPAQUE protocol (RFC 9497) for password authentication. The server never sees or stores the user's plain-text password, only a password file.
*   **JWT:** Post-authentication sessions are managed via JSON Web Tokens.

### Federation Security
*   **TOFU (Trust On First Use):** Federated identities are trusted on the first connection.
*   **Signatures:** All federated messages are signed using ML-DSA-65 keys to ensure authenticity.
*   **Allowlist:** Federation can be restricted to specific hosts via environment variables.

## Post-Quantum Cryptography

Ratchet Chat uses NIST-standardized post-quantum primitives:

*   **ML-KEM-768 (FIPS 203)** replaces RSA-OAEP for transport key encapsulation.
*   **ML-DSA-65 (FIPS 204)** replaces Ed25519 for identity keys and signatures.
*   **OPAQUE (RFC 9497)** replaces SRP for password authentication.

These primitives are implemented in pure JavaScript and are used end-to-end across client and server.

## Performance Compared to RSA/AES/SRP

Post-quantum primitives trade larger keys and signatures for quantum resistance:

*   **Bandwidth:** ML-DSA signatures and ML-KEM ciphertexts are significantly larger than Ed25519 signatures and RSA-2048 ciphertexts, so payloads and directory entries are larger.
*   **CPU:** ML-DSA and ML-KEM operations are more computationally expensive than Ed25519/RSA on most platforms. Key generation and signing/verification cost more.
*   **Login flow:** OPAQUE performs more cryptographic work than SRP but runs only during registration/login. Session traffic remains JWT-based.
*   **Message encryption:** Payload encryption still uses AES-GCM, so bulk message throughput is largely unchanged; the added cost comes from larger signatures and KEM encapsulation/decapsulation.

We do not publish benchmarks in this repository. Real-world performance depends on device class, runtime, and network conditions.

## Known Limitations / Threat Model

*   **Metadata:** The server knows *who* is messaging *whom* and *when* (metadata), but not *what* they are saying.
*   **Client Security:** The security of the E2EE scheme relies on the security of the user's device. Malware on the client device could compromise keys or messages.
*   **Federation Trust:** The current TOFU model for federation means a sophisticated Man-in-the-Middle (MitM) attack during the very first exchange could theoretically compromise a federated session.
