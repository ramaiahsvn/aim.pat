# Fleet certificate setup (PROD mutual TLS)

The TLS build (`perso-kiosk-agent-tls.exe`) and the bureau authenticate each other with X.509
certificates from a private **fleet PKI**: one root CA, one bureau server cert, and one cert
per kiosk. Both sides pin the same CA, so **only enrolled fleet devices can connect** and the
whole APDU channel is encrypted on the wire.

## 1. Generate the PKI (once, on a trusted host)

```bash
./gen-fleet-certs.sh fleet-pki KIOSK-DXB-014 KIOSK-DXB-015   # add every kiosk hardwareId
```
This creates, under `fleet-pki/`:
- `ca.pem` / `ca.key` — the root CA. **`ca.key` is the trust anchor — keep it OFFLINE / in an HSM. Never ship it.**
- `bureau.pem` / `bureau.key` — the bureau server cert.
- `kiosk-<ID>.pem` / `kiosk-<ID>.key` — one per kiosk; the cert **CN = the kiosk hardwareId**
  (so the bureau's audit log ties a session to a device).

> Runs anywhere openssl is installed — Linux/macOS, or Git-Bash / WSL / `openssl.exe` on
> Windows (identical commands). If you already hold certs as `.pfx` (the k3_fleet_pfx pattern),
> convert once: `openssl pkcs12 -in fleet.pfx -out fleet.pem -nodes`.

Verify any leaf chains to the CA:
```bash
openssl verify -CAfile fleet-pki/ca.pem fleet-pki/bureau.pem fleet-pki/kiosk-KIOSK-DXB-014.pem
```

## 2. Distribute (least privilege)

| Host   | Give it | Never give it |
|--------|---------|---------------|
| Bureau | `bureau.pem`, `bureau.key`, `ca.pem` | any kiosk key, `ca.key` |
| Kiosk  | its own `kiosk-<ID>.pem`, `kiosk-<ID>.key`, `ca.pem` | any other kiosk's key, `bureau.key`, `ca.key` |

## 3. Run with TLS

Bureau:
```bash
perso-bureau --port 9099 --token <token> --max-workers 16 \
  --tls --cert bureau.pem --key bureau.key --ca ca.pem
```
Kiosk (the `-tls` exe):
```bash
perso-kiosk-agent-tls.exe --bureau-host <BUREAU_IP> --bureau-port 9099 \
  --tls --cert kiosk-KIOSK-DXB-014.pem --key kiosk-KIOSK-DXB-014.key --ca ca.pem
```

## 4. What "mutual auth" enforces (verified behaviour)

- Enrolled kiosk (fleet-CA cert) → handshake succeeds, session runs over TLS 1.2+.
- A **plain** client → refused (no TLS handshake).
- A **rogue** cert not signed by the fleet CA → refused (`certificate verify failed`).

TLS terminates in the exe (OpenSSL is statically linked — no OpenSSL install on the kiosk).
Cert loading uses the PEM files you pass, not the Windows system store.

## 5. Renewal / revocation

- Leaf certs are valid 825 days (`DAYS_LEAF`), the CA 10 years. Re-run `gen-fleet-certs.sh`
  with the same output dir to mint more kiosk certs (the CA + bureau are reused, not regenerated).
- To retire a kiosk before expiry, stop honouring its cert at the bureau (rotate the CA or add a
  CRL/allow-list). For a small fleet, rotating the fleet CA + re-issuing is simplest.
