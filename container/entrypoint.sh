#!/bin/sh
set -e

### Call reconfigure (idempotent rebuild)
# reconfigure.sh is always at /reconfigure.sh (guaranteed by Dockerfile)
if [ -x /reconfigure.sh ]; then
    echo "Calling reconfigure.sh $SSHITMAIDS_DEST_HOST:$SSHITMAIDS_DEST_PORT..."
    exec /reconfigure.sh "$SSHITMAIDS_DEST_HOST" "$SSHITMAIDS_DEST_PORT"
else
    echo "ERROR: /reconfigure.sh not found. Image build failed."
    exit 1
fi

### Start SSHD (should be handled by reconfigure.sh, but fallback here if needed)
echo "Starting SSHD..."
exec /usr/sbin/sshd -e 2>&1 &
exec tail -f /dev/null
