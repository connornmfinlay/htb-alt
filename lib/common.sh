#!/usr/bin/env bash
# Shared helpers and config for the lab CLI. Sourced by ./lab.
set -euo pipefail

# ---- configuration -------------------------------------------------------
LAB_NET="${LAB_NET:-labnet}"
LAB_SUBNET="${LAB_SUBNET:-10.13.37.0/24}"
LAB_GW="${LAB_GW:-10.13.37.1}"
ATTACKER_IP="${ATTACKER_IP:-10.13.37.10}"
ATTACKER_NAME="attacker"
ATTACKER_IMAGE="lab/attacker:latest"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$ROOT_DIR/catalog/targets.tsv"
WORK_DIR="$ROOT_DIR/attacker/work"   # persistent attacker home, bind-mounted

# Where published web ports listen. Default: the Tailscale IP if this host has
# one, so vulnerable targets are reachable from your tailnet (e.g. your XPS) but
# NOT from the home LAN or internet. Override with PUBLISH_ADDR=0.0.0.0 to also
# expose on the LAN, or PUBLISH_ADDR=127.0.0.1 for host-only.
detect_publish_addr() {
  local ts
  ts=$(ip -4 -o addr show tailscale0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
  echo "${ts:-0.0.0.0}"
}
PUBLISH_ADDR="${PUBLISH_ADDR:-$(detect_publish_addr)}"
export PUBLISH_ADDR

# ---- pretty output -------------------------------------------------------
c_reset=$'\033[0m'; c_bold=$'\033[1m'; c_blue=$'\033[34m'
c_green=$'\033[32m'; c_yellow=$'\033[33m'; c_red=$'\033[31m'
info() { printf '%s[*]%s %s\n' "$c_blue" "$c_reset" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$c_green" "$c_reset" "$*"; }
warn() { printf '%s[!]%s %s\n' "$c_yellow" "$c_reset" "$*"; }
err()  { printf '%s[x]%s %s\n' "$c_red" "$c_reset" "$*" >&2; }
die()  { err "$*"; exit 1; }

need_podman() { command -v podman >/dev/null || die "podman not found on PATH"; }

net_exists()    { podman network exists "$LAB_NET"; }
target_running(){ podman container exists "$1" && [ "$(podman inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = true ]; }

# Read a catalog row by id -> sets REPLY_* globals. Returns 1 if not found.
catalog_lookup() {
  local want="$1" id cat type ref ports desc
  while IFS=$'\t' read -r id cat type ref ports desc; do
    [[ "$id" =~ ^#|^$ ]] && continue
    if [ "$id" = "$want" ]; then
      REPLY_ID="$id"; REPLY_CAT="$cat"; REPLY_TYPE="$type"
      REPLY_REF="$ref"; REPLY_PORTS="$ports"; REPLY_DESC="$desc"
      return 0
    fi
  done < "$CATALOG"
  return 1
}
