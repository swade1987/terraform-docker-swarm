#!/bin/bash

# Create a logstash configuration
sudo mkdir -p /etc/logstash

cat << "EOF" > /etc/logstash/logstash.conf
input { tcp { port => 5000 } } output { elasticsearch { hosts => "${elasticsearch_domain_name}:9200" } }
EOF

# Change the permissions to the configuration file so Docker can use it.
sudo chmod 644 /etc/logstash/logstash.conf

# Obtain the private IP address of this instance via the AWS API.
readonly EC2_METADATA_URL='http://169.254.169.254/latest/meta-data'
HOST_IP=$$(curl -s $${EC2_METADATA_URL}/local-ipv4)

# Hook up a consul agent container to connect the node to Consul
docker run -d --net=host --name consul-agent --restart=always -e 'CONSUL_LOCAL_CONFIG={"leave_on_terminate": true}' \
    consul agent -bind=$${HOST_IP} -retry-join=${consul_domain_name} -node=logstash-$${HOST_IP}

# Hook up a Registrator container to interact with the LOCAL consul agent on this node.
docker run -d --name=registrator --restart=always --net=host \
    --volume=/var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator consul://127.0.0.1:8500

# Pull the logstash image from Docker Hub (https://hub.docker.com/_/logstash/) and then create a container using the configuration file created above.
docker run -d --name logstash --restart=always --net=host  -p 5000:5000 \
    -v /etc/logstash/logstash.conf:/etc/logstash/conf.d/logstash.conf logstash -f /etc/logstash/conf.d/logstash.conf