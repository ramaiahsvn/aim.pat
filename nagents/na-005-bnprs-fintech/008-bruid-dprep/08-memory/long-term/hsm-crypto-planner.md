---
name: HSM / Crypto Planner — bruid-dprep
description: The authoritative HSM/crypto plan for the BRUID perso engine, owned by bruid-dprep. Defines the IHsmClient seam, the derivation/crypto algorithms (EMV Option A UDK, KCV, SCP02 session keys + C-MAC, ISO 9564-1 PIN block, Visa CVV/PVV), the backend strategy (reuse bpr.cpp BprCrypt for dev/test → real HSM/KMS for prod), and the verification-vector strategy. Grounded in the existing bpr.cpp codebase.
type: project
---

> **Owner:** bruid-dprep (na-005/008) — "maintain the HSM planner part in dprep" (user, 2026-07-04).
> **Consumers:** bruid-cperso (009, central), bruid-iperso (010, instant/kiosk).
> **Engine phase:** P3 in the perso-engine roadmap. See `perso-engine-handoff.md` +
> rnd-cperso's `emv-engine-architecture.md` / `hsm-integration-analysis.md` (Operas macro map).
> **Guardrail:** keys addressed by **LABEL only** — never a key VALUE in code/files/logs (PCI).

## 0. Decisions resolved here (were open forks)

| Fork | Decision (planner recommendation) | Rationale |
|---|---|---|
| Dev/test HSM backend | **Reuse `bpr.cpp` `BprCrypt`** behind `IHsmClient` — **drop SoftHSM2/PKCS#11** | BprCrypt already ships DES/DES3/DES3CBC + `patEncryptDecrypt3Des`, `patEncryptDecrypt_Pinblock`, `patSupervisorKey3Des` and even an OpenSSL DES3-CBC path. No new dependency, already builds in-tree, block-level 3DES is exactly what UDK/KCV/SCP02 need. |
| Production HSM backend | **Adapter behind the same seam** → remote KMS (`kms.bnprs.ai`, already used by the Qi/instant path) for supervisor/session ops; a central-bureau HSM adapter (Thales KMS/Operas or payShield) added later | Keeps the seam stable; central vs instant differ only in the backend impl. |
| Reference-vector source | **Public KATs first** (FIPS DES/3DES, EMV Book 2 Option-A, GP SCP02, Visa CVV/PVV); issuer test keys/KCVs later | Proves algorithm correctness now without real keys; realistic end-to-end vectors need the outstanding issuer keys (below). |

> These are planner recommendations — the user may override. They unblock implementation now.

## 1. The `IHsmClient` seam

One interface, three backends (dev = BprCrypt; prod-central = HSM adapter; prod-instant = KMS).
Keys referenced by **label**; the backend resolves label → key handle (never exposes the value).

```cpp
namespace hsm {
struct IHsmClient {
  virtual ~IHsmClient() = default;
  // --- EMV key derivation ---
  virtual Bytes derive_udk(std::string_view imkLabel, const Bytes& pan, const Bytes& psn) = 0; // Option A
  virtual Bytes kcv(std::string_view keyLabel) = 0;                        // 3-byte KCV
  virtual Bytes export_under_kek(std::string_view kekLabel, std::string_view keyLabel) = 0;
  // --- GlobalPlatform SCP02 ---
  virtual Scp02Session derive_scp02(std::string_view baseKeyLabel, uint16_t seqCounter) = 0;
  virtual Bytes cmac_scp02(const Bytes& sMac, const Bytes& icv, const Bytes& apdu) = 0;
  // --- data-prep security values ---
  virtual Bytes pin_block_iso0(std::string_view pinKeyLabel, const Bytes& pan, const Bytes& pin) = 0;
  virtual std::string cvv(std::string_view cvkLabel, const Bytes& pan, const Bytes& expiry, const Bytes& svc) = 0;
  virtual std::string pvv(std::string_view pvkLabel, const Bytes& pan, uint8_t pvki, const Bytes& pin) = 0;
  // --- offline data auth (later; RSA) ---
  virtual RsaKeyPair gen_icc_rsa(int bits) = 0;
  virtual Bytes      sign_sda(std::string_view issuerKeyLabel, const Bytes& staticData) = 0;
};
class BprCryptHsm : public IHsmClient { /* dev/test — wraps BprCrypt DES3/DES3CBC */ };
class KmsHsm      : public IHsmClient { /* prod — kms.bnprs.ai / central HSM adapter */ };
}
```

## 2. Algorithm specifications (dev backend = BprCrypt)

### 2.1 EMV Option A — Master/UDK derivation (3DES)
Per EMV Book 2 / EMV CPS, "Option A" (a.k.a. Method A):
1. `Y = rightmost 16 digits of (PAN ∥ PSN)` (PSN default `00`); pack as 8 bytes BCD → `ZL`.
2. `ZR = ZL XOR 0xFFFFFFFFFFFFFFFF`.
3. `MK_L = DES3_enc(IMK, ZL)`, `MK_R = DES3_enc(IMK, ZR)` (IMK is double-length).
4. `MK = MK_L ∥ MK_R`, then **odd-parity adjust** each byte.
   → via `BprCrypt::patEncryptDecrypt3Des(ZL, k1,k2,k1, true)` (double-length IMK = k1,k2,k1).

