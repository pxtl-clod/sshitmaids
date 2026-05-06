#!/bin/sh

# Force HOME to the git user's home directory
HOME=/home/git
export HOME

# Forward the original command from the incoming SSH session.
# When sshd is using ForceCommand, the requested command is available in SSH_ORIGINAL_COMMAND.
if [ -n "$SSH_ORIGINAL_COMMAND" ]; then
    exec ssh -F /home/git/.ssh/config -T dest "$SSH_ORIGINAL_COMMAND"
else
    exec ssh -F /home/git/.ssh/config -T dest
fi