#!/bin/bash
# Init script to set up folder/file restrictions and container-only package installation

# Read restricted paths from file if available, otherwise use environment variable
if [ -f "/home/agent/app/restricted-paths.txt" ]; then
	echo "Reading restricted paths from restricted-paths.txt..."
	mapfile -t PATHS < <(grep -v '^#' /home/agent/app/restricted-paths.txt | grep -v '^$')
	RESTRICTED_PATHS_STR=$(
		IFS=','
		echo "${PATHS[*]}"
	)
	echo "Restricted paths from file: $RESTRICTED_PATHS_STR"
else
	RESTRICTED_PATHS="${RESTRICTED_PATHS:-}"
	if [ "$RESTRICTED_PATHS" != "" ]; then
		echo "Reading restricted paths from environment variable..."
		echo "Restricted paths: $RESTRICTED_PATHS"
		# Convert comma-separated list to array
		IFS=',' read -ra PATHS <<<"$RESTRICTED_PATHS"
	else
		echo "No restrictions configured (no restricted-paths.txt file and no RESTRICTED_PATHS env var)"
		PATHS=()
	fi
fi

if [ ${#PATHS[@]} -gt 0 ]; then
	echo "Setting up access restrictions using bind mounts..."

	# Create empty directories/files to bind mount over restricted paths
	for path in "${PATHS[@]}"; do
		path=$(echo "$path" | xargs) # Trim whitespace
		full_path="/home/agent/app/$path"

		if [ -e "$full_path" ]; then
			if [ -d "$full_path" ]; then
				echo "Restricting directory: $path"
				# Create empty directory and bind mount over it
				mkdir -p "/tmp/empty-dir"
				chmod 000 "/tmp/empty-dir"
				mount --bind "/tmp/empty-dir" "$full_path"
			else
				echo "Restricting file: $path"
				# Create empty file and bind mount over it
				touch "/tmp/empty-file"
				chmod 000 "/tmp/empty-file"
				mount --bind "/tmp/empty-file" "$full_path"
			fi
		else
			echo "Path $path does not exist, skipping..."
		fi
	done
else
	echo "No paths to restrict, proceeding without restrictions..."
fi

echo "Access restrictions applied. Switching to agent user and executing command: $@"

# Switch to agent user and execute command
exec su agent -c "cd /home/agent/app && $*"