### 2.2 KCV (3-byte)
`KCV = leftmost 3 bytes of DES3_enc(key, 0x00000000_00000000)`.

### 2.3 SCP02 session keys + C-MAC (GlobalPlatform Card Spec)
- Derivation data `D = constant(2) ∥ seqCounter(2) ∥ 0x00 ×12`; constants:
  `C-ENC=0x0182`, `C-MAC=0x0101`, `DEK=0x0181`, `R-MAC=0x0180` *(confirm against GP appendix before lock)*.
- `SK = DES3_CBC_enc(baseKey, IV=0, D)`.
- C-MAC = ISO 9797-1 **MAC algorithm 3** (retail MAC: single-DES chain, final block 3DES) over the
  APDU with the SCP02 ICV chaining. Card cryptogram / host cryptogram per SCP02.
- **Acceptance oracle:** the Gemalto trace confirms SCP02 (`8050 0000 08 <host chal>` → `611C`).

### 2.4 PIN block — ISO 9564-1 Format 0
`PINfield = 0x0 ∥ len ∥ PIN ∥ F-pad`; `PANfield = 0x0000 ∥ 12 rightmost PAN digits (excl. check)`;
`block = PINfield XOR PANfield`; `encPB = DES3_enc(PINkey, block)`.
→ `BprCrypt::patEncryptDecrypt_Pinblock` already exists — align to it.

### 2.5 Visa CVV / iCVV / CVV2  and  Visa PVV
- **CVV**: input = `PAN ∥ ExpiryDate ∥ ServiceCode` (16 nibbles, split into two 8-byte blocks B1,B2);
  `A = DES_enc(CVK_A, B1)`; `C = DES_dec(CVK_B, A XOR B2)`… decimalize → 3 digits. **iCVV** uses service
  code `999`; **CVV2** uses service code `000`.
- **PVV**: `TSP = 11 rightmost PAN digits (excl. check) ∥ PVKI ∥ 4 PIN digits`; `DES3(PVK, TSP)`;
  decimalize (skip non-decimal, then A-F→0-5) → 4 digits.
- These need issuer **CVK/PVK/PIN keys** (labels) from **na-003/007-bnprs-grc-kms**.

## 3. Key inventory (labels only — coordinate with na-003/007-bnprs-grc-kms)

| Label (example) | Type | Use |
|---|---|---|
| `IMK-AC`, `IMK-SMI`, `IMK-SMC` | 2TDEA | EMV UDK derivation (Option A) |
| `KEK` / `TK` (transport) | 2TDEA | Key-block export to card |
| `PIN-TK` | 2TDEA | PIN block encryption (ISO-0) |
| `CVK-A/CVK-B` | 2TDEA | CVV / iCVV / CVV2 |
| `PVK` | 2TDEA | Visa PVV |
| `KMC-Calypso` (CI/TP/TV/TS/TR/TD) | 2TDEA | Calypso/TRANSLINK (bruid-cperso P6) |

Real key VALUES + diversification data live only in the HSM / KMS. Operas macro map
(`BatchDerivation`, `ExportDESKey`, `CalculateKCV`, `TranslateDESKeyBlock`) is in rnd-cperso's
`hsm-integration-analysis.md`.

## 4. Verification-vector strategy
- **KAT anchor (fully known):** single/3DES-ECB of `0x0000000000000000` under key
  `0x0123456789ABCDEF` = `0xD5D44FF720683D0D` → `KCV = D5D44F`. Use to smoke-test the BprCrypt path.
- **UDK / SCP02 / CVV / PVV:** use published spec test vectors (EMV Book 2, GP SCP02, Visa) —
  do NOT fabricate. Encode them as fixtures once transcribed from the specs.
- **Realistic issuer vectors:** blocked on the outstanding issuer test keys/KCVs (§5).

## 5. Outstanding inputs (needed for realistic vectors, NOT for algorithm work)
- [ ] Issuer **test keys / KCVs** (from na-003/007-bnprs-grc-kms) — labels + KCVs, never values.
- [ ] Confirm SCP02 session-key **derivation constants** against the GP appendix before lock.
- [ ] Confirm STORE DATA `P1=0x60` block semantics from the Gemalto trace (with bruid-cperso).

## 6. Sequencing (feeds task-001.2)
P3a interface + `BprCryptHsm` (UDK + KCV, KAT-verified) → P3b PIN block (align to `patEncryptDecrypt_Pinblock`)
→ P3c CVV/PVV (needs na-003/007 keys) → P3d SCP02 session keys + C-MAC (trace-aligned) →
P3e `KmsHsm` prod adapter. Each step KAT/vector-gated before the next.
