# ====== Security groups ====== #

resource "aws_security_group" "consul_server" {
    name = "${var.namespace}-consul_internal"
    description = "Consul internal traffic + maintenance."
    vpc_id = "${var.vpc_id}"

    tags {
        name = "${var.namespace}-consul_internal"
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }

    ingress {
        from_port = 8300
        to_port = 8300
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }

    ingress {
        from_port = 8301
        to_port = 8301
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }

    ingress {
        from_port = 8301
        to_port = 8301
        protocol = "udp"
        cidr_blocks = ["${var.cidr_block}"]
    }

    ingress {
        from_port = 8302
        to_port = 8302
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }

    ingress {
        from_port = 8302
        to_port = 8302
        protocol = "udp"
        cidr_blocks = ["${var.cidr_block}"]
    }

    ingress {
        from_port = 8400
        to_port = 8400
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }

    ingress {
        from_port = 8500
        to_port = 8500
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }

    ingress {
        from_port = 8600
        to_port = 8600
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }

    ingress {
        from_port = 8600
        to_port = 8600
        protocol = "udp"
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


# ====== Leader ====== #

resource "template_file" "user_data_leader" {
    template = "${file("${path.module}/user_data.leader.sh")}"
}

resource "aws_instance" "consul_server_leader" {
    ami = "${var.ami}"
    instance_type = "${var.instance_type}"
    key_name = "${var.key_name}"
    vpc_security_group_ids = ["${aws_security_group.consul_server.id}", "${var.allow_bastion_security_group}"]
    subnet_id = "${element(split(",", var.private_subnets), 0)}"
    user_data = "${template_file.user_data_leader.rendered}"
    tags { Name = "${var.namespace}-consul-server-0" }
}


# ====== Follower ====== #

resource "template_file" "user_data_follower" {
    template = "${file("${path.module}/user_data.follower.sh")}"
    vars {
        consul_leader_ip = "${aws_instance.consul_server_leader.private_ip}"
        cluster_count = "${var.no_of_nodes_in_cluster}"
    }
}

resource "aws_instance" "consul_server_follower_1" {
    ami = "${var.ami}"
    instance_type = "${var.instance_type}"
    key_name = "${var.key_name}"
    vpc_security_group_ids = ["${aws_security_group.consul_server.id}", "${var.allow_bastion_security_group}"]
    subnet_id = "${element(split(",", var.private_subnets), 1)}"
    user_data = "${template_file.user_data_follower.rendered}"
    tags { Name = "${var.namespace}-consul-server-1" }
}

resource "aws_instance" "consul_server_follower_2" {
    ami = "${var.ami}"
    instance_type = "${var.instance_type}"
    key_name = "${var.key_name}"
    vpc_security_group_ids = ["${aws_security_group.consul_server.id}", "${var.allow_bastion_security_group}"]
    subnet_id = "${element(split(",", var.private_subnets), 2)}"
    user_data = "${template_file.user_data_follower.rendered}"
    tags { Name = "${var.namespace}-consul-server-2" }
}


# ====== DNS records ====== #

resource "aws_route53_record" "consul_server" {
    count = "${var.no_of_nodes_in_cluster}"
    zone_id = "${var.private_hosted_zone_id}"
    name = "consul.${var.private_hosted_domain_name}"
    type = "A"
    ttl = "300"
    records = [
        "${aws_instance.consul_server_leader.private_ip}",
        "${aws_instance.consul_server_follower_1.private_ip}",
        "${aws_instance.consul_server_follower_2.private_ip}"
    ]
}
