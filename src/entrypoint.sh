#!/bin/sh
set -e

### 1. Ensure git user exists
if ! id git >/dev/null 2>&1; then
    echo "Creating git user..."
    useradd -m git
fi

### 2. Initialize root’s SSH directory from seed volume
if [ -d /root/sshitmaids ]; then
    echo "Initializing /root/.ssh from /root/sshitmaids..."
    cp -r /root/sshitmaids/* /root/.ssh/
fi

### 3. Initialize git user’s SSH directory from seed volume
if [ -d /root/sshitmaids ]; then
    echo "Initializing /home/git/.ssh from /root/sshitmaids..."
    mkdir -p /home/git/.ssh
    cp -r /root/sshitmaids/* /home/git/.ssh/
fi

### 4. Fix permissions (SSH is extremely strict)
echo "Fixing SSH permissions..."

# root
chown -R root:root /root/.ssh
chmod 700 /root/.ssh
chmod 600 /root/.ssh/*

# git
chown -R git:git /home/git/.ssh
chmod 700 /home/git/.ssh
chmod 600 /home/git/.ssh/*

### 5. Ensure ForceCommand is present for git user
if ! grep -q "Match User git" /etc/ssh/sshd_config; then
    echo "Adding Match User git block to sshd_config..."
    printf "\nMatch User git\n    ForceCommand /usr/local/bin/dest-mitm\n" >> /etc/ssh/sshd_config
fi

### 6. Start SSHD
exec /usr/sbin/sshd -D -e