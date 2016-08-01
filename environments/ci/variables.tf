variable "environment_name" {
    default = "ci"
}

variable "bastion_key_name" {
    default = "eu-west-1"
}

variable "instance_key_name" {
    default = "instance"
}

variable "region" {
    default = "eu-west-1"
}

variable "environment_subdomain" {
    default = "ci.example.org"
}

variable "private_hosted_zone" {
    default = "example.private"
}

variable "allowed_ip_address" {
    default = "225.225.255.255/32"
}

variable "bastion_host_ami" {
    default = "ami-123456"
}

variable "docker_base_ami" {
    default = "ami-123456"
}

variable "consul_cluster_count" {
    default = "2"
}

variable "swarm_cluster_count" {
    default = "3"
}

variable "default_node_cluster_size"{
    default = "2"
}

variable "public_hosted_zone_id" {
    default = "TODO"
}

variable "private_hosted_zone_id" {
    default = "TODO"
}

variable "elastic_search_cluster_count" {
    default = "1"
}

variable "logstash_cluster_count" {
    default = "3"
}

variable "kibana_cluster_count" {
    default = "3"
}
