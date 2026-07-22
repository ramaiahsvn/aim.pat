#!/usr/bin/env bash
# Generate the BNPRS perso FLEET PKI: one root CA, one bureau server cert, and one cert per kiosk.
# Run this ONCE, on a TRUSTED host, with openssl installed (Linux/macOS, or Git-Bash/WSL/openssl.exe on
# Windows — the openssl commands are identical). Everything lands in the output dir.
#
# Usage:   ./gen-fleet-certs.sh [out-dir] KIOSK-ID [KIOSK-ID ...]
# Example: ./gen-fleet-certs.sh fleet-pki KIOSK-DXB-014 KIOSK-DXB-015
#
# SHIP:  - to the BUREAU host:  bureau.pem + bureau.key + ca.pem
#        - to EACH kiosk:        its own kiosk-<ID>.pem + kiosk-<ID>.key + ca.pem   (NOTHING else)
# NEVER ship ca.key — it is the trust anchor's private key; keep it OFFLINE / in an HSM.
set -euo pipefail

OUT="${1:-fleet-pki}"; shift || true
DAYS_CA=3650
DAYS_LEAF=825
mkdir -p "$OUT"; cd "$OUT"

if [ ! -f ca.pem ]; then
    openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.pem -days "$DAYS_CA" \
        -subj "/O=BNPRS Fleet/CN=BNPRS Perso Fleet CA"
    echo "created root CA -> ca.pem (keep ca.key OFFLINE)"
fi

sign() {  # <common-name> <basename>
    local cn="$1" name="$2"
    openssl req -newkey rsa:2048 -nodes -keyout "$name.key" -out "$name.csr" -subj "/O=BNPRS Fleet/CN=$cn"
    openssl x509 -req -in "$name.csr" -CA ca.pem -CAkey ca.key -CAcreateserial -out "$name.pem" -days "$DAYS_LEAF"
    rm -f "$name.csr"
    echo "signed $name.pem (CN=$cn)"
}

[ -f bureau.pem ] || sign "perso-bureau" bureau     # one bureau server cert (re-run-safe)

for kid in "$@"; do sign "$kid" "kiosk-$kid"; done   # one cert per kiosk hardwareId

echo
echo "PKI in: $(pwd)"
echo "  bureau:  bureau.pem bureau.key  (+ ca.pem)"
echo "  kiosks:  kiosk-<ID>.pem kiosk-<ID>.key  (+ ca.pem)"
echo "verify a leaf:  openssl verify -CAfile ca.pem bureau.pem"
