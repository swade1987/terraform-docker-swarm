module "vpc" {
    source = "../../modules/vpc"
    name = "${var.environment_name}"
    cidr = "10.1.0.0/16"
    private_subnets = "10.1.0.0/21,10.1.64.0/21" #,10.1.128.0/21
    public_subnets = "10.1.32.0/22" #,10.1.96.0/22,10.1.160.0/22
    availability_zones = "eu-west-1a,eu-west-1b,eu-west-1c"
    private_hosted_zone_name = "${var.private_hosted_zone_name}"
}
/*
module "bastion-host" {
    source = "../../modules/bastion-host"
    ami = "${var.bastion_host_ami}"
    vpc_id = "${module.vpc.vpc_id}"
    allowed_ip_addresses = "${var.pds_adsl_ip_address}"
    instance_type = "t2.micro"
    key_name = "${var.bastion_key_name}"
    public_subnets = "${module.vpc.public_subnets}"
    bastion_host_domain_name = "${var.bastion_domain_name}"
    cidr_block = "${module.vpc.cidr_block}"
    public_hosted_zone_id = "${module.public-subdomain.subdomain_hosted_zone}"
}

module "public-subdomain" {
   source = "../../modules/public-subdomain"
   parent_hosted_zone_id = "Z3820KW3201KHJ"
   subdomain = "${var.environment_subdomain}"
}

module "gocd-server" {
    source = "../../modules/gocd-server"
    name = "${var.environment_name}"
    ami = "${var.gocd_server_ami}"
    vpc_id = "${module.vpc.vpc_id}"
    instance_type = "t2.medium"
    key_name = "${var.instance_key_name}"
    public_subnets = "${module.vpc.public_subnets}"
    private_subnets = "${module.vpc.private_subnets}"
    domain_name = "${var.gocd_domain_name}"
    ingress_cidr_blocks = "${module.vpc.cidr_block}"
    allow_bastion_security_group = "${module.bastion-host.allow_bastion_security_group_id}"
    private_hosted_zone_id = "${module.vpc.private_hosted_zone_id}"
}

module "gocd-agent" {
    source = "../../modules/gocd-agent"
    name = "${var.environment_name}"
    vpc_id = "${module.vpc.vpc_id}"
    public_subnets = "${module.vpc.public_subnets}"
    private_subnets = "${module.vpc.private_subnets}"
    ingress_cidr_blocks = "${module.vpc.cidr_block}"
    key_name = "${var.instance_key_name}"
    ami = "${var.gocd_agent_ami}"
    instance_type = "t2.medium"
    server_dns = "${var.gocd_domain_name}"
    minimum_number_of_instances = 2
    number_of_instances = 2
    default_region = "${var.region}"
    allow_bastion_security_group = "${module.bastion-host.allow_bastion_security_group_id}"
    gocd_server_security_group = "${module.gocd-server.security_group_id}"
}
*/
# ====== VPC peering ====== #

resource "aws_vpc_peering_connection" "vpcpeering_core" {
    peer_owner_id = "${var.account_no}"
    vpc_id = "${module.vpc.vpc_id}"
    peer_vpc_id = "${var.core_services_vpc_id}"
    auto_accept = true
    tags {
        Name = "${module.vpc.name}_core"
    }
}

# Add routes from all private subnets to another VPC via the peering tunnel
resource "aws_route" "ci_to_core_services" {
    # count = "${length(split(",", module.vpc.private_subnet_route_table_ids))}"
    count = 2
    route_table_id = "${element(split(",", module.vpc.private_subnet_route_table_ids), count.index)}"
    destination_cidr_block = "${var.core_services_vpc_cidr}"
    vpc_peering_connection_id = "${aws_vpc_peering_connection.vpcpeering_core.id}"
}

# Add routes from all private subnets to another VPC via the peering tunnel
resource "aws_route" "core_services_to_ci" {
    # count = "${length(split(",", module.vpc.private_subnet_route_table_ids))}"
    route_table_id = "${var.core_services_vpc_private_route_table_1}"
    destination_cidr_block = "${module.vpc.cidr_block}"
    vpc_peering_connection_id = "${aws_vpc_peering_connection.vpcpeering_core.id}"
}