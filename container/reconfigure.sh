#!/bin/sh

set -e

DEST_HOST="$1"
DEST_PORT=${2:-"22"}
MITM_DIR="/root/sshitmaids"
CLIENT_DIR="/root/client"
PASSTHROUGH_USER="git"
USER_DIR="/home/$PASSTHROUGH_USER"


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

echo "Reconfigure container for $DEST_HOST:$DEST_PORT"
echo "=========================================="

echo "1. Ensure volume directories exist..."
mkdir -p "$MITM_DIR" "$CLIENT_DIR"

echo "2. Building mitm authorized_keys from all client and mitm public keys..."
: > "$MITM_DIR/authorized_keys" >&/dev/null

# Append each .pub file from volumes
for pub in "$MITM_DIR"/*.pub; do
    [ -e "$pub" ] || continue
    cat "$pub" >> "$MITM_DIR/authorized_keys"
done

for pub in "$CLIENT_DIR"/*.pub; do
    [ -e "$pub" ] || continue
    cat "$pub" >> "$MITM_DIR/authorized_keys"
done

echo "   mitm's .ssh/authorized_keys built"

# Write SSH config for MITM
echo "3. Writing SSH config for MITM ($PASSTHROUGH_USER user)..."
cat > "$MITM_DIR/config" <<EOF
Host dest
    HostName $DEST_HOST
    Port $DEST_PORT
    User $PASSTHROUGH_USER
    IdentityFile /$MITM_DIR/.ssh/id_ed25519
    UserKnownHostsFile /$MITM_DIR/.ssh/known_hosts
    StrictHostKeyChecking yes
EOF

# Write client's SSH config if enabled
echo "4. Handling client config..."
if [ "$SSHITMAIDS_GENERATE_CLIENT_CONFIG" = "true" ]; then
    cat > "$CLIENT_DIR/config" <<EOF
Host $DEST_HOST
    HostName sshitmaids
    Port $DEST_PORT
    User root
    IdentityFile ~/.ssh/id_ed25519
EOF
    echo "   client ssh config generated"
else
    echo "   Skipping client config (SSHITMAIDS_GENERATE_CLIENT_CONFIG not 'true')"
fi

echo "5. Writing known_hosts..."
if [ "$SSHITMAIDS_DO_KEYSCAN" = "true" ]; then
    ssh-keyscan $DEST_HOST > /tmp/known_hosts_tmp 2>/dev/null || true
    if [ ! -s /tmp/known_hosts_tmp ]; then
        rm -f /tmp/known_hosts_tmp
        echo "   WARNING: Keyscan returned empty file. Probably rate-limited." >&2
    else
        mv /tmp/known_hosts_tmp "$MITM_DIR/known_hosts"
        echo "   $DEST_HOST keyscanned and saved to known_hosts"
    fi
else
    touch "$MITM_DIR/known_hosts"
    echo "   Skipping keyscan to prevent rate limiting"
fi

echo "6. Ensuring root user ephemeral .ssh dir..."
# NOTE: .ssh dirs inside /home/$PASSTHROUGH_USER and /root are ephemeral The
# "master" copies of SSH keys and config live in the bound volume dirs:
#   - /root/sshitmaids/ 
#   - /root/client/
#
# This is intentional so secrets/config are managed externally and persist
# across containers.

# Setup root .ssh (if not exists)
if [ ! -d /root/.ssh ]; then
    mkdir -p /root/.ssh
fi

# Copy MITM keys to root's .ssh (if not already copied)
if [ -d "$MITM_DIR"/dest ]; then
    cp -f "$MITM_DIR"/dest/* /root/.ssh/ 2>/dev/null || true
fi

echo "7. Ensuring $PASSTHROUGH_USER & ephemeral .ssh dir..."

if [ ! -d $USER_DIR ]; then
    echo "  Creating home directory for $PASSTHROUGH_USER user..."
    mkdir -p $USER_DIR 2>/dev/null
else
    echo "  $PASSTHROUGH_USER home directory exists."
fi
if [ -z "$(id $PASSTHROUGH_USER 2>/dev/null)" ]; then
    echo "   Creating $PASSTHROUGH_USER user..."
    useradd -m -G $PASSTHROUGH_USER -s /bin/bash $PASSTHROUGH_USER 2>/dev/null || true
fi

# Setup $PASSTHROUGH_USER .ssh directory
mkdir -p $USER_DIR/.ssh
rm -rf $USER_DIR/.ssh/*
cp -r $MITM_DIR/* $USER_DIR/.ssh/ 2>/dev/null || true

echo "8. Fixing SSH permissions..."
echo "   for root..."
chmod 700 /root/.ssh
chmod 600 /root/.ssh/* 2>/dev/null || touch /root/.ssh/.placeholder
chown root:root /root/.ssh
chown root:root -R /root/.ssh* 2>/dev/null || touch /root/.ssh/.placeholder

echo "   and $PASSTHROUGH_USER..."
chown $PASSTHROUGH_USER:$PASSTHROUGH_USER $USER_DIR/.ssh
chmod 700 $USER_DIR/.ssh
chmod 600 $USER_DIR/.ssh/*
chown $PASSTHROUGH_USER:$PASSTHROUGH_USER -R $USER_DIR/.ssh 2>/dev/null || touch $USER_DIR/.ssh/.placeholder

echo "9. Configure sshd for $PASSTHROUGH_USER user..."
if ! grep -q "Match User $PASSTHROUGH_USER" /etc/ssh/sshd_config; then
    echo "  Adding Match User $PASSTHROUGH_USER block to /etc/ssh/sshd_config..."
    printf "\nMatch User $PASSTHROUGH_USER\n    ForceCommand /usr/local/bin/dest-mitm\n" >> /etc/ssh/sshd_config
    echo "   Match User $PASSTHROUGH_USER block added to sshd_config"
else
    echo "   Match User $PASSTHROUGH_USER block already exists in sshd_config"
fi

echo "=========================================="
echo "Done reconfiguring for $DEST_HOST:$DEST_PORT"
