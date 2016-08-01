# ====== Go.cd agent security groups ======= #

# ====== Security group for traffic into the instances. ====== #

resource "aws_security_group" "ingress_to_instances" {

    name         = "${var.namespace}-gocdAgent_toInstances"
    description  = "gocd agent - traffic to instances"
    vpc_id       = "${var.vpc_id}"

    tags {
        name = "${var.namespace}-gocdAgent_toInstances"
    }

    # HTTP from the go.cd server to the agents.
    ingress {
        from_port = 8153
        to_port = 8153
        protocol = "tcp"
        security_groups = ["${var.gocd_server_security_group}"]
    }

    ingress {
        from_port = 8154
        to_port = 8154
        protocol = "tcp"
        security_groups = ["${var.gocd_server_security_group}"]
    }
}

# ====== Security group for traffic from the instances. ====== #

resource "aws_security_group" "egress_from_instances" {

    name         = "${var.namespace}-gocdAgent_fromInstances"
    description  = "gocd agent - traffic from instances"
    vpc_id       = "${var.vpc_id}"

    tags {
        name = "${var.namespace}-gocdAgent_fromInstances"
    }

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
}

# ====== IAM roles, policies and profiles for our instances. ====== #

resource "aws_iam_role" "gocd_agent" {
    name = "${var.namespace}-gocdAgent"
    assume_role_policy = "${file("${path.module}/policies/assume-role-policy.json")}"
}

resource "aws_iam_role_policy" "gocd_agent" {
    name = "${var.namespace}-gocdAgent"
    role = "${aws_iam_role.gocd_agent.id}"
    policy = "${file("${path.module}/policies/gocd-agent-policy.json")}"
}

resource "aws_iam_instance_profile" "gocd_agent" {
    name = "${var.namespace}-gocdAgent"
    roles = ["${aws_iam_role.gocd_agent.name}"]
}

# ====== Launch configuration for our agents. ====== #

resource "template_file" "init" {
    lifecycle {create_before_destroy = true}
    template = "${file("${path.module}/user_data.sh")}"
    vars {
        gocd_server = "${var.server_dns}"
        default_region = "${var.default_region}"
        ssh_key = "${file("${path.module}/ssh/id_rsa")}"
        ssh_known_hosts = "${file("${path.module}/ssh/known_hosts")}"
    }
}

resource "aws_launch_configuration" "gocd_agent" {
    lifecycle {create_before_destroy = true}
    user_data = "${template_file.init.rendered}"

    image_id = "${var.ami}"
    instance_type = "${var.instance_type}"
    iam_instance_profile = "${aws_iam_instance_profile.gocd_agent.id}"

    name_prefix = "${var.namespace}-gocd-agent-launch-configuration"

    security_groups = ["${aws_security_group.ingress_to_instances.id}", "${aws_security_group.egress_from_instances.id}", "${var.allow_bastion_security_group}"]
    associate_public_ip_address = false
    ebs_optimized = false
    key_name = "${var.key_name}"
}

# ====== Autoscaling group for our agents. ====== #

resource "aws_autoscaling_group" "gocd_agent" {
    lifecycle { create_before_destroy = true }

    name = "${var.namespace}-gocd-agent-autoscaling-group"
    launch_configuration = "${aws_launch_configuration.gocd_agent.id}"

    max_size = "${var.number_of_instances}"
    min_size = "${var.minimum_number_of_instances}"
    desired_capacity = "${var.number_of_instances}"
    wait_for_elb_capacity = "${var.number_of_instances}"
    default_cooldown = 30
    health_check_grace_period = "900"
    health_check_type = "EC2"

    vpc_zone_identifier = ["${split(",", var.private_subnets)}"]

    tag {
        key = "Name"
        value = "${var.namespace}-gocd-agent"
        propagate_at_launch = true
    }

    tag {
        key = "role"
        value = "${var.namespace}-gocd-agent"
        propagate_at_launch = true
    }
}