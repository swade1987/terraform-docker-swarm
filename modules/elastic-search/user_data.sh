#!/bin/bash

# Obtain the private IP address of this instance via the AWS API.
readonly EC2_METADATA_URL='http://169.254.169.254/latest/meta-data'
HOST_IP=$$(curl -s $${EC2_METADATA_URL}/local-ipv4)

# Hook up a consul agent container to connect the node to Consul
docker run -d --net=host --name consul-agent --restart=always -e 'CONSUL_LOCAL_CONFIG={"leave_on_terminate": true}' \
    consul agent -bind=$${HOST_IP} -retry-join=${consul_domain_name} -node=elasticsearch-$${HOST_IP}

# Hook up a Registrator container to interact with the LOCAL consul agent on this node.
docker run -d --name=registrator --restart=always --net=host \
    --volume=/var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator consul://127.0.0.1:8500

# Pull the elastic-search image from Docker Hub (https://hub.docker.com/_/elasticsearch/) and create an elastic-search container
sudo docker run -d --name elasticsearch  -p 9200:9200 -p 9300:9300 elasticsearch