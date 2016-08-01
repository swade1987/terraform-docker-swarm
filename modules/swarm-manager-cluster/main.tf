resource "aws_security_group" "swarm_manager" {
    name = "${var.namespace}-swarm_manager_internal"
    description = "Security group for Swarm Manager"
    vpc_id = "${var.vpc_id}"

    tags {
        name = "${var.namespace}-swarm_manager_internal"
    }

    # Allow access via the docker_gwbridge network (3375 for non TLS, 3376 for TLS)
    ingress {
        from_port = 3375
        to_port = 3375
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}", "${var.core_services_vpc_cidr}"]
    }
    ingress {
        from_port = 3376
        to_port = 3376
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}", "${var.core_services_vpc_cidr}"]
    }
    ingress {
        from_port = 2375
        to_port = 2375
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }
    ingress {
        from_port = 2376
        to_port = 2376
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        self = true
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "template_file" "user_data" {
    template = "${file("${path.module}/user_data.sh")}"
    vars {
        consul_server = "${var.consul_domain_name}"
        subnet = "${var.cidr_block}"
        overlay_network_name = "${var.overlay_network_name}"
    }
}

# ====== Swarm Manager cluster (3 nodes for HA) ====== #

resource "aws_instance" "swarm_server_one" {
    ami = "${var.ami}"
    instance_type = "${var.instance_type}"
    key_name = "${var.key_name}"
    vpc_security_group_ids = ["${aws_security_group.swarm_manager.id}", "${var.allow_bastion_security_group}", "${var.consul_security_group}"]
    user_data = "${template_file.user_data.rendered}"
    subnet_id = "${element(split(",", var.private_subnets), 0)}"

    tags { Name = "${var.namespace}-swarm-server-1" }
}
resource "aws_instance" "swarm_server_two" {
    ami = "${var.ami}"
    instance_type = "${var.instance_type}"
    key_name = "${var.key_name}"
    vpc_security_group_ids = ["${aws_security_group.swarm_manager.id}", "${var.allow_bastion_security_group}", "${var.consul_security_group}"]
    user_data = "${template_file.user_data.rendered}"
    subnet_id = "${element(split(",", var.private_subnets), 1)}"

    tags { Name = "${var.namespace}-swarm-server-2" }
}
resource "aws_instance" "swarm_server_three" {
    ami = "${var.ami}"
    instance_type = "${var.instance_type}"
    key_name = "${var.key_name}"
    vpc_security_group_ids = ["${aws_security_group.swarm_manager.id}", "${var.allow_bastion_security_group}", "${var.consul_security_group}"]
    user_data = "${template_file.user_data.rendered}"
    subnet_id = "${element(split(",", var.private_subnets), 2)}"

    tags { Name = "${var.namespace}-swarm-server-3" }
}

# ====== DNS records ====== #

resource "aws_route53_record" "swarm_server" {
    count = "${var.no_of_nodes_in_cluster}"
    zone_id = "${var.private_hosted_zone_id}"
    name = "swarm.${var.private_hosted_domain_name}"
    type = "A"
    ttl = "300"
    records = [
        "${aws_instance.swarm_server_one.private_ip}",
        "${aws_instance.swarm_server_two.private_ip}",
        "${aws_instance.swarm_server_three.private_ip}"
    ]
}
