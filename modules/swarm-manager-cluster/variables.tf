variable "namespace" {}
variable "vpc_id" {}
variable "private_subnets" {}
variable "cidr_block" {}
variable "key_name" {}
variable "ami" {}
variable "instance_type" {}
variable "consul_domain_name" {}
variable "consul_security_group" {}
variable "allow_bastion_security_group" {}
variable "private_hosted_domain_name" {}
variable "private_hosted_zone_id" {}
variable "no_of_nodes_in_cluster" {}
variable "overlay_network_name" {}
variable "core_services_vpc_cidr" {
    default = "10.0.0.0/16"
}
