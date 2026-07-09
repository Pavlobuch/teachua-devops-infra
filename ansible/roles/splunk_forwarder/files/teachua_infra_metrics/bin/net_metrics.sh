#!/bin/bash
# Emits one JSON line per network interface (excluding loopback), computing
# a 1-second byte-rate delta from /proc/net/dev's cumulative counters —
# those counters are lifetime totals since boot, not useful charted directly.
set -euo pipefail

declare -A rx1 tx1 rx2 tx2

read_counters() {
  local -n rx_ref=$1
  local -n tx_ref=$2
  while IFS=: read -r iface stats; do
    iface="${iface// /}"
    [ -z "$iface" ] && continue
    [ "$iface" = "lo" ] && continue
    read -r rx _ _ _ _ _ _ _ tx _ <<< "$stats"
    rx_ref["$iface"]=$rx
    tx_ref["$iface"]=$tx
  done < <(tail -n +3 /proc/net/dev)
}

read_counters rx1 tx1
sleep 1
read_counters rx2 tx2

for iface in "${!rx1[@]}"; do
  rx_rate=$(( rx2[$iface] - rx1[$iface] ))
  tx_rate=$(( tx2[$iface] - tx1[$iface] ))
  printf '{"interface": "%s", "rx_bytes_per_sec": %s, "tx_bytes_per_sec": %s}\n' "$iface" "$rx_rate" "$tx_rate"
done
