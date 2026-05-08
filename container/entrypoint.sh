#!/bin/sh
set -e

### Call reconfigure (idempotent rebuild)
# reconfigure.sh is always at /reconfigure.sh (guaranteed by Dockerfile)
if [ -x /reconfigure.sh ]; then
    echo "Calling reconfigure.sh $SSHITMAIDS_DEST_HOST:$SSHITMAIDS_DEST_PORT..."
    ./reconfigure.sh "$SSHITMAIDS_DEST_HOST" "$SSHITMAIDS_DEST_PORT"
else
    echo "ERROR: /reconfigure.sh not found. Image build failed."
    exit 1
fi

echo "Confirming sshd is running (in case reconfigure.sh didn't start it)..."
if [ -n "$(ps -C sshd --no-headers)" ]; then
    echo "sshd is running."
else
    echo "ERROR: sshd is not running, startup failed. Check reconfigure.sh logs for errors."
    exit 1
fi

echo "Container is ready. sshd is running and listening for client connections."
echo "Switching to log tailing mode."
exec tail -f /var/log/sshd.log