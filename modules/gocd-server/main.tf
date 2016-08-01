# ====== Go.cd server security groups ======= #

# Allow access to go.cd from authorised networks.
resource "aws_security_group" "gocd_elb" {
    name = "${var.namespace}-gocd-ui-elb-sg"
    description = "Security group for the gocd UI ELBs"
    vpc_id = "${var.vpc_id}"

    tags {
        name = "${var.namespace}-gocd-ui-elb-sg"
    }

    # HTTP
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["${var.ingress_cidr_blocks}"]
    }

    # HTTPS - SSL (UI)
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["${var.ingress_cidr_blocks}"]
    }

    # HTTPS - SSL (SERVER TO AGENT AND VICE VERSA)
    ingress {
        from_port = 8154
        to_port = 8154
        protocol = "tcp"
        cidr_blocks = ["${var.ingress_cidr_blocks}"]
    }

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["${var.ingress_cidr_blocks}"]
    }
}

# Allow access to the instances ONLY via the load balancer.
resource "aws_security_group" "gocd_server" {
    name = "${var.namespace}-gocd-server-sg"
    description = "Security group for Go.cd Server instances"
    vpc_id = "${var.vpc_id}"

    tags {
        name = "${var.namespace}-gocd-server-sg"
    }

    # HTTP from ELB
    ingress {
        from_port = 8153
        to_port = 8153
        protocol = "tcp"
        security_groups = ["${aws_elb.gocd_elb.source_security_group_id}"]
    }

    # HTTPS -> HTTP from ELB
    ingress {
        from_port = 8154
        to_port = 8154
        protocol = "tcp"
        security_groups = ["${aws_elb.gocd_elb.source_security_group_id}"]
    }

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["${var.ingress_cidr_blocks}"]
    }

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
}

# ====== IAM Roles, Policies & Certificiates ======= #

resource "aws_iam_role" "gocd_server" {
    name = "${var.namespace}-gocdServer"
    assume_role_policy = "${file("${path.module}/policies/assume-role-policy.json")}"
}

resource "aws_iam_role_policy" "gocd_server" {
    name = "${var.namespace}-gocdServer"
    role = "${aws_iam_role.gocd_server.id}"
    policy = "${file("${path.module}/policies/gocd-server-policy.json")}"
}

resource "aws_iam_instance_profile" "gocd_server" {
    name = "${var.namespace}-gocdServer"
    roles = ["${aws_iam_role.gocd_server.name}"]
}

resource "aws_iam_server_certificate" "gocd_cert" {
  name_prefix       = "${var.namespace}-gocd-cert"
  certificate_body  = "${file("${path.module}/ssl/gocd-certificate-body.pem")}"
  private_key       = "${file("${path.module}/ssl/gocd-private-key.pem")}"
  certificate_chain = "${file("${path.module}/ssl/gocd-certificate-chain.pem")}"

  lifecycle {
    create_before_destroy = true
  }
}

# Place an Elastic Load Balancer in the private subnet.
resource "aws_elb" "gocd_elb" {
  name = "${var.namespace}-gocd-elb"
  subnets = ["${split(",", var.private_subnets)}"]
  security_groups = ["${aws_security_group.gocd_elb.id}"]
  cross_zone_load_balancing = true
  connection_draining = true
  internal = true

  # HTTP

  listener {
    lb_port            = 80
    lb_protocol        = "tcp"
    instance_port      = 8153
    instance_protocol  = "tcp"
  }

  # HTTPS

  listener {
    lb_port            = 443
    lb_protocol        = "https"
    instance_port      = 8153
    instance_protocol  = "http"
    ssl_certificate_id = "${aws_iam_server_certificate.gocd_cert.arn}"
  }

  # HTTPS (SERVER TO AGENT)
  listener {
    lb_port            = 8154
    lb_protocol        = "tcp"
    instance_port      = 8154
    instance_protocol  = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    target              = "TCP:8153"
    timeout             = 5
  }
}

# Create a private DNS record pointing to the load balancer.
resource "aws_route53_record" "gocd-server" {
  zone_id = "${var.private_hosted_zone_id}"
  name = "${var.domain_name}"
  type = "A"

  alias {
    name = "${aws_elb.gocd_elb.dns_name}"
    zone_id = "${aws_elb.gocd_elb.zone_id}"
    evaluate_target_health = true
  }
}

# ====== Launch configuration ======= #

resource "template_file" "init" {
    lifecycle {create_before_destroy = true}
    template = "${file("${path.module}/user_data.sh")}"
    vars {
        ssh_key = "${file("${path.module}/ssh/id_rsa")}"
        ssh_known_hosts = "${file("${path.module}/ssh/known_hosts")}"
    }
}

resource "aws_launch_configuration" "gocd_server" {
    lifecycle {create_before_destroy = true}
    user_data = "${template_file.init.rendered}"

    image_id = "${var.ami}"
    instance_type = "${var.instance_type}"
    iam_instance_profile = "${aws_iam_instance_profile.gocd_server.id}"

    name_prefix = "${var.namespace}-gocd-server-launch-configuration"

    security_groups = ["${aws_security_group.gocd_server.id}", "${var.allow_bastion_security_group}"]
    associate_public_ip_address = false
    ebs_optimized = false
    key_name = "${var.key_name}"
}

# ====== Auto scaling group (allow instances located in the private subnet) ======= #

resource "aws_autoscaling_group" "gocd_server" {
    lifecycle { create_before_destroy = true }

    name = "${var.namespace}-gocd-server-autoscaling-group"
    launch_configuration = "${aws_launch_configuration.gocd_server.id}"

    max_size = 2
    min_size = 1
    desired_capacity = 1
    wait_for_elb_capacity = 1
    default_cooldown = 30
    health_check_grace_period = "900"
    health_check_type = "EC2"

    load_balancers = ["${aws_elb.gocd_elb.name}"]
    vpc_zone_identifier = ["${split(",", var.private_subnets)}"]

    tag {
        key = "Name"
        value = "${var.namespace}-gocd-server"
        propagate_at_launch = true
    }

    tag {
        key = "role"
        value = "gocd-server"
        propagate_at_launch = true
    }
}