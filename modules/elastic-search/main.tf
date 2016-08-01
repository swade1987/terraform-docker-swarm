# ====== Security groups ====== #

resource "aws_security_group" "elastic_search" {
    name = "${var.namespace}-elastic_search_internal"
    description = "Elasticsearch internal traffic + maintenance."
    vpc_id = "${var.vpc_id}"

    tags {
        name = "${var.namespace}-elastic_search_internal"
    }

    # Open default ports for Elasticsearch
    ingress {
        from_port = 9200
        to_port = 9200
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }
    ingress {
        from_port = 9300
        to_port = 9300
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

# ====== Creating the amount of elastic search instances required ====== #

resource "template_file" "user_data" {
    template = "${file("${path.module}/user_data.sh")}"
    vars {
        consul_domain_name = "${var.consul_domain_name}"
    }
}

resource "aws_instance" "elastic_search" {
    ami = "${var.ami}"
    count = "${var.no_of_nodes_in_cluster}"
    instance_type = "${var.instance_type}"
    key_name = "${var.key_name}"
    vpc_security_group_ids = [
        "${aws_security_group.elastic_search.id}",
        "${var.allow_bastion_security_group}",
        "${var.consul_security_group}"
    ]
    subnet_id = "${element(split(",", var.private_subnets), count.index)}"
    user_data = "${template_file.user_data.rendered}"
    tags { Name = "${var.namespace}-elastic-search-${count.index}" }
}

# ====== Creating private DNS record for EACH of the instances ====== #
// resource "aws_route53_record" "elasticsearch_instances" {
//     count = "${var.no_of_nodes_in_cluster}"
//     zone_id = "${var.private_hosted_zone_id}"
//     name = "elasticsearch-${count.index}.${var.private_hosted_domain_name}"
//     type = "A"
//     ttl = "300"
//     records = ["${aws_instance.elastic_search.${count.index}.private_ip}"]
// }

# ====== Creating one private DNS record for ALL of the instances ====== #
resource "aws_route53_record" "elastic_search" {
    count = "${var.no_of_nodes_in_cluster}"
    zone_id = "${var.private_hosted_zone_id}"
    name = "elasticsearch.${var.private_hosted_domain_name}"
    type = "A"
    ttl = "300"
    records = ["${aws_instance.elastic_search.*.private_ip}"]
}