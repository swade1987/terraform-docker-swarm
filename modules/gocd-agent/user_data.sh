#!/bin/bash

# Configure the region for the AWS CLI (for the go user)
sudo mkdir -p /var/go/.aws

cat << "EOF" > /var/go/.aws/config
[default]
region=${default_region}
EOF

echo "Setting up agent to talk to Go server @ ${gocd_server}"
sudo sed -e "s#GO_SERVER=.*#GO_SERVER=${gocd_server}#g" -i /etc/default/go-agent
sudo sed -e "s#GO_SERVER_PORT=.*#GO_SERVER_PORT=80#g" -i /etc/default/go-agent

echo "Starting Go agent"
sudo /etc/init.d/go-agent restart

echo "Creating SSH key"

sudo mkdir -p /var/go/.ssh

cat << "EOF_SSH" > /var/go/.ssh/id_rsa
${ssh_key}
EOF_SSH

cat << "EOF_SSH_HOSTS" > /var/go/.ssh/known_hosts
${ssh_known_hosts}
EOF_SSH_HOSTS

chmod -R go-rwx /var/go/.ssh

echo "Setup Docker"
sudo -u go docker login -u exampleci -p stevenwade1987
chown -R go /var/go