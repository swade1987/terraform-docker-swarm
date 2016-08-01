# ====== Security group: Logstash instances ====== #

resource "aws_security_group" "logstash_instances" {
    name = "${var.namespace}-logstash_internal"
    description = "Logstash internal traffic + maintenance."
    vpc_id = "${var.vpc_id}"

    tags {
        name = "${var.namespace}-logstash_internal"
    }

    # Open default port for Logstash
    ingress {
        from_port = 5000
        to_port = 5000
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
        cidr_blocks = ["${var.cidr_block}"]
    }
}


# ====== Security group: elastic load balancer ====== #

resource "aws_security_group" "logstash_elb" {
    name = "${var.namespace}-logstash_elb"
    description = "Logstash Elastic Load Balancer traffic"
    vpc_id = "${var.vpc_id}"

    tags {
        name = "${var.namespace}-logstash_elb"
    }

    ingress {
        from_port = 5000
        to_port = 5000
        protocol = "tcp"
        cidr_blocks = [ "${var.cidr_block}" ]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "${var.cidr_block}" ]
    }
}


# ====== Creating the amount of Logstash instances required ====== #

resource "template_file" "user_data" {
    template = "${file("${path.module}/user_data.sh")}"
    vars {
        consul_domain_name = "${var.consul_domain_name}"
        elasticsearch_domain_name = "${var.elasticsearch_domain_name}"
    }
}

resource "aws_instance" "logstash" {
    ami = "${var.ami}"
    count = "${var.no_of_nodes_in_cluster}"
    instance_type = "${var.instance_type}"
    key_name = "${var.key_name}"
    vpc_security_group_ids = [
        "${aws_security_group.logstash_instances.id}",
        "${var.allow_bastion_security_group}",
        "${var.consul_security_group}",
        "${var.elasticsearch_security_group}"
    ]
    subnet_id = "${element(split(",", var.private_subnets), count.index)}"
    user_data = "${template_file.user_data.rendered}"
    tags { Name = "${var.namespace}-logstash-${count.index}" }
}


# ====== Create an elastic load balancer ====== #

resource "aws_elb" "logstash_elb" {
    name = "${var.namespace}-logstash-elb"
    subnets = ["${split(",", var.private_subnets)}"]
    security_groups = ["${aws_security_group.logstash_elb.id}"]
    cross_zone_load_balancing = true
    connection_draining = true
    internal = true

    instances = ["${aws_instance.logstash.*.id}"]

    # HTTP

    listener {
        lb_port            = 5000
        lb_protocol        = "tcp"
        instance_port      = 5000
        instance_protocol  = "tcp"
    }

    health_check {
        healthy_threshold   = 2
        unhealthy_threshold = 2
        interval            = 10
        target              = "TCP:5000"
        timeout             = 5
    }
}


# ====== Creating one private DNS record for ALL of the instances ====== #

resource "aws_route53_record" "logstash" {
    zone_id = "${var.private_hosted_zone_id}"
    name = "logstash.${var.private_hosted_domain_name}"
    type = "A"

    alias {
        name = "${aws_elb.logstash_elb.dns_name}"
        zone_id = "${aws_elb.logstash_elb.zone_id}"
        evaluate_target_health = true
    }
}