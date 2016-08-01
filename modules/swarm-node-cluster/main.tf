# ====== Security group for traffic into the ELB ====== #

resource "aws_security_group" "ingress_to_elb" {

    name         = "${var.namespace}-swarm_node_to_elb"
    description  = "docker-swarm-node - traffic to elb"
    vpc_id       = "${var.vpc_id}"

    tags {
        name = "${var.namespace}-swarm_node_to_elb"
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# ====== Security group for traffic from the ELB ====== #

resource "aws_security_group" "egress_from_elb" {

    name         = "${var.namespace}-swarm_node_from_elb"
    description  = "docker-swarm-node - traffic from elb"
    vpc_id       = "${var.vpc_id}"

    tags {
        name = "${var.namespace}-swarm_node_from_elb"
    }

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["${var.cidr_block}"]
    }
}

# ====== Security group for traffic into the instances. ====== #

resource "aws_security_group" "instances" {

    name         = "${var.namespace}-swarm_node_to_instances"
    description  = "docker-swarm-node - traffic to and from instances"
    vpc_id       = "${var.vpc_id}"

    tags {
        name = "${var.namespace}-swarm_node_to_instances"
    }


    # HTTP from ELB
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = ["${aws_elb.docker_swarm_node.source_security_group_id}"]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        security_groups = ["${aws_elb.docker_swarm_node.source_security_group_id}"]
    }

    ingress {
        from_port = 8080
        to_port = 8080
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

resource "aws_elb" "docker_swarm_node" {
  name = "${var.namespace}-docker-swarm-node-elb"
  subnets = ["${split(",", var.public_subnets)}"]
  security_groups = ["${aws_security_group.ingress_to_elb.id}", "${aws_security_group.egress_from_elb.id}"]
  cross_zone_load_balancing = true
  connection_draining = true

  listener {
    instance_port      = 80
    instance_protocol  = "tcp"
    lb_port            = 80
    lb_protocol        = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    target              = "TCP:80"
    timeout             = 5
  }
}

# ====== Launch configuration and Auto Scaling Group for instances. ====== #

resource "template_file" "init" {
    lifecycle {create_before_destroy = true}
    template = "${file("${path.module}/user_data.sh")}"
    vars {
        consul_domain_name = "${var.consul_domain_name}"
        swarm_domain_name = "${var.swarm_domain_name}"
        environment_subdomain = "${var.environment_subdomain}"
        environment = "${var.environment}"
        docker_gc = "${file("${path.module}/docker-gc.sh")}"
    }
}


resource "aws_launch_configuration" "docker_swarm_node" {
    lifecycle {create_before_destroy = true}
    user_data = "${template_file.init.rendered}"
    image_id = "${var.ami}"
    instance_type = "${var.instance_type}"
    name_prefix = "${var.namespace}-docker-swarm-node-launch-configuration"
    associate_public_ip_address = false
    ebs_optimized = false
    key_name = "${var.key_name}"

    security_groups = [
        "${aws_security_group.instances.id}",
        "${var.consul_security_group}",
        "${var.swarm_manager_security_group}",
        "${var.allow_bastion_security_group}",
        "${var.logstash_security_group}"
    ]
}

resource "aws_autoscaling_group" "docker_swarm_node" {
    lifecycle { create_before_destroy = true }

    name = "${var.namespace}-docker-swarm-node"
    launch_configuration = "${aws_launch_configuration.docker_swarm_node.id}"

    min_size = "1"
    max_size = "${var.number_of_instances}"
    desired_capacity = "${var.number_of_instances}"
    wait_for_elb_capacity = "${var.number_of_instances}"
    default_cooldown = 30
    health_check_grace_period = "900"
    health_check_type = "EC2"

    load_balancers = ["${aws_elb.docker_swarm_node.name}"]
    vpc_zone_identifier = ["${split(",", var.private_subnets)}"]

    tag {
        key = "Name"
        value = "${var.namespace}-docker-swarm-node"
        propagate_at_launch = true
    }
}

# ====== Create a Route 53 record for all subdomains to point to this load balancer. ====== #

resource "aws_route53_record" "docker_swarm_node" {
  zone_id = "${var.public_hosted_zone_id}"
  name = "*.${var.environment_subdomain}"
  type = "A"

  alias {
    name = "${aws_elb.docker_swarm_node.dns_name}"
    zone_id = "${aws_elb.docker_swarm_node.zone_id}"
    evaluate_target_health = true
  }
}