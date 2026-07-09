#!/bin/bash
# Emits one JSON line with current CPU utilization.
# vmstat's cpu columns (us sy id wa st) are always the last 5 fields of its
# output line, regardless of how many leading procs/memory/swap/io columns
# a given vmstat build reports — indexing from the end (NF-4..NF) is more
# robust than counting from the start.
set -euo pipefail

read -r us sy id wa st < <(vmstat 1 2 | tail -1 | awk '{print $(NF-4), $(NF-3), $(NF-2), $(NF-1), $NF}')

printf '{"cpu_used_pct": %s, "cpu_idle_pct": %s, "cpu_user_pct": %s, "cpu_system_pct": %s, "cpu_iowait_pct": %s, "cpu_steal_pct": %s}\n' \
  "$((100 - id))" "$id" "$us" "$sy" "$wa" "$st"
