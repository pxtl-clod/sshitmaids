#!/bin/sh
set -e

### Call reconfigure (idempotent rebuild)
# reconfigure.sh is always at /reconfigure.sh (guaranteed by Dockerfile)
if [ -x /reconfigure.sh ]; then
    echo "Calling reconfigure.sh..."
    exec /reconfigure.sh "$@"
else
    echo "ERROR: /reconfigure.sh not found. Image build failed."
    exit 1
fi

### Start SSHD (reached if reconfigure fails, shouldn't happen)
echo "Starting SSHD..."
exec /usr/sbin/sshd -D -e
