#!/data/data/com.termux/files/usr/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/source.env"
IMAGE_NAME="huytungst/python-matter-server:6.6.0"
CONTAINER_NAME="matter-server"

# Set the data storage path for the Matter Server
DATA_PATH="$(pwd)/data"
mkdir -p "$DATA_PATH"

# Check if PORT is a valid number; default to 5580 if not provided
case $PORT in
  ''|*[!0-9]*) PORT=5580;;
  *) [ $PORT -gt 1023 ] && [ $PORT -lt 65536 ] || PORT="5580";;
esac

# Ensure udocker environment is set up
udocker_check

# Clean up unused containers and images
udocker_prune

# Create the Matter Server container
udocker_create "$CONTAINER_NAME" "$IMAGE_NAME"

# If arguments are passed, run them directly in the container
if [ -n "$1" ]; then
 udocker_run --entrypoint "bash -c" -p "$PORT:5580" "$CONTAINER_NAME" "$@"
else
  # Default run command for Matter Server, without security options or host net
 udocker_run -p "$PORT:5580" \
   -v "$DATA_PATH:/data" \
  "$CONTAINER_NAME" \
   --storage-path /data --port "$PORT" --listen-address "0.0.0.0"
fi
exit $?