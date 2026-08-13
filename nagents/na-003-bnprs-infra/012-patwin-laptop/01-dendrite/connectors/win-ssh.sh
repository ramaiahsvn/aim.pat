#!/usr/bin/env bash
# =============================================================================
#  win-ssh.sh — resolve a Windows host from windows-hosts.yaml and connect
#  na-003/012 patwin-laptop
#
#  The address lives ONLY in windows-hosts.yaml. Nothing here hardcodes an IP,
#  so a machine moving to a new IP is a one-line edit in that file.
#
#  Usage:
#     ./win-ssh.sh --list                 show the inventory and what is missing
#     ./win-ssh.sh --probe [host-id]      is it up? is 22 open? (no login)
#     ./win-ssh.sh [host-id]              interactive shell
#     ./win-ssh.sh [host-id] <command>    run one command
#
#  With no host-id, `default_host` from the YAML is used.
#  Uses ruby's bundled YAML — no yq/PyYAML needed (macOS has neither by default).
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
INVENTORY="$HERE/windows-hosts.yaml"

[ -f "$INVENTORY" ] || { echo "error: inventory not found: $INVENTORY" >&2; exit 1; }
command -v ruby >/dev/null || { echo "error: ruby needed to read the inventory" >&2; exit 1; }

# field <host-id> <key>  -> value on stdout ("" when absent/null)
field() {
  ruby -ryaml -e '
    inv = YAML.load_file(ARGV[0])
    id  = ARGV[1]
    id  = inv["default_host"].to_s if id.nil? || id.empty?
    h   = (inv["hosts"] || []).find { |x| x["id"].to_s == id }
    abort "error: host id \"#{id}\" not in inventory" if h.nil?
    k = ARGV[2]
    if k == "_resolved"
      # resolution_order decides which of address/hostname to use
      order = inv["resolution_order"] || ["address", "hostname"]
      v = order.map { |f| h[f].to_s.strip }.find { |s| !s.empty? }
      print v.to_s
    elsif k == "_id"
      print id
    else
      print h[k].nil? ? "" : h[k].to_s.strip
    end
  ' "$INVENTORY" "${1:-}" "$2"
}

cmd_list() {
  ruby -ryaml -e '
    inv = YAML.load_file(ARGV[0])
    printf("inventory : %s\n", ARGV[0])
    printf("default   : %s\n\n", inv["default_host"])
    (inv["hosts"] || []).each do |h|
      order = inv["resolution_order"] || ["address", "hostname"]
      target = order.map { |f| h[f].to_s.strip }.find { |s| !s.empty? } || "(none)"
      printf("  %-10s %-22s port %-5s user %-12s confirmed=%s admin=%s\n",
             h["id"], target, h["port"] || 22,
             (h["user"].to_s.strip.empty? ? "(UNSET)" : h["user"]),
             h["confirmed"].inspect, h["admin_account"].inspect)
      printf("             %s\n", h["label"].to_s)
      o = h["observed"] || {}
      printf("             ssh_ready=%s jvm_present=%s last_probe=%s\n",
             o["ssh_ready"].inspect, o["jvm_present"].inspect, o["last_probe"])
      blockers = []
      blockers << "user unset"        if h["user"].to_s.strip.empty?
      blockers << "host unconfirmed"  if h["confirmed"] != true
      blockers << "sshd not ready"    if o["ssh_ready"] != true
      printf("             BLOCKERS: %s\n", blockers.empty? ? "none" : blockers.join(", "))
      puts
    end
  ' "$INVENTORY"
}

cmd_probe() {
  local id="${1:-}"
  local target port
  target="$(field "$id" _resolved)"
  port="$(field "$id" port)"; port="${port:-22}"
  echo "host   : $(field "$id" _id)"
  echo "target : $target"

  # ICMP is INFORMATIONAL ONLY. Windows Firewall blocks inbound echo by default,
  # so "no reply" does not mean down — and a single packet can also miss while a
  # WiFi NIC wakes from power saving. TCP is the authoritative liveness signal.
  if ping -c 2 -W 2000 "$target" >/dev/null 2>&1; then
    echo "icmp   : replies (informational)"
  else
    echo "icmp   : no reply — normal for Windows, not a verdict"
  fi

  if nc -z -G 3 -w 3 "$target" "$port" >/dev/null 2>&1; then
    echo "port $port: OPEN"
    echo "banner : $(nc -w 3 "$target" "$port" </dev/null 2>/dev/null | head -1)"
    echo "verdict: reachable — ready for win-ssh.sh $(field "$id" _id)"
    return 0
  fi

  echo "port $port: closed"
  # Prove the host is alive some other way before blaming the network
  local alive=""
  for p in 445 3389 135 139; do
    if nc -z -G 2 -w 2 "$target" "$p" >/dev/null 2>&1; then alive="$p"; break; fi
  done
  if [ -n "$alive" ]; then
    echo "verdict: HOST IS ALIVE (tcp/$alive open) but sshd is not listening."
    echo "         Run enable-ssh.ps1 on it as Administrator."
  else
    echo "verdict: no TCP response at all — wrong address, host off, or another subnet."
    echo "         Check 'address' in windows-hosts.yaml (or blank it to use hostname)."
  fi
  return 1
}

cmd_connect() {
  local id="${1:-}"; shift || true
  local target port user ident
  target="$(field "$id" _resolved)"
  port="$(field "$id" port)";  port="${port:-22}"
  user="$(field "$id" user)"
  ident="$(field "$id" identity)"
  ident="${ident/#\~/$HOME}"

  if [ -z "$user" ]; then
    echo "error: 'user' is unset for host '$(field "$id" _id)' in windows-hosts.yaml." >&2
    echo "       Fill it in — the agent must not guess a username." >&2
    exit 2
  fi
  if [ "$(field "$id" confirmed)" != "true" ]; then
    echo "warning: host '$(field "$id" _id)' is not confirmed (confirmed: false)." >&2
    echo "         Verify it is the intended machine, then set confirmed: true." >&2
  fi
  [ -f "$ident" ] || { echo "error: identity not found: $ident" >&2; exit 1; }

  set -- ssh -i "$ident" -p "$port" \
            -o IdentitiesOnly=yes \
            -o StrictHostKeyChecking=accept-new \
            -o ConnectTimeout=8 \
            "$user@$target" ${1+"$@"}
  echo "+ ${*}" >&2
  exec "$@"
}

case "${1:-}" in
  --list|-l)  cmd_list ;;
  --probe|-p) shift; cmd_probe "${1:-}" ;;
  --help|-h)  sed -n '2,20p' "$0" ;;
  *)          cmd_connect "$@" ;;
esac
