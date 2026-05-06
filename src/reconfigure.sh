#!/bin/sh

set -e

DEST_HOST="$1"
DEST_PORT=${2:-"22"}

if [ -z "$DEST_HOST" ]; then
    echo "Usage: $0 <destination-host> [port]"
    echo "  example: $0 example.com 22"
    exit 1
fi

# Validate port is numeric
if ! echo "$DEST_PORT" | grep -Eq '^[0-9]+$'; then
    echo "Error: Port '$DEST_PORT' is not a valid number"
    exit 1
fi

# Default to 22 if not set
DEST_PORT=${DEST_PORT:-22}

echo "1. Setting up known_hosts..."

if [ "$SSHITMAIDS_DO_KEYSCAN" = "true" ]; then
    ssh-keyscan "$DEST_HOST" > /root/sshitmaids/known_hosts.temp 2>/dev/null || true
    if [ ! -s /root/sshitmaids/known_hosts.temp ]; then
        rm -f /root/sshitmaids/known_hosts.temp
        echo "WARNING: Keyscan returned empty file. Probably rate-limited." >&2
    else
        mv /root/sshitmaids/known_hosts.temp /root/sshitmaids/known_hosts
        echo "  $DEST_HOST keyscanned for known_hosts"
    fi  
else
    echo "  Skipping keyscan."
    touch /root/sshitmaids/known_hosts
fi

echo "2. Setup git user & ephemeral .ssh dir..."

# NOTE: .ssh dirs inside /home/git and /root are ephemeral
# The "master" copies of SSH keys and config live in the bound volume dirs:
#   - /root/sshitmaids/ 
#   - /root/client/
# This is intentional so secrets/config are managed externally and persist across containers.

if [ ! -d /home/git ]; then
    echo "  Creating home directory for git user..."
    mkdir -p /home/git
else
    echo "  Git home directory exists."
fi

if id git 2>/dev/null; then
    echo "  Git user exists, skipping creation."
else
    useradd -m -G git -s /bin/bash git
    echo "  Git user created."
fi

# Ensure /home/git is owned by git (idempotent - safe to always run)
chown git:git /home/git
rm -rf /home/git/.ssh

# Create ephemeral .ssh/dest directory in git home
mkdir -p /home/git/.ssh/dest

echo "3. Loading root's SSH directory /root/.ssh "
echo "   from point-of-truth /root/sshitmaids ..."
rm -rf /root/.ssh/*
cp -r /root/sshitmaids/* /root/.ssh/

echo "4. Loading git user's SSH directory /home/git/.ssh"
echo "   from point-of-truth /root/sshitmaids ..."
mkdir -p /home/git/.ssh
rm -rf /home/git/.ssh/*
cp -r /root/sshitmaids/* /home/git/.ssh/

echo "5. Fixing SSH permissions..."

echo "   for root..."
chmod 700 /root/.ssh
chmod 600 /root/.ssh/* 2>/dev/null || touch /root/.ssh/placeholder
chown root:root -R /root/.ssh 2>/dev/null || true

echo "   and git..."
chown git:git /home/git/.ssh
chmod 700 /home/git/.ssh
chmod 600 /home/git/.ssh/*
chown git:git -R /home/git/.ssh 2>/dev/null || true

echo "6. Configuring sshd_config for git user..."
if ! grep -q "Match User git" /etc/ssh/sshd_config; then
    echo "  Adding Match User git block to /etc/ssh/sshd_config..."
    printf "\nMatch User git\n    ForceCommand /usr/local/bin/dest-mitm" >> /etc/ssh/sshd_config
    echo "   Match User git block added."
fi

echo "Done reconfigure.sh for $DEST_HOST:$DEST_PORT"