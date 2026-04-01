#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[032m'
RED='\033[031m'
YELLOW='\033[033m'
RESET='\033[0m'

echo Date: $(date)

# --- CPU Usage ---
cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}')
cpu_usage=$(echo "100 - $cpu_idle" | bc)
echo CPU: $cpu_idle idle, $cpu_usage used

# --- Memory Usage ---
memory_total=$(free -h | awk '/Mem:/ {print $2}')
memory_usage=$(free -h | awk '/Mem:/ {print $3}')
echo Memory: $memory_usage used out of $memory_total

# --- Disk Usage ---
echo Disk:
df -h --output=source,target,size,used,pcent | awk 'NR>1' | while read fs mount size used usep
do
	if [[ "$fs" == /dev/* && "$fs" != /dev/loop* ]]; then
		echo "  $fs mounted on $mount: $used used out of $size ($usep)"
	fi
done
