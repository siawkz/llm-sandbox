#!/bin/bash

# Configuration validation script for sandbox

set -e

validate_whitelist() {
	local whitelist_file="$1"

	if [ ! -f "$whitelist_file" ]; then
		echo "❌ Whitelist file not found: $whitelist_file"
		return 1
	fi

	echo "✅ Validating whitelist file: $whitelist_file"

	local line_num=0
	local domain_count=0

	while IFS= read -r line || [ "$line" != "" ]; do
		line_num=$((line_num + 1))

		# Skip empty lines and comments
		if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
			continue
		fi

		# Trim whitespace
		domain=$(echo "$line" | xargs)

		# Basic domain validation
		if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
			echo "⚠️  Line $line_num: Invalid domain format: '$domain'"
		else
			domain_count=$((domain_count + 1))
		fi
	done <"$whitelist_file"

	echo "✅ Found $domain_count valid domains in whitelist"
	return 0
}

validate_restricted_paths() {
	local restricted_file="$1"

	if [ ! -f "$restricted_file" ]; then
		echo "ℹ️  Restricted paths file not found: $restricted_file (this is optional)"
		return 0
	fi

	echo "✅ Validating restricted paths file: $restricted_file"

	local line_num=0
	local path_count=0

	while IFS= read -r line || [ "$line" != "" ]; do
		line_num=$((line_num + 1))

		# Skip empty lines and comments
		if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
			continue
		fi

		# Trim whitespace
		path=$(echo "$line" | xargs)

		# Basic path validation (no absolute paths, no parent directory traversal)
		if [[ "$path" =~ ^/ ]]; then
			echo "⚠️  Line $line_num: Absolute paths not allowed: '$path'"
		elif [[ "$path" =~ \.\. ]]; then
			echo "⚠️  Line $line_num: Parent directory traversal not allowed: '$path'"
		elif [[ -z "$path" ]]; then
			echo "⚠️  Line $line_num: Empty path"
		else
			path_count=$((path_count + 1))
		fi
	done <"$restricted_file"

	echo "✅ Found $path_count valid restricted paths"
	return 0
}

# Main validation
echo "🔍 Validating sandbox configuration files..."
echo

# Validate whitelist
validate_whitelist "whitelist.txt"
echo

# Validate restricted paths if it exists
validate_restricted_paths "restricted-paths.txt"
echo

echo "✅ Configuration validation complete!"
