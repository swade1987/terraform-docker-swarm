#!/bin/bash

# Store our instance private key.
sudo cat << "EOF_SSH" > /home/ubuntu/.ssh/id_rsa
${ssh_key}
EOF_SSH

sudo chmod -R go-rwx /home/ubuntu/.ssh
sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh

# Tweak the configuration for OpenVPN

DNS_SERVER=$(cat /etc/resolv.conf | grep ^nameserver | head -n 1 | cut -d' ' -f2)
sudo sed -i '/push\s\+"dhcp-option\s\+DNS/d' /etc/openvpn/server.conf
echo push \"dhcp-option DNS $DNS_SERVER\" | sudo tee -a /etc/openvpn/server.conf
sudo service openvpn restart