#!/bin/bash

# Obtain the private IP address of this instance via the AWS API.
readonly EC2_METADATA_URL='http://169.254.169.254/latest/meta-data'
HOST_IP=$$(curl -s $${EC2_METADATA_URL}/local-ipv4)

# Hook up a consul agent container to connect the node to Consul
docker run -d --net=host --name consul-agent --restart=always -e 'CONSUL_LOCAL_CONFIG={"leave_on_terminate": true}' \
    consul agent -bind=$${HOST_IP} -retry-join=${consul_domain_name} -node=kibana-$${HOST_IP}

# Hook up a Registrator container to interact with the LOCAL consul agent on this node.
docker run -d --name=registrator --restart=always --net=host \
    --volume=/var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator consul://127.0.0.1:8500

# Pull the kibana image from Docker Hub (https://hub.docker.com/_/kibana/) and bind it to the default port.
docker run --name kibana --restart=always -e ELASTICSEARCH_URL=http://${elasticsearch_domain_name}:9200 -p 5601:5601 -d kibana