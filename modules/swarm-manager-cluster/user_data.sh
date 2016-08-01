#!/bin/bash

# Remove docker engine key to make it unique
sudo rm -f /etc/docker/key.json
sudo service docker restart

# Configure the docker daemon
sudo mkdir /etc/systemd/system/docker.service.d

cat << "EOF" > /etc/systemd/system/docker.service.d/daemon.conf
{
    [Service]
    ExecStart=
    ExecStart=/usr/bin/docker daemon -H tcp://0.0.0.0:2375 -H unix:// --cluster-store=consul://${consul_server} --cluster-advertise=eth0:2375
}
EOF

# Restart the docker daemon
sudo systemctl daemon-reload
sudo systemctl restart docker

# Obtain the private IP address of this instance via the AWS API.
readonly EC2_METADATA_URL='http://169.254.169.254/latest/meta-data'
HOST_IP=$$(curl -s $${EC2_METADATA_URL}/local-ipv4)

# Create a swarm manager container and connect it to Consul.
docker run -d --name swarm -p 3375:3375 \
    swarm manage -H tcp://0.0.0.0:3375 --replication --advertise $${HOST_IP}:3375 consul://${consul_server}

docker run -d --net=host --name consul-agent -e 'CONSUL_LOCAL_CONFIG={"leave_on_terminate": true}' \
    consul agent -bind=$${HOST_IP} -retry-join=${consul_server} -node=swarm-manager-$${HOST_IP}

# Create an overlay network for our environment
docker network create --driver overlay ${overlay_network_name}

echo 'Completed.'
