# Bureau ↔ Kiosk TLS mutual-auth runbook (PROD)  —  task-003.5

The UAT channel is plain TCP + a shared token. **PROD wraps it in TLS 1.2+ with mutual
authentication**: the Bureau is the TLS server and *requires* a valid client (fleet)
certificate; the Kiosk agent is the TLS client and presents its fleet cert *and* verifies
the Bureau's cert. Both sides pin the same **fleet CA**. A kiosk without a CA-signed cert
cannot complete the handshake — so only enrolled fleet devices reach the Bureau, and the
whole APDU channel (SAD) is encrypted on the wire.

Build the TLS-capable binaries with `-DPERSOENGINE_BUILD_TLS=ON` (links OpenSSL::SSL).
Without it the `--tls` flag is refused with a clear message; the plain UAT path is unchanged.

## 1. Generate the fleet PKI (one-time, on a trusted host)

```bash
# Fleet root CA — the trust anchor for every bureau + kiosk. Keep ca.key OFFLINE/HSM.
openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.pem -days 3650 \
  -subj "/O=BNPRS Fleet/CN=BNPRS Perso Fleet CA"

# Bureau server cert (one per bureau)
openssl req -newkey rsa:2048 -nodes -keyout bureau.key -out bureau.csr \
  -subj "/O=BNPRS Fleet/CN=perso-bureau"
openssl x509 -req -in bureau.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -out bureau.pem -days 825

# Kiosk (fleet) cert — one PER KIOSK; CN = the kiosk's hardwareId (audit trail)
openssl req -newkey rsa:2048 -nodes -keyout kiosk.key -out kiosk.csr \
  -subj "/O=BNPRS Fleet/CN=KIOSK-DXB-014"
openssl x509 -req -in kiosk.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -out kiosk.pem -days 825
```

Ship each kiosk **only** its own `kiosk.pem` + `kiosk.key` + the shared `ca.pem` — never
the CA key. If you hold fleet certs as `.pfx` (the k3_fleet_pfx pattern), convert once:
`openssl pkcs12 -in fleet.pfx -out fleet.pem -nodes` (then split cert/key if needed).

## 2. Run the Bureau (TLS server, mutual auth)

```bash
perso-bureau --port 9099 --token <token> \
  --tls --cert bureau.pem --key bureau.key --ca ca.pem \
  --keystore keys/uat_keystore.txt
```
Startup prints `… (PROD, TLS 1.2+ mutual auth; token required)`. Every accepted kiosk is
logged as `connected from <ip> (TLS, cert-verified)`.

## 3. Run the Kiosk agent (TLS client)

```bash
perso-kiosk-agent --bureau-host <bureau-ip> --bureau-port 9099 \
  --tls --cert kiosk.pem --key kiosk.key --ca ca.pem
```
The local trigger endpoint (127.0.0.1:9098) and its JSON request/response are **unchanged** —
the kiosk software calls it exactly as in the build guide; only the agent↔bureau hop is now
TLS. The trigger hop stays loopback-only.

## 4. Verified behaviour (pat-m4p, 2026-07-22)

| Case | Client cert | Result |
|------|-------------|--------|
| Enrolled kiosk | fleet-CA-signed | handshake OK, perso loop runs over TLS |
| Plain agent → TLS bureau | none | rejected (no handshake) |
| Rogue device | self-signed, not fleet CA | **rejected** — `SSL_accept: certificate verify failed` |

## 5. Connection-drop recovery

The Bureau's **finalize (SET STATUS → SECURED) is the LAST step**, gated on a passing GPO.
So:
- **Link drops before finalize** → the card was never secured. The Kiosk agent **rejects**
  the card locally (it never ejects a card the Bureau did not confirm complete); retry a
  fresh card.
- **Link drops after finalize** → the card is already a valid personalized card.

The agent enforces this: any bureau-link failure while a card is open triggers a local
`reject()` and a `{"status":"fail","detail":"link lost: …"}` result to the kiosk.
