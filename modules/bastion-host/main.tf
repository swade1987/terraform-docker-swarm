# ====== Bastion security groups ======= #

# Allow access to the bastion host from authorised networks.
# This security group will be applied to the bastion server.

resource "aws_security_group" "bastion" {
    name = "${var.namespace}-bastion"
    description = "Allow access from allowed_networks via SSH, and NAT internal traffic"
    vpc_id = "${var.vpc_id}"

    tags {
        name = "${var.namespace}-bastion"
    }

    # TODO - REMOVE EVENTUALLY (ALLOW ALL TCP AND UDP)
    /*
    ingress = {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress = {
        from_port = 0
        to_port = 65535
        protocol = "udp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    */

    # SSH
    ingress = {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [ "${var.allowed_ip_addresses}" ]
        self = false
    }

    # VPN PORTS
    ingress = {
        from_port = 1194
        to_port = 1194
        protocol = "udp"
        cidr_blocks = [ "${var.allowed_ip_addresses}" ]
        self = false
    }
    ingress = {
        from_port = 943
        to_port = 943
        protocol = "tcp"
        cidr_blocks = [ "${var.allowed_ip_addresses}" ]
        self = false
    }

    /*
    # NAT
    ingress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }
    */


    # Allow access to everything in the VPC
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["${var.cidr_block}"]
    }

    # Allow outbound HTTP to everywhere
    egress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    # Allow outbound HTTPS to everywhere
    egress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
}

# Allow access to other servers from the bastion host.
# This security group will be applied to any server that is accessed by the bastion server.

resource "aws_security_group" "allow_bastion" {
    name = "${var.namespace}-allow_everything_from_bastion"
    description = "Allow all inbound (including SSH and VPN access) from the bastion host"
    vpc_id = "${var.vpc_id}"

    tags {
        name = "${var.namespace}-allow_vpn_and_ssh_access"
    }


    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        security_groups = ["${aws_security_group.bastion.id}"]
        self = false
    }
}

# ====== Bastion host instances ======= #

resource "template_file" "user_data" {
    template = "${file("${path.module}/user_data.sh")}"
    vars {
        ssh_key = "${file("${path.module}/ssh/id_rsa")}"
    }
}

resource "aws_instance" "bastion_host" {
    ami = "${var.ami}"
    instance_type = "${var.instance_type}"
    key_name = "${var.key_name}"
    vpc_security_group_ids = ["${aws_security_group.bastion.id}"]
    user_data = "${template_file.user_data.rendered}"
    subnet_id = "${element(split(",", var.public_subnets), 0)}"
    tags { Name = "${var.namespace}-bastion-host" }
}

# ====== Domain name ======= #

# Associate the instances created above with a single domain name.

resource "aws_route53_record" "bastion_host" {
  zone_id = "${var.public_hosted_zone_id}"
  name = "${var.bastion_host_domain_name}"
  type = "A"
  ttl = "300"
  records = ["${aws_instance.bastion_host.public_ip}"]
}