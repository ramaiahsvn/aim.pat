#!/usr/bin/env python3
"""Mock Kiosk agent — validates the perso-bureau NDJSON protocol WITHOUT a real card.

Reference for the Kiosk team: shows the exact message flow. It relays APDUs with *canned* responses
instead of a real card. Replace rapdu_for() with a real local card channel (TP9000 v2 / PC/SC) that
transmits capdu to the card and resolves 61xx/6Cxx locally.

Usage:  python3 mock_kiosk.py [host] [port] [token]
        (start the bureau first:  perso-bureau <port> <token>)
"""
import socket, json, sys

HOST  = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
PORT  = int(sys.argv[2]) if len(sys.argv) > 2 else 9099
TOKEN = sys.argv[3] if len(sys.argv) > 3 else "uat-token"

def rapdu_for(capdu: str) -> str:
    """Canned card responses. A real agent transmits to the card and returns data||SW1SW2 (61/6C resolved)."""
    c = capdu.upper()
    if "A000000004000000" in c:  # SELECT MC card manager -> FCI + 9000
        return "6F108408A000000004000000A5029000"
    if "A000000003000000" in c:  # SELECT Visa card manager -> not present on this mock card
        return "6A82"
    return "9000"

def send(sock, obj): sock.sendall((json.dumps(obj) + "\n").encode())

def messages(sock):
    buf = b""
    while True:
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            if line.strip():
                yield json.loads(line)
        chunk = sock.recv(4096)
        if not chunk:
            return
        buf += chunk

def main():
    s = socket.create_connection((HOST, PORT))
    send(s, {"type": "hello", "token": TOKEN, "kioskId": "KIOSK-UAT-01",
             "agentVersion": "0.1", "capabilities": ["tp9000", "pcsc"]})
    msgs = messages(s)
    print("<- hello_ack:", next(msgs))
    send(s, {"type": "perso_request", "channel": "iperso", "transport": "tp9000",
             "inputType": "dpi", "inputB64": "UkVRVUVTVA=="})  # placeholder input
    for m in msgs:
        t = m.get("type")
        if t == "card_open":
            print("   open local card (mock) ...")
            send(s, {"type": "card_opened", "atr": "3BFE1300008131FE454A434F5076323431B7"})
        elif t == "apdu":
            rp = rapdu_for(m["capdu"])
            print(f"   relay seq={m['seq']}  {m['capdu'][:24]}...  -> {rp}")
            send(s, {"type": "apdu_response", "seq": m["seq"], "rapdu": rp})
        elif t == "card_finish":
            print("   dispose ->", m.get("disposition"))
            send(s, {"type": "card_finished", "ok": True})
        elif t == "result":
            print("<- RESULT:", m)
            break
        elif t == "error":
            print("<- ERROR:", m)
            break
    s.close()

if __name__ == "__main__":
    main()
