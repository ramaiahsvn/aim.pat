# RM Feature Inventory (KMS_359_RMpdf.pdf, D1245808D, 460pp)

Authoritative feature list extracted from the Gemalto KMS v3 RM table of
contents, for the Rust/Tauri rewrite (trp1003.phsm.kms.fe, ai_dev).
Living implementation status in docs/rust-migration/ROADMAP.md.

## Chapter map
- Ch1 Master Key (concepts)
- Ch2 licensing — OUT OF SCOPE
- Ch3 Setting up KMS: master-key from parts (generate/import/activate via
  KMS-screens AND trusted-path), master-key state, key storage
  (CoreConfiguration.xml), PKCS#10 cert request profile
- Ch4 HSM admin (SafeNet — mostly out of scope) + Transport Mode feature
  (check/change transport mode value)
- Ch5 Key Administration Module (THE BIG ONE, pp.115-321)
- Ch6-9 KMS Server, log files, key cache, backup/restore location
- Ch10 + App A-H: key natures/types matrix (App A), KMS Key Card, Windows
  Log Server (App H — out of scope), etc.

## Ch5 feature checklist (DONE vs TODO)
DONE (4a/5a/6a): issuer refs CRUD, key contexts CRUD, symmetric key create
(single component, HSM-gen), edit/revoke/suspend/delete, versions +
default version, key status/expiry, CA CRUD, CA public-key import (generic),
SO1-3 endorsement, backup/restore.

TODO Ch5 keys: transport keys (import/generate, cleartext+trusted-path,
security levels), RSA key create/generate, ECC key create/generate,
symmetric by-parts, import symmetric encrypted-by-transport-key, import
symmetric cleartext, delete key VALUE (keep metadata), import public key
from external cert, export RSA modulus (MULTOS), export multiple keys
(symmetric transport / asymmetric transport), import multiple keys
(container file / RSA CT6 format / OGDC), export key profiles, change KMS
Key Card PIN, key natures/types full Appendix-A matrix.

TODO Ch5 CA/certs: per-scheme CA public-key import screens (VISA/MC/X509/
MULTOS TKCK/GCB/JCB/AMEX/INTERAC/CUP/DFS/ERCA/MSCA/StepNexus/NSPK), display
CA key, endorse X509 CA key (screens+trusted-path). Issuer Public Key
Certificates (IPK): per-scheme (VISA/MCI/GCB/JCB/AMEX/INTERAC/CUP/DFS/
MULTOS/NSPK/X509), import-without-request, chained X509, generate P10
request, import cert, import chained, endorse X509 IPK cert.

TODO Ch4/6-9: transport mode check/change; KMS server start/stop/service
(Win/Linux); backup/restore location config; log files config; key cache
(local/remote generation).

## Scale note
Hundreds of discrete features → multi-session effort. Building in
fully-tested batches by RM section, not stubs. Real-HSM FFI for many ops
returns CKR_FUNCTION_NOT_SUPPORTED until host API gains entry points; mock
implements real deterministic logic so the flows are testable end-to-end.
