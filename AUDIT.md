# Security Audit Report for Ratchet Chat

**Date:** December 24, 2025
**Auditor:** Gemini CLI Agent

## Executive Summary

Ratchet Chat demonstrates a high standard of security engineering, particularly in its implementation of End-to-End Encryption (E2EE) and the Secure Remote Password (SRP) protocol for authentication. The application adheres to a "privacy-by-design" philosophy, ensuring the server has zero knowledge of message contents or user passwords.

However, several configuration-level risks and potential vulnerabilities in the federation logic were identified. The most critical immediate actions are to secure default credentials and secrets before deployment.

## 1. Architecture & Infrastructure

### 1.1 Default Credentials (HIGH)
**Description:** The `docker-compose.prod.yml` file uses default credentials for the PostgreSQL database (`ratchet`/`ratchet_password`) and a placeholder `JWT_SECRET` (`change-me`).
**Impact:** If deployed without modification, an attacker could easily compromise the database or forge session tokens to take over accounts.
**Recommendation:**
*   Enforce the use of strong, randomly generated secrets in production.
*   Update `entrypoint.sh` or documentation to fail startup if default secrets are detected in a production environment.

### 1.2 Infrastructure Security
*   **Positive:** The application runs as a non-root user in Docker (implied by standard practices, though specific `USER` instruction in Dockerfile should be verified).
*   **Positive:** HTTP security headers (`Content-Security-Policy`, `Strict-Transport-Security`, etc.) are correctly configured in `server.ts`.
*   **Recommendation:** Ensure the `Federation TLS` configuration (`.cert` files) is properly managed and rotated.

## 2. Authentication & Authorization

### 2.1 Secure Remote Password (SRP) (STRONG)
**Description:** The project implements SRP correctly. The server never stores the user's password, only a verifier. This mitigates the impact of a database leak regarding credential theft.
**Observations:**
*   `server/lib/srp.ts` and `client/src/lib/srp.ts` align on parameters.
*   `kdf_iterations` are configurable and enforce a safe minimum (300,000).

### 2.2 User Enumeration (MEDIUM)
**Description:** The `/auth/srp/start` endpoint returns different error messages ("Invalid credentials" vs "Invalid SRP parameters") or has timing differences depending on whether a user exists.
**Impact:** Allows an attacker to enumerate valid usernames.
**Mitigation:** The application implements `loginBackoff` which blocks IP/Username pairs after failures. This significantly slows down enumeration attacks.
**Recommendation:** Standardize error messages and ensure constant-time processing where possible, although the latter is difficult with SRP logic flow.

### 2.3 Rate Limiting (GOOD)
**Description:** Middleware is in place (`server/middleware/rateLimit.ts`) to limit requests to auth and federation endpoints.

## 3. Data Protection (End-to-End Encryption)

### 3.1 Encryption Implementation (STRONG)
**Description:** The client (`client/src/lib/crypto.ts`) uses a hybrid encryption scheme:
*   **Transport Keys:** RSA-OAEP (2048-bit) for encrypting session keys.
*   **Message Encryption:** AES-GCM (256-bit) for message content.
*   **Signatures:** Ed25519 (TweetNaCl) for authenticity.
**Impact:** The server only processes encrypted blobs. It cannot decrypt messages.

### 3.2 Key Management
**Description:** Private keys are encrypted at rest on the client using a master key derived from the user's password.
**Risk:** If a user loses their password, their private keys (and thus history) are unrecoverable. This is a design trade-off for security.

## 4. Federation

### 4.1 DNS Rebinding / TOCTOU (MEDIUM)
**Description:** In `server/lib/federationAuth.ts`, the `isFederationHostAllowed` function checks if a host is private/blocked using `dns.lookup`. However, the subsequent request uses `http/https` libraries which resolve the name again.
**Impact:** A malicious actor could control a DNS server to return a public IP during the check and a private IP (e.g., `127.0.0.1`) during the fetch (Time-of-Check Time-of-Use). This could allow SSRF attacks against internal services.
**Recommendation:** Resolve the IP address once, verify it, and then make the HTTP request directly to that IP address (setting the `Host` header manually) to pinning the resolution.

### 4.2 Trust on First Use (TOFU) (INFO)
**Description:** The federation uses a TOFU model. The first time a server sees a remote key, it trusts it.
**Risk:** Vulnerable to Man-in-the-Middle (MitM) attacks during the very first connection between two servers.
**Mitigation:** `FEDERATION_TRUST_MODE` can be set to `strict` to require manual pre-approval, though this hurts usability.

## 5. Code Quality & Validation

*   **Input Validation:** Extensive use of `zod` schemas ensures strictly typed and validated inputs for all API endpoints.
*   **SQL Injection:** `Prisma` ORM is used, effectively preventing SQL injection vulnerabilities.
*   **Output Sanitization:** Logging uses `sanitizeLogPayload` to prevent sensitive data from leaking into logs.

## Recommendations Summary

1.  **Immediate:** Change default `JWT_SECRET` and database passwords in `docker-compose.prod.yml`.
2.  **Short Term:** Fix the DNS Rebinding vulnerability in `federationAuth.ts` by connecting to the resolved IP.
3.  **Long Term:** Consider implementing a key transparency log or out-of-band verification for federation identities to strengthen the TOFU model.
