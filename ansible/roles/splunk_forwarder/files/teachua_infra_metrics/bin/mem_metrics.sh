#!/bin/bash
# Emits one JSON line with current memory usage, in bytes.
set -euo pipefail

read -r total used free shared buff_cache available < <(free -b | awk '/^Mem:/ {print $2, $3, $4, $5, $6, $7}')
mem_used_pct=$(awk -v u="$used" -v t="$total" 'BEGIN { printf "%.2f", (u/t)*100 }')

printf '{"mem_total_bytes": %s, "mem_used_bytes": %s, "mem_free_bytes": %s, "mem_available_bytes": %s, "mem_buff_cache_bytes": %s, "mem_used_pct": %s}\n' \
  "$total" "$used" "$free" "$available" "$buff_cache" "$mem_used_pct"
