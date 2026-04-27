#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: automated_local_backup.sh
#
# Description:
#   A local backup automation script that creates compressed, timestamped
#   archives (.tar.gz) from one or more source directories and stores them
#   in a backup destination directory.
#
# Features:
#   - Supports multiple source directories (bash array)
#   - Creates timestamped archives in format:
#       <dirname>_YYYY-MM-DD_HH-MM-SS.tar.gz
#   - Verifies each archive for integrity after creation
#   - Applies retention policy by deleting backups older than N days
#   - Calculates and displays total backup directory size
#   - Provides colored logging (info, success, warning, error)
#
# Behavior:
#   - Skips non-existent source directories with a warning (does not crash)
#   - Continues processing remaining sources even if one fails
#   - Exits with code 1 if any archive creation fails
#
# Configuration:
#   BACKUP_DIR      - Destination directory for backups (default: ~/backups)
#   SOURCE_DIR      - Array of directories to back up (default: ~/Documents)
#   RETENTION_DAYS  - Number of days to keep old backups (default: 3)
#
# Usage:
#   ./automated_local_backup.sh [-d backup_dir] [-s source_dir] [-r retention_days] [-h]
#
# -----------------------------------------------------------------------------

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'

success() { echo -e "    ${GREEN}[SUCCESS] $*${RESET}"; }
warn() { echo -e "    ${YELLOW}[WARNING] $*${RESET}" >&2; }
error() { echo -e "    ${RED}[ERROR] $*${RESET}" >&2; }
info() { echo -e "${BLUE}$*${RESET}"; }

BACKUP_DIR="$HOME/backups"
SOURCE_DIR=()
RETENTION_DAYS=3

USAGE="Usage: ./automated_local_backup.sh [-d backup_dir] [-s source_dir] [-r retention_days] [-h]

Options:
    -d <backup_dir>      Directory to store backups (default: $HOME/backups)
    -s <source_dir>      Directory to back up (can be specified multiple times, default: $HOME/Documents)
    -r <retention_days>  Number of days to keep old backups (default: 3)
    -h                   Show this help message and exit"

# --- Argument options ---
while getopts "d:s:r:h" opt; do
	case "$opt" in
		d) BACKUP_DIR="$OPTARG" ;;
		s) SOURCE_DIR+=("$OPTARG") ;;
		r) RETENTION_DAYS="$OPTARG" ;;
		h) info "$USAGE"
			exit 0 ;;
		*) info "$USAGE"
			exit 1 ;;
	esac
done

if [ "${#SOURCE_DIR[@]}" -eq 0 ]; then
	SOURCE_DIR=("$HOME/Documents")
fi

if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
	error "retention_days must be a number${RESET}"
	exit 1
fi

FAILED=0
CREATED_COUNT=0
DELETED_COUNT=0

create_archive()
{
	local source_dir="$1"
	local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
	local base_name=$(basename "$source_dir")
	local archive_name="${base_name}_${timestamp}.tar.gz"
	local archive_path="${BACKUP_DIR}/${archive_name}"

	if ! tar -czf "$archive_path" -C "$(dirname "$source_dir")" "$base_name"; then
		error "failed to create archive for '$source_dir'"
		return 1
	fi

	if [ ! -s "$archive_path" ]; then
		error "archive '$archive_path' is missing or empty"
		return 1
	fi

	echo "$archive_path"
	return 0
}

verify_archive()
{
	local archive_file="$1"

	if [ ! -f "$archive_file" ]; then
		error "archive '$archive_file' does not exist"
		return 1
	fi

	if tar -tzf "$archive_file" > /dev/null 2>&1; then
		return 0
	else
		error "archive '$archive_file' is corrupted"
		return 1
	fi
}

cleanup_old_backups()
{
	if [ ! -d "$BACKUP_DIR" ]; then
		return 0
	fi

	while read file; do
		if rm -f "$file"; then
			DELETED_COUNT=$((DELETED_COUNT + 1))
		else
			warn "failed to delete old backup '$file'"
		fi
	done < <(find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +"$RETENTION_DAYS")
}

calculate_total_size()
{
	if [ ! -d "$BACKUP_DIR" ]; then
		info "Total backup size: 0 bytes"
		return 0
	fi

	local total_size=$(du -sh "$BACKUP_DIR" 2> /dev/null | awk '{print $1}')
	info "Total backup size: $total_size"
	return 0
}

main()
{
	if [ ! -d "$BACKUP_DIR" ]; then
		mkdir -p "$BACKUP_DIR"
	fi

	for dir in "${SOURCE_DIR[@]}"; do
		if [ ! -d "$dir" ]; then
			warn "$dir does not exist, skipping"
			continue
		fi

		if archive=$(create_archive "$dir"); then
			CREATED_COUNT=$((CREATED_COUNT + 1))
			if ! verify_archive "$archive"; then
				FAILED=1
			fi
		else
			FAILED=1
		fi
	done

	cleanup_old_backups
	calculate_total_size

	echo "Backup summary:"
	echo "    Created: $CREATED_COUNT"
	echo "    Deleted: $DELETED_COUNT"

	if [ $FAILED -eq 0 ]; then
		success "All backups created successfully"
	else
		error "Some backups failed"
	fi
}

main
