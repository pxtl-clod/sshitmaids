#!/bin/sh

#TODO: Move as much of this and entrypoint.sh into a shared "reconfigure.sh"
# script that can be re-run on demand, and make the entrypoint just call it.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
DEST_HOST="$1"
if [ -z "$DEST_HOST" ]; then
    echo "Usage: $0 <destination-host>"
    exit 1
fi

MITM_DIR="$ROOT_DIR/volumes/ssh/sshitmaids"
CLIENT_DIR="$ROOT_DIR/volumes/ssh/client"

echo "1. Build authorized_keys from all agent public keys..."
echo "  a. Start fresh"
mkdir -p $MITM_DIR
: > "$MITM_DIR/authorized_keys"

echo "  b. Append each .pub file"
for pub in "$CLIENT_DIR"/*.pub; do
    [ -e "$pub" ] || continue
    cat "$pub" >> "$MITM_DIR/authorized_keys"
done

for pub in "$MITM_DIR"/*.pub; do
    [ -e "$pub" ] || continue
    cat "$pub" >> "$MITM_DIR/authorized_keys"
done

echo "2. Write SSH config for MITM..."
cat > "$MITM_DIR/config" <<EOF
Host dest
    HostName $DEST_HOST
    User git
    IdentityFile /home/git/.ssh/id_ed25519
    UserKnownHostsFile /home/git/.ssh/known_hosts
    StrictHostKeyChecking yes
EOF
echo "sshitmaids ssh config generated for $DEST_HOST"

echo "3. Write SSH config for client..."
if [ "$SSHITMAIDS_GENERATE_CLIENT_CONFIG" = "true" ]; then
    mkdir -p $CLIENT_DIR
    cat > "$CLIENT_DIR/config" <<EOF
Host $DEST_HOST
    HostName sshitmaids
    Port 22
    User root
    IdentityFile ~/.ssh/id_ed25519
EOF
    echo "client ssh config generated for $DEST_HOST"
else
    echo "  ... Skipping client config generation (SSHITMAIDS_GENERATE_CLIENT_CONFIG is not 'true')."
fi

# echo "4. Write known_hosts for sshitmaids..."
if [ "$SSHITMAIDS_DO_KEYSCAN" = "true" ]; then
    ssh-keyscan $DEST_HOST > "$MITM_DIR/known_hosts_tmp"
    if [ ! -s "$MITM_DIR/known_hosts_tmp" ]; then
        echo "WARNING: Keyscan returned empty file. Probably rate-limited." >&2
        rm "$MITM_DIR/known_hosts_tmp"
    else
        mv "$MITM_DIR/known_hosts_tmp" "$MITM_DIR/known_hosts"
    fi
    echo "$DEST_HOST keyscanned for sshitmaids/known_hosts"
else
    echo "  ... Skipping keyscan (SSHITMAIDS_DO_KEYSCAN is not 'true') to prevent rate limiting (github is notorious about it)."
fi
echo "$DEST_HOST keyscanned for sshitmaids/known_hosts"
echo "Done '${BASH_SOURCE[0]}'."