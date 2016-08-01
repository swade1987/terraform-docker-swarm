#!/bin/bash

echo "Creating SSH key to allow access to GitHub & BitBucket"

sudo mkdir -p /var/go/.ssh

cat << "EOF_SSH" > /var/go/.ssh/id_rsa
${ssh_key}
EOF_SSH

cat << "EOF_SSH_HOSTS" > /var/go/.ssh/known_hosts
${ssh_known_hosts}
EOF_SSH_HOSTS

chmod -R go-rwx /var/go/.ssh

chown -R go /var/go