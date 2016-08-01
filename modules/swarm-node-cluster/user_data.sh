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
    ExecStart=/usr/bin/docker daemon -H tcp://0.0.0.0:2375 -H unix:// --cluster-store=consul://${consul_domain_name} --cluster-advertise=eth0:2375
}
EOF

cat << "EOF_DOCKER_GC" > /opt/docker-gc.sh
${docker_gc}
EOF_DOCKER_GC

chmod u+x /opt/docker-gc.sh
NEW_CRONTAB="0 * * * * /opt/docker-gc.sh"
(crontab -l; echo "$NEW_CRONTAB") | crontab -

# Restart the docker daemon
sudo systemctl daemon-reload
sudo systemctl restart docker

# Obtain the private IP address of this instance via the AWS API.
readonly EC2_METADATA_URL='http://169.254.169.254/latest/meta-data'
HOST_IP=$$(curl -s $${EC2_METADATA_URL}/local-ipv4)

# Hook up a consul agent container to connect the node to Consul
docker run -d --net=host --name consul-agent --restart=always -e 'CONSUL_LOCAL_CONFIG={"leave_on_terminate": true}' \
    consul agent -bind=$${HOST_IP} -retry-join=${consul_domain_name} -node=swarm-node-$${HOST_IP}

# Hook up a Registrator container to interact with the consul agent on this node.
docker run -d --name=registrator --restart=always --net=host \
    --volume=/var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator consul://127.0.0.1:8500

# Hook up a Swarm container to interact with the Swarm Master.
docker run -d --name=swarm-agent --restart=always \
    swarm join --advertise=$${HOST_IP}:2375 consul://${consul_domain_name}

# Hook up a Traefik container to interact with Swarm.
sudo docker run -d -p 80:80 -p 8080:8080 --net=${environment} traefik \
    -l DEBUG -c /dev/null --docker --docker.domain=${environment_subdomain} --docker.endpoint=tcp://${swarm_domain_name}:3375 --docker.watch  --web

echo 'Completed...'