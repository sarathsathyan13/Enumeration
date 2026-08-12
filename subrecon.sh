#!/usr/bin/env bash
#
# subrecon.sh — Advanced subdomain enumeration & liveness check
#
# Wraps assetfinder + httprobe with proper error handling, dependency
# checks, isolated working directories (safe to run against multiple
# domains without clobbering results), and clean logging.
#
# Intended for use only against domains/assets you own or are explicitly
# authorized to test.
#
# Usage:
#   ./subrecon.sh example.com
#   ./subrecon.sh -o ./results example.com
#   ./subrecon.sh -c 50 example.com     # httprobe concurrency
#
set -Eeuo pipefail
 
# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
OUT_DIR="./recon_output"
CONCURRENCY=20
DOMAIN=""
 
usage() {
  cat <<EOF
Usage: $(basename "$0") [-o output_dir] [-c concurrency] <domain>
 
  -o DIR   Output directory (default: ${OUT_DIR})
  -c N     httprobe concurrency (default: ${CONCURRENCY})
  -h       Show this help
 
Example:
  $(basename "$0") -o ./results example.com
EOF
}
 
# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
while getopts ":o:c:h" opt; do
  case "$opt" in
    o) OUT_DIR="$OPTARG" ;;
    c) CONCURRENCY="$OPTARG" ;;
    h) usage; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
 
if [[ $# -lt 1 ]]; then
  echo "Invalid Syntax. Please provide a domain name."
  usage
  exit 1
fi
DOMAIN="$1"
 
# Basic sanity check on the domain format
if ! [[ "$DOMAIN" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}$ ]]; then
  echo "Error: '${DOMAIN}' does not look like a valid domain name." >&2
  exit 1
fi
 
# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log()  { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
step() { echo; log "== $* =="; }
die()  { echo "Error: $*" >&2; exit 1; }
 
# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
for bin in assetfinder httprobe sort; do
  command -v "$bin" >/dev/null 2>&1 || die "'${bin}' not found in PATH. Please install it first."
done
 
# ---------------------------------------------------------------------------
# Working directory setup — namespaced per domain + timestamp, so repeat
# runs never overwrite prior results and nothing is left in the repo root.
# ---------------------------------------------------------------------------
RUN_DIR="${OUT_DIR}/${DOMAIN}/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RUN_DIR"
 
RAW_DOMAINS="${RUN_DIR}/domains.txt"
ALIVE_RAW="${RUN_DIR}/alive_raw.txt"
FINAL_LIST="${RUN_DIR}/sorted_alive_subs.txt"
 
cleanup() {
  # Remove intermediate files on any exit, keep only the final list + log
  rm -f "$RAW_DOMAINS" "$ALIVE_RAW" 2>/dev/null || true
}
trap cleanup EXIT
 
# ---------------------------------------------------------------------------
# Step 1: Enumerate subdomains
# ---------------------------------------------------------------------------
step "Running assetfinder against ${DOMAIN}"
if ! assetfinder --subs-only "$DOMAIN" > "$RAW_DOMAINS"; then
  die "assetfinder failed to run."
fi
 
if [[ ! -s "$RAW_DOMAINS" ]]; then
  die "assetfinder returned no results for ${DOMAIN}."
fi
 
sort -u "$RAW_DOMAINS" -o "$RAW_DOMAINS"
found_count=$(wc -l < "$RAW_DOMAINS")
log "Found ${found_count} unique candidate subdomains."
 
# ---------------------------------------------------------------------------
# Step 2: Probe for alive hosts
# ---------------------------------------------------------------------------
step "Checking for alive domains (concurrency: ${CONCURRENCY})"
if ! httprobe -c "$CONCURRENCY" < "$RAW_DOMAINS" > "$ALIVE_RAW"; then
  die "httprobe failed to run."
fi
 
if [[ ! -s "$ALIVE_RAW" ]]; then
  log "No alive hosts found among the ${found_count} candidates."
  : > "$FINAL_LIST"
else
  # ---------------------------------------------------------------------
  # Step 3: Strip scheme, dedupe, sort
  # ---------------------------------------------------------------------
  step "Normalizing and sorting results"
  sed -E 's#^[a-zA-Z]+://##' "$ALIVE_RAW" | sort -u -o "$FINAL_LIST"
fi
 
alive_count=$(wc -l < "$FINAL_LIST")
 
# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
step "Script Execution Completed"
log "Total ${alive_count} alive subdomains found (out of ${found_count} discovered)."
log "Results saved to: ${FINAL_LIST}"
 
