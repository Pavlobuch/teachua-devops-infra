#!/bin/bash
# Emits one JSON line per real filesystem (skips tmpfs/devtmpfs/squashfs/overlay
# snap/container noise), sizes in bytes.
set -euo pipefail

df -B1 --output=source,target,size,used,avail,pcent -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | tail -n +2 | \
while read -r source target size used avail pcent; do
  pcent_num="${pcent%\%}"
  printf '{"filesystem": "%s", "mount": "%s", "size_bytes": %s, "used_bytes": %s, "avail_bytes": %s, "used_pct": %s}\n' \
    "$source" "$target" "$size" "$used" "$avail" "$pcent_num"
done
