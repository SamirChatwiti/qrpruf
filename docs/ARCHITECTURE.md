# QRPruf — Architecture Overview

## Core Concept

QRPruf is a **zero-trust proof-of-presence protocol**. Each proof is a cryptographically sealed bundle: GPS coordinates, UTC timestamp, SHA-256 media hash, and user identity — signed server-side and encoded into a QR code. No server can forge a proof retroactively; no client can alter the timestamp or location.

---

## Layer Diagram

```
┌─────────────────────────────────────────────────────┐
│                   Flutter App (Client)               │
│                                                     │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────┐  │
│  │ Capture UI  │  │ ProofService │  │ CryptoSvc │  │
│  │ (Camera /   │→ │ (quota check,│→ │ (AES-GCM  │  │
│  │  Audio /    │  │  draft build,│  │  encrypt, │  │
│  │  Video)     │  │  upload)     │  │  SHA-256) │  │
│  └─────────────┘  └──────┬───────┘  └───────────┘  │
│                           │                         │
│  ┌────────────────────────▼────────────────────┐    │
│  │              Geolocator (GPS)                │    │
│  │  10s timeout — falls back to {0,0} gracefully│    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────┬───────────────────────────┘
                          │ HTTPS
┌─────────────────────────▼───────────────────────────┐
│                  Supabase (Backend)                  │
│                                                     │
│  ┌──────────────┐  ┌───────────────┐               │
│  │  Edge Fn     │  │  Storage      │               │
│  │ create_proof │  │ (proof-media  │               │
│  │  (sign+seal) │  │  bucket)      │               │
│  └──────┬───────┘  └───────────────┘               │
│         │                                           │
│  ┌──────▼──────────────────────────┐               │
│  │  PostgreSQL                     │               │
│  │  - proofs            (sealed)   │               │
│  │  - evidence_media    (hashes)   │               │
│  │  - users             (identity) │               │
│  └─────────────────────────────────┘               │
└─────────────────────────────────────────────────────┘
```

---

## Key Components

### `ProofService` (`lib/core/services/proof_service.dart`)
- Singleton. Manages the full proof lifecycle: draft creation → quota check → upload queue → Supabase edge function call.
- Upload uses **two strategies**: Supabase SDK first, raw HTTP fallback (handles network edge cases).
- Retry logic: 3 attempts with exponential back-off.

### `ProofCryptoService` (`lib/features/proofs/data/proof_crypto_service.dart`)
- AES-GCM 256-bit encryption, offloaded to Dart isolates to prevent UI freeze.
- Videos skip encryption (too large for in-memory AES) and are hash-only.

### `WassitSession` (`lib/wassit/session/wassit_session.dart`)
- In-memory session state for the current proof capture. Cleared on QR generation.

### Daily Quota Engine (inside `ProofService`)
| Media | Limit |
|-------|-------|
| Photos | 10 / day |
| Video | 60 s / day |
| Audio | 120 s / day |

Quota is checked against `evidence_media` table in real time before capture is allowed.

---

## Security Model

1. **On-device**: SHA-256 hash computed locally before upload — server cannot substitute a different file.
2. **Transport**: AES-GCM encrypted payload, HTTPS. Access token rotated per session.
3. **Server**: Edge function `create_proof` signs the proof with a server-side secret. The QR URL embeds the decryption key as a URL fragment (never sent to server).
4. **Verification**: Any verifier with the QR URL can recompute the hash and compare against the sealed proof record.

---

## Data Flow — Proof Generation

```
User captures media
        │
        ▼
[Quota check] ──exceed──▶ Block + message
        │ ok
        ▼
[GPS fix] (10s timeout, fallback {0,0})
        │
        ▼
[Draft created] — hash computed locally
        │
        ▼
[create_proof Edge Fn] — proof_id returned
        │
        ▼
[Background upload queue] — AES-GCM encrypted
        │
        ▼
[QR Code generated] — URL = qrpruf.com/p/proof.html?id=&key=#KEY
```

---

## WITI Ecosystem Position

```
QRPruf (this repo) ──── universal proof core
    │
    ├── NOUR (nour-mobile) — field app for judicial officers
    │       embeds QRPruf proof flow
    │
    └── Governance Platform — web admin for court management
            reads proof metadata via QRPruf API
```
