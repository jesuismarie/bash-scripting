#!/usr/bin/env bash

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'

ok() { echo -e "    ${GREEN}[OK]${RESET}   $*"; }
warn() { echo -e "    ${YELLOW}[WARN]${RESET} $*"; }
crit() { echo -e "    ${RED}[CRIT]${RESET} $*"; }
section() { echo -e "\n${BLUE}════ $* ${RESET}"; }

# --- Uptime ---
show_uptime()
{
	section "Uptime"
	up_time=$(uptime -p)
	echo "    $up_time"
}

# --- CPU Usage ---
check_cpu()
{
	section "CPU"

	cpu_idle=$(top -bn1 | awk '/Cpu/ {print $8}')
	cpu_usage=$(echo "scale=1; 100 - $cpu_idle" | bc)

	if (( $(echo "$cpu_usage >= 90" | bc -l) )); then
		crit "$cpu_usage% used, $cpu_idle% idle"
	elif (( $(echo "$cpu_usage >= 75" | bc -l) )); then
		warn "$cpu_usage% used, $cpu_idle% idle"
	else
		ok "$cpu_usage% used, $cpu_idle% idle"
	fi
}

top_services()
{
	section "Top 5 Processes"

	ps -eo comm,%cpu --no-headers |
	awk -v cores="$(nproc)" '{ cpu[$1] += $2; count[$1]++ }
	END { for (n in cpu) printf "%s %.1f %d\n", n, cpu[n]/cores, count[n] }' |
	sort -k2 -nr | head -n 5 | \
	while read name cpu num;
	do
		cpu_int=$(printf "%.0f" "$cpu")

		if [ "$cpu_int" -ge 90 ]; then
			crit "${RED}(${cpu}%)${RESET} $name ($num processes)"
		elif [ "$cpu_int" -ge 75 ]; then
			warn "${YELLOW}(${cpu}%)${RESET} $name ($num processes)"
		else
			ok "${GREEN}(${cpu}%)${RESET} $name ($num processes)"
		fi
	done || true
}

# --- Load Average ---
check_load()
{
	section "Load Average"
	load1=$(awk '{print $1}' /proc/loadavg)
	load5=$(awk '{print $2}' /proc/loadavg)
	load15=$(awk '{print $3}' /proc/loadavg)

	cpu_cores=$(nproc)
	echo "    CPU Cores $(nproc) - 1m: $load1  5m: $load5  15m: $load15"
	if (( $(echo "$load1 > $cpu_cores * 2" | bc -l) )); then
		crit "System is heavily overloaded!"
	elif (( $(echo "$load1 > $cpu_cores" | bc -l) )); then
		warn "System load is higher than available CPU cores."
	else
		ok "System load is within normal limits."
	fi
}

# --- Memory Usage ---
check_memory()
{
	section "Memory"

	memory_total=$(free -h | awk '/Mem:/ {print $2}')
	memory_used=$(free -h | awk '/Mem:/ {print $3}')
	memory_usage_percent=$(free | awk '/Mem:/ {printf "%.1f", $3/$2*100}')

	if (( $(echo "$memory_usage_percent >= 90" | bc -l) )); then
		crit "$memory_used used out of $memory_total (${memory_usage_percent}%)"
	elif (( $(echo "$memory_usage_percent >= 75" | bc -l) )); then
		warn "$memory_used used out of $memory_total (${memory_usage_percent}%)"
	else
		ok "$memory_used used out of $memory_total (${memory_usage_percent}%)"
	fi
}

# --- Disk Usage ---
check_disk()
{
	section "Disk"
	df -h --output=source,target,size,used,pcent | awk 'NR>1' | \
	while read fs mount size used usep;
	do
		if [[ "$fs" == /dev/* && "$fs" != /dev/loop* ]]; then
			usage=${usep%\%}

			if [ "$usage" -ge 90 ]; then
				crit "${RED}($usep)${RESET} $fs mounted on $mount: $used used out of $size"
			elif [ "$usage" -ge 80 ]; then
				warn "${YELLOW}($usep)${RESET} $fs mounted on $mount: $used used out of $size"
			else
				ok "${GREEN}($usep)${RESET} $fs mounted on $mount: $used used out of $size"
			fi
		fi
	done || true
}

main()
{
	echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════╗${RESET}"
	echo -e "${BLUE}║                 System Health Check - $(date '+%Y-%m-%d %H:%M:%S')                 ║${RESET}"
	echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════════╝${RESET}"

	show_uptime
	check_cpu
	top_services
	check_load
	check_memory
	check_disk

	echo
	echo -e "${BLUE}══════════════════════════ System Health Check End ══════════════════════════${RESET}"
}

main
