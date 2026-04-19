#!/usr/bin/env bash

set -euo pipefail

BACKUP_DIR="$HOME/backups"
SOURCE_DIR=("$HOME/Desktop")

FAILED=0
CREATED_COUNT=0

create_archive()
{
	local source_dir="$1"
	local timestamp=$(date +"%Y-%m-%d_%H:%M:%S")
	local base_name=$(basename "$source_dir")
	local archive_name="${base_name}_${timestamp}.tar.gz"
	local archive_path="${BACKUP_DIR}/${archive_name}"

	if ! tar -czf "$archive_path" -C "$(dirname "$source_dir")" "$base_name"; then
		echo "Error: failed to create archive for '$source_dir'" >&2
		return 1
	fi

	if [ ! -s "$archive_path" ]; then
		echo "Error: archive '$archive_path' is missing or empty" >&2
		return 1
	fi

	echo "$archive_path"
	return 0
}

verify_archive()
{
	local archive_file="$1"

	if [ ! -f "$archive_file" ]; then
		echo "Error: archive '$archive_file' does not exist" >&2
		return 1
	fi

	if tar -tzf "$archive_file" > /dev/null 2>&1; then
		return 0
	else
		echo "Error: archive '$archive_file' is corrupted" >&2
		return 1
	fi

}

main()
{
	if [ ! -d "$BACKUP_DIR" ]; then
		mkdir -p "$BACKUP_DIR"
	fi

	for dir in "${SOURCE_DIR[@]}"; do
		if [ ! -d "$dir" ]; then
			echo "Warning: $dir does not exist, skipping"
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
}

main "$@"
