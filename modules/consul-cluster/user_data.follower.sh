#!/bin/bash

# Set necessary constants
bootstrap_expect=${cluster_count}

# Obtain the ip address for this host.
host_ip=$(hostname -i)

# Pull the consul image from Docker Hub (https://hub.docker.com/_/consul/) and create a consul server container
sudo docker run -d --name consul \
    -p 8300:8300 \
    -p 8301:8301 \
    -p 8301:8301/udp \
    -p 8302:8302 \
    -p 8302:8302/udp \
    -p 8400:8400 \
    -p 80:8500 \
    -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true}' \
    consul agent \
    -server \
    -ui \
    -client=0.0.0.0 \
    -bootstrap-expect $bootstrap_expect \
    -advertise $host_ip \
    -retry-join ${consul_leader_ip} \
    -node=consul-server-$host_ip
