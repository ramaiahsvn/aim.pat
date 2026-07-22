# Perso result — output schema (for the kiosk main application)

Every trigger returns ONE JSON line. Your app checks `status`; on a **successful live perso**
the bureau also returns `output` with the physical-card-production data.

## Success (live perso, status = ok)
```json
{
  "status": "ok",
  "detail": "VISA PERSO COMPLETE",
  "atr": "3B...",
  "output": {
    "print": {
      "cardholderName": "ALI A A",
      "pan":            "4111111111111111",
      "panMasked":      "411111******1111",
      "expiry":         "12/29"
    },
    "magstripe": {
      "track1": "%B4111111111111111^ALI A A^2912201?",
      "track2": ";4111111111111111=2912201?"
    }
  },
  "bureau": { "dgisAccepted": 20, "dgisTotal": 20, "secured": true, ... }
}
```

## Failure (status = fail)
No `output` is returned (nothing was written to the card). `detail` says why. The agent has
already rejected the card.

## How your app uses it
1. Read the one result line, parse JSON.
2. If `status == "ok"`: chip perso is done and the card is ejected good. Use `output.print`
   for the card printer and `output.magstripe.track1/track2` for the magstripe encoder.
3. If `status == "fail"`: card rejected; show `detail`, retry.

## IMPORTANT (PCI)
`output` contains cardholder data (PAN, tracks) — it is Sensitive Account Data. It is sent
ONLY on success, only over the TLS channel. Use it transiently for the printer/encoder and
**do not persist or log it**. The bureau never logs the values.

## Notes
- `output` is present ONLY on a successful live perso (transport=tp9000, commit=true). Preflight
  / mock runs never return it.
- Track layout is ISO 7813 (Track1 Format B, Track2 with `=`). Reconcile the exact name and
  discretionary-data format with your encoder + the issuer's DPI fields.
